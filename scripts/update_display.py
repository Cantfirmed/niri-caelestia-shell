#!/usr/bin/env python3
"""Robust KDL parser and serializer for Niri output configurations (~/.config/niri/niri/output.kdl).

Preserves top-level and inline comments, slashdash (/-) disabled nodes, nested blocks,
and unmanaged output attributes while safely updating managed properties:
  - off / active
  - mode "<width>x<height>@<refresh>"
  - scale <float>
  - position x=<int> y=<int>
  - transform "<normal|90|180|270|flipped|flipped-90|flipped-180|flipped-270>"
  - variable-refresh-rate [on-demand=true]

Also enforces lid-closed clamshell safety so saving display settings while docked
with a closed laptop lid never accidentally re-enables the internal panel.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from typing import Any

INTERNAL_PREFIXES = ("eDP", "LVDS", "DSI")

VALID_TRANSFORMS = {
    "normal": "normal",
    "0": "normal",
    "90": "90",
    "_90": "90",
    "180": "180",
    "_180": "180",
    "270": "270",
    "_270": "270",
    "flipped": "flipped",
    "flipped90": "flipped-90",
    "flipped-90": "flipped-90",
    "flipped_90": "flipped-90",
    "flipped180": "flipped-180",
    "flipped-180": "flipped-180",
    "flipped_180": "flipped-180",
    "flipped270": "flipped-270",
    "flipped-270": "flipped-270",
    "flipped_270": "flipped-270",
}

MANAGED_KEYS = {"off", "position", "mode", "scale", "transform", "variable-refresh-rate"}


def normalize_transform(val: Any) -> str | None:
    if val is None:
        return None
    key = str(val).strip().lower()
    if not key:
        return None
    if key in VALID_TRANSFORMS:
        return VALID_TRANSFORMS[key]
    raise ValueError(f"Unsupported transform value: {val!r}")


def format_scale(scale: float) -> str:
    val = round(float(scale), 4)
    text = f"{val:g}"
    if "." not in text and "e" not in text.lower():
        text = f"{val:.1f}"
    return text


def escape_kdl_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def unescape_kdl_string(token: str) -> str:
    if token.startswith('r#') or token.startswith('r"'):
        first_quote = token.index('"')
        hashes = first_quote - 1
        end_idx = len(token) - 1 - hashes
        return token[first_quote + 1 : end_idx]
    if len(token) >= 2 and token[0] == '"' and token[-1] == '"':
        inner = token[1:-1]
        out: list[str] = []
        i = 0
        while i < len(inner):
            ch = inner[i]
            if ch == "\\" and i + 1 < len(inner):
                nxt = inner[i + 1]
                mapping = {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", '"': '"', "/": "/"}
                out.append(mapping.get(nxt, nxt))
                i += 2
            else:
                out.append(ch)
                i += 1
        return "".join(out)
    return token


# ---------------------------------------------------------------------------
# Character-level KDL Scanner & Lossless AST Node Parser
# ---------------------------------------------------------------------------


@dataclass
class KdlStatement:
    """Represents a statement or trivia chunk inside a KDL document or block."""

    leading_trivia: str
    name: str | None  # None if pure trailing trivia at EOF/end-of-block
    args: list[str] = field(default_factory=list)
    raw_header: str = ""  # From start of node name up to '{' or end of statement (excluding trailing comment/newline)
    body_text: str | None = None  # Inside '{' ... '}' if block node
    trailing_trivia: str = ""  # Inline spaces/comments up to and including terminating ';' or '\n'
    slashdashed: bool = False

    def render(self) -> str:
        if self.name is None:
            return self.leading_trivia
        prefix = self.leading_trivia
        if self.slashdashed:
            # Raw text for slashdashed nodes is stored directly in raw_header
            return f"{prefix}{self.raw_header}{self.trailing_trivia}"
        if self.body_text is not None:
            return f"{prefix}{self.raw_header}{{{self.body_text}}}{self.trailing_trivia}"
        return f"{prefix}{self.raw_header}{self.trailing_trivia}"


class KdlScanner:
    """Lossless KDL scanner supporting nested /* */ comments, raw strings, slashdash, and blocks."""

    def __init__(self, text: str) -> None:
        self.text = text
        self.n = len(text)
        self.pos = 0

    def eof(self) -> bool:
        return self.pos >= self.n

    def peek(self, offset: int = 0) -> str:
        idx = self.pos + offset
        return self.text[idx] if 0 <= idx < self.n else ""

    def skip_line_comment(self) -> None:
        self.pos += 2  # '//'
        while not self.eof() and self.peek() != "\n":
            self.pos += 1

    def skip_block_comment(self) -> None:
        self.pos += 2  # '/*'
        depth = 1
        while not self.eof() and depth > 0:
            if self.peek() == "/" and self.peek(1) == "*":
                depth += 1
                self.pos += 2
            elif self.peek() == "*" and self.peek(1) == "/":
                depth -= 1
                self.pos += 2
            else:
                self.pos += 1

    def skip_string(self) -> str:
        start = self.pos
        if self.peek() == "r" and (self.peek(1) == '"' or self.peek(1) == "#"):
            self.pos += 1
            hashes = 0
            while self.peek() == "#":
                hashes += 1
                self.pos += 1
            if self.peek() == '"':
                self.pos += 1
                closing = '"' + ("#" * hashes)
                while not self.eof():
                    if self.text.startswith(closing, self.pos):
                        self.pos += len(closing)
                        break
                    self.pos += 1
            return self.text[start : self.pos]

        self.pos += 1  # opening '"'
        while not self.eof():
            ch = self.peek()
            if ch == "\\":
                self.pos += 2
            elif ch == '"':
                self.pos += 1
                break
            else:
                self.pos += 1
        return self.text[start : self.pos]

    def skip_braced_block(self) -> str:
        """Assumes self.peek() == '{'. Advances past matching '}' and returns inner content."""
        assert self.peek() == "{"
        self.pos += 1
        inner_start = self.pos
        depth = 1
        while not self.eof() and depth > 0:
            ch = self.peek()
            nxt = self.peek(1)
            if ch == "/" and nxt == "/":
                self.skip_line_comment()
            elif ch == "/" and nxt == "*":
                self.skip_block_comment()
            elif ch == '"' or (ch == "r" and nxt in ('"', "#")):
                self.skip_string()
            elif ch == "{":
                depth += 1
                self.pos += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    inner_end = self.pos
                    self.pos += 1
                    return self.text[inner_start:inner_end]
                self.pos += 1
            else:
                self.pos += 1
        return self.text[inner_start : self.pos]

    def consume_leading_trivia(self) -> str:
        start = self.pos
        while not self.eof():
            ch = self.peek()
            nxt = self.peek(1)
            if ch in (" ", "\t", "\r", "\n"):
                self.pos += 1
            elif ch == "/" and nxt == "/":
                self.skip_line_comment()
            elif ch == "/" and nxt == "*":
                self.skip_block_comment()
            else:
                break
        return self.text[start : self.pos]

    def consume_trailing_line(self) -> str:
        start = self.pos
        while not self.eof():
            ch = self.peek()
            nxt = self.peek(1)
            if ch in (" ", "\t", "\r"):
                self.pos += 1
            elif ch == "/" and nxt == "/":
                self.skip_line_comment()
            elif ch == "/" and nxt == "*":
                self.skip_block_comment()
            elif ch == ";":
                self.pos += 1
                # Also consume optional inline comment + newline right after ';'
                while not self.eof() and self.peek() in (" ", "\t", "\r"):
                    self.pos += 1
                if self.peek() == "/" and self.peek(1) == "/":
                    self.skip_line_comment()
                if self.peek() == "\n":
                    self.pos += 1
                break
            elif ch == "\n":
                self.pos += 1
                break
            else:
                break
        return self.text[start : self.pos]

    def skip_one_node_raw(self) -> None:
        """Advance past a single node (used for /- slashdashed nodes/blocks)."""
        while not self.eof():
            ch = self.peek()
            nxt = self.peek(1)
            if ch == "\\" and nxt in ("\n", "\r", " ", "\t"):
                # Line continuation
                self.pos += 2
                continue
            if ch in ("\n", ";"):
                break
            if ch == "/" and nxt == "/":
                break
            if ch == "/" and nxt == "*":
                self.skip_block_comment()
            elif ch == '"' or (ch == "r" and nxt in ('"', "#")):
                self.skip_string()
            elif ch == "{":
                self.skip_braced_block()
                break
            else:
                self.pos += 1

    def parse_statements(self) -> list[KdlStatement]:
        statements: list[KdlStatement] = []
        while not self.eof():
            trivia = self.consume_leading_trivia()
            if self.eof():
                if trivia:
                    statements.append(KdlStatement(leading_trivia=trivia, name=None))
                break

            # Slashdash commented node: `/- ...`
            if self.peek() == "/" and self.peek(1) == "-":
                sd_start = self.pos
                self.pos += 2
                # Skip whitespace/comments between `/-` and the commented node
                self.consume_leading_trivia()
                self.skip_one_node_raw()
                raw_sd = self.text[sd_start : self.pos]
                trailing = self.consume_trailing_line()
                statements.append(
                    KdlStatement(
                        leading_trivia=trivia,
                        name="__slashdash__",
                        raw_header=raw_sd,
                        trailing_trivia=trailing,
                        slashdashed=True,
                    )
                )
                continue

            node_start = self.pos
            # Parse node name token
            if self.peek() == '"' or (self.peek() == "r" and self.peek(1) in ('"', "#")):
                raw_name = self.skip_string()
                node_name = unescape_kdl_string(raw_name)
            else:
                ident_start = self.pos
                while not self.eof() and self.peek() not in (" ", "\t", "\r", "\n", ";", "{", "}", "/"):
                    self.pos += 1
                node_name = self.text[ident_start : self.pos]

            if not node_name:
                # Defensive progress guarantee on unexpected char
                self.pos += 1
                statements.append(
                    KdlStatement(leading_trivia=trivia + self.text[node_start : self.pos], name=None)
                )
                continue

            args: list[str] = []
            body_text: str | None = None
            header_end = self.pos

            while not self.eof():
                ch = self.peek()
                nxt = self.peek(1)
                if ch in (" ", "\t", "\r"):
                    self.pos += 1
                elif ch == "\\" and nxt in ("\n", "\r", " ", "\t"):
                    # KDL line continuation
                    self.pos += 1
                    while not self.eof() and self.peek() in (" ", "\t", "\r"):
                        self.pos += 1
                    if self.peek() == "\n":
                        self.pos += 1
                elif ch == "/" and nxt == "*":
                    self.skip_block_comment()
                elif ch == "/" and nxt == "/":
                    break
                elif ch in ("\n", ";", "}"):
                    break
                elif ch == "{":
                    header_end = self.pos
                    body_text = self.skip_braced_block()
                    break
                elif ch == '"' or (ch == "r" and nxt in ('"', "#")):
                    tok = self.skip_string()
                    args.append(unescape_kdl_string(tok))
                    header_end = self.pos
                else:
                    tok_start = self.pos
                    while not self.eof() and self.peek() not in (" ", "\t", "\r", "\n", ";", "{", "}", "/"):
                        if self.peek() == '"':
                            self.skip_string()
                        else:
                            self.pos += 1
                    tok = self.text[tok_start : self.pos]
                    if "=" not in tok:
                        args.append(tok)
                    header_end = self.pos

            if body_text is None:
                header_end = self.pos
            raw_header = self.text[node_start:header_end]
            trailing = self.consume_trailing_line()
            statements.append(
                KdlStatement(
                    leading_trivia=trivia,
                    name=node_name,
                    args=args,
                    raw_header=raw_header,
                    body_text=body_text,
                    trailing_trivia=trailing,
                )
            )
        return statements


def parse_kdl_statements(text: str) -> list[KdlStatement]:
    return KdlScanner(text).parse_statements()


def render_kdl_statements(statements: list[KdlStatement]) -> str:
    return "".join(stmt.render() for stmt in statements)


def extract_output_settings(content: str, connector: str) -> dict[str, Any]:
    """Read existing settings for `connector` from KDL content so callers can preserve them."""
    info: dict[str, Any] = {}
    for stmt in parse_kdl_statements(content):
        if stmt.slashdashed or stmt.name != "output" or not stmt.args:
            continue
        if stmt.args[0] != connector or stmt.body_text is None:
            continue
        for child in parse_kdl_statements(stmt.body_text):
            if child.slashdashed or child.name is None:
                continue
            if child.name == "off":
                info["off"] = True
            elif child.name == "mode" and child.args:
                info["mode"] = child.args[0]
            elif child.name == "scale" and child.args:
                try:
                    info["scale"] = float(child.args[0])
                except ValueError:
                    pass
            elif child.name == "transform" and child.args:
                try:
                    info["transform"] = normalize_transform(child.args[0])
                except ValueError:
                    pass
            elif child.name == "variable-refresh-rate":
                info["vrr"] = "on-demand" if "on-demand=true" in child.raw_header else True
            elif child.name == "position":
                for tok in child.raw_header.split()[1:]:
                    if tok.startswith("x="):
                        try:
                            info["x"] = int(tok.split("=", 1)[1])
                        except ValueError:
                            pass
                    elif tok.startswith("y="):
                        try:
                            info["y"] = int(tok.split("=", 1)[1])
                        except ValueError:
                            pass
    return info


def _extract_inline_comment(trailing_trivia: str) -> str:
    """Keep any inline `// ...` or `/* ... */` comment attached to a replaced line."""
    stripped = trailing_trivia.rstrip("\r\n")
    idx_line = stripped.find("//")
    idx_block = stripped.find("/*")
    candidates = [i for i in (idx_line, idx_block) if i >= 0]
    if not candidates:
        return "\n"
    first = min(candidates)
    prefix_ws = stripped[:first] if stripped[:first].strip() == "" else " "
    if not prefix_ws:
        prefix_ws = " "
    return f"{prefix_ws}{stripped[first:]}\n"


def _build_managed_line(key: str, spec: dict[str, Any]) -> str | None:
    """Return the serialized header string for a managed child node, or None to omit/delete."""
    if key == "off":
        if spec.get("off") is True or spec.get("active") is False:
            return "off"
        return None

    if key == "mode":
        mode = spec.get("mode")
        if mode in (None, "", False):
            return None
        return f"mode {escape_kdl_string(str(mode))}"

    if key == "scale":
        scale = spec.get("scale")
        if scale is None:
            return None
        return f"scale {format_scale(float(scale))}"

    if key == "position":
        x = spec.get("x")
        y = spec.get("y")
        if x is None or y is None:
            return None
        return f"position x={int(round(float(x)))} y={int(round(float(y)))}"

    if key == "transform":
        transform = normalize_transform(spec.get("transform"))
        if transform is None:
            return None
        return f"transform {escape_kdl_string(transform)}"

    if key == "variable-refresh-rate":
        vrr = spec.get("vrr")
        if vrr is None or vrr is False or str(vrr).lower() in ("false", "off", "0", "none"):
            return None
        if str(vrr).lower() == "on-demand":
            return "variable-refresh-rate on-demand=true"
        return "variable-refresh-rate"

    return None


def _should_manage_key(key: str, spec: dict[str, Any]) -> bool:
    """Determine whether `spec` intends to modify `key` (vs leaving existing value untouched)."""
    if key == "off":
        return "off" in spec or "active" in spec
    if key == "position":
        return spec.get("x") is not None and spec.get("y") is not None
    if key == "mode":
        return "mode" in spec and spec.get("mode") is not None
    if key == "scale":
        return "scale" in spec and spec.get("scale") is not None
    if key == "transform":
        return "transform" in spec and spec.get("transform") is not None
    if key == "variable-refresh-rate":
        return "vrr" in spec and spec.get("vrr") is not None
    return False


def _update_output_block_body(body_text: str, spec: dict[str, Any]) -> str:
    children = parse_kdl_statements(body_text)
    indent = "    "
    for ch in children:
        if ch.name and not ch.slashdashed:
            last_nl = ch.leading_trivia.rfind("\n")
            cand = ch.leading_trivia[last_nl + 1 :] if last_nl >= 0 else ch.leading_trivia
            if cand and cand.strip() == "":
                indent = cand
                break

    managed_order = ["off", "mode", "scale", "position", "transform", "variable-refresh-rate"]
    handled: set[str] = set()
    updated_children: list[KdlStatement] = []

    for ch in children:
        if ch.slashdashed or ch.name is None or ch.name not in MANAGED_KEYS:
            updated_children.append(ch)
            continue

        key = ch.name
        if not _should_manage_key(key, spec):
            updated_children.append(ch)
            continue

        new_header = _build_managed_line(key, spec)
        if key in handled or new_header is None:
            # Remove duplicate or explicitly cleared attribute while preserving any preceding comments!
            last_nl = ch.leading_trivia.rfind("\n")
            kept_comments = ch.leading_trivia[: last_nl + 1] if last_nl >= 0 else ""
            if kept_comments.strip():
                updated_children.append(KdlStatement(leading_trivia=kept_comments, name=None))
            handled.add(key)
            continue

        handled.add(key)
        ch.raw_header = new_header
        ch.body_text = None
        ch.trailing_trivia = _extract_inline_comment(ch.trailing_trivia)
        updated_children.append(ch)

    # Append any newly configured managed attributes in canonical order before trailing block trivia
    trailing_eof: KdlStatement | None = None
    if updated_children and updated_children[-1].name is None:
        trailing_eof = updated_children.pop()

    has_existing_nodes = any(c.name is not None for c in updated_children)
    first_prefix_needs_nl = not has_existing_nodes and (not body_text.startswith("\n"))

    for key in managed_order:
        if key in handled or not _should_manage_key(key, spec):
            continue
        new_header = _build_managed_line(key, spec)
        if new_header is None:
            continue
        lead = ("\n" if first_prefix_needs_nl else "") + indent
        first_prefix_needs_nl = False
        updated_children.append(
            KdlStatement(
                leading_trivia=lead,
                name=key,
                raw_header=new_header,
                trailing_trivia="\n",
            )
        )

    if trailing_eof is not None:
        # Ensure closing brace lands on its own line
        if not trailing_eof.leading_trivia.startswith("\n") and updated_children:
            if not updated_children[-1].trailing_trivia.endswith("\n"):
                updated_children[-1].trailing_trivia += "\n"
        updated_children.append(trailing_eof)
    else:
        if updated_children and not updated_children[-1].trailing_trivia.endswith("\n"):
            updated_children[-1].trailing_trivia += "\n"

    rendered = render_kdl_statements(updated_children)
    if rendered and not rendered.startswith("\n"):
        rendered = "\n" + rendered
    return rendered


def update_kdl_content(content: str, outputs_list: list[dict[str, Any]]) -> str:
    """Losslessly update or append `output "<connector>"` blocks in KDL document text."""
    statements = parse_kdl_statements(content)

    for raw_spec in outputs_list:
        spec = dict(raw_spec)
        connector = spec.get("connector")
        if not connector:
            continue

        matched = False
        for stmt in statements:
            if stmt.slashdashed or stmt.name != "output" or not stmt.args:
                continue
            if stmt.args[0] == connector:
                if not matched:
                    stmt.body_text = _update_output_block_body(stmt.body_text or "\n", spec)
                    if not stmt.raw_header.endswith(" "):
                        stmt.raw_header = f"output {escape_kdl_string(connector)} "
                    matched = True

        if not matched:
            body = _update_output_block_body("", spec)
            trailing_eof: KdlStatement | None = None
            if statements and statements[-1].name is None:
                trailing_eof = statements.pop()

            needs_leading_nl = False
            if statements:
                prev_text = statements[-1].render()
                if not prev_text.endswith("\n\n") and prev_text.endswith("\n"):
                    needs_leading_nl = True
                elif not prev_text.endswith("\n"):
                    statements[-1].trailing_trivia += "\n"
                    needs_leading_nl = True

            statements.append(
                KdlStatement(
                    leading_trivia="\n" if needs_leading_nl else "",
                    name="output",
                    args=[connector],
                    raw_header=f"output {escape_kdl_string(connector)} ",
                    body_text=body,
                    trailing_trivia="\n",
                )
            )
            if trailing_eof is not None:
                statements.append(trailing_eof)

    result = render_kdl_statements(statements)
    if result and not result.endswith("\n"):
        result += "\n"
    return result


# ---------------------------------------------------------------------------
# Hardware / Clamshell Safety & Niri Validation
# ---------------------------------------------------------------------------


def ensure_niri_socket() -> bool:
    if "NIRI_SOCKET" in os.environ and os.path.exists(os.environ["NIRI_SOCKET"]):
        return True
    uid = os.getuid()
    socks = glob.glob(f"/run/user/{uid}/niri*.sock")
    if socks:
        socks.sort(key=lambda s: os.path.getmtime(s), reverse=True)
        os.environ["NIRI_SOCKET"] = socks[0]
        return True
    return False


def is_lid_closed() -> bool:
    for path in glob.glob("/proc/acpi/button/lid/*/state"):
        try:
            with open(path, "r", encoding="utf-8") as f:
                if "closed" in f.read().lower():
                    return True
        except OSError:
            pass
    return False


def has_connected_external_drm() -> bool:
    for path in glob.glob("/sys/class/drm/card*-*/status"):
        parts = os.path.basename(os.path.dirname(path)).split("-", 1)
        if len(parts) > 1:
            conn = parts[1]
            if conn.startswith(INTERNAL_PREFIXES):
                continue
            try:
                with open(path, "r", encoding="utf-8") as f:
                    if f.read().strip() == "connected":
                        return True
            except OSError:
                continue
    return False


def apply_clamshell_guard(outputs_list: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Prevent config writes from re-enabling internal laptop panel when lid is closed + external active."""
    if not is_lid_closed():
        return outputs_list

    external_active_in_spec = any(
        not str(o.get("connector", "")).startswith(INTERNAL_PREFIXES)
        and o.get("off") is not True
        and o.get("active", True) is not False
        for o in outputs_list
    )
    if not (external_active_in_spec or has_connected_external_drm()):
        return outputs_list

    guarded: list[dict[str, Any]] = []
    has_internal_entry = False
    for item in outputs_list:
        copy_item = dict(item)
        conn = str(copy_item.get("connector", ""))
        if conn.startswith(INTERNAL_PREFIXES):
            has_internal_entry = True
            copy_item["off"] = True
            copy_item["active"] = False
        guarded.append(copy_item)

    if not has_internal_entry:
        # Check if an internal DRM panel exists; if so, ensure it stays off in clamshell mode
        for path in glob.glob("/sys/class/drm/card*-*/status"):
            parts = os.path.basename(os.path.dirname(path)).split("-", 1)
            if len(parts) > 1 and parts[1].startswith(INTERNAL_PREFIXES):
                guarded.append({"connector": parts[1], "off": True, "active": False})
                break

    return guarded


def validate_kdl_file(path: str) -> tuple[bool, str]:
    niri_bin = shutil.which("niri")
    if not niri_bin:
        return True, ""
    res = subprocess.run([niri_bin, "validate", "-c", path], capture_output=True, text=True)
    if res.returncode == 0:
        return True, ""
    return False, (res.stderr or res.stdout).strip()


def update_multiple_outputs(
    outputs_list: list[dict[str, Any]],
    config_path: str | None = None,
    reload_config: bool = True,
    respect_clamshell: bool = True,
) -> str:
    target_path = os.path.expanduser(config_path or "~/.config/niri/niri/output.kdl")
    os.makedirs(os.path.dirname(target_path), exist_ok=True)

    if os.path.exists(target_path):
        with open(target_path, "r", encoding="utf-8") as f:
            content = f.read()
    else:
        content = "// --- Output Configuration ---\n"

    effective_list = apply_clamshell_guard(outputs_list) if respect_clamshell else outputs_list
    updated_content = update_kdl_content(content, effective_list)

    fd, tmp_path = tempfile.mkstemp(
        prefix=".output.kdl.",
        suffix=".tmp",
        dir=os.path.dirname(target_path),
        text=True,
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp_f:
            tmp_f.write(updated_content)

        valid, err = validate_kdl_file(tmp_path)
        if not valid:
            raise RuntimeError(f"Generated KDL failed `niri validate`: {err}")

        os.replace(tmp_path, target_path)
    finally:
        if os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass

    if reload_config and ensure_niri_socket():
        niri_bin = shutil.which("niri")
        if niri_bin:
            subprocess.run([niri_bin, "msg", "action", "load-config-file"], check=False)

    return updated_content


def update_output_kdl(
    connector: str,
    x: int | None = None,
    y: int | None = None,
    scale: float | None = None,
    mode: str | None = None,
    transform: str | None = None,
    vrr: bool | str | None = None,
    off: bool | None = None,
    config_path: str | None = None,
    reload_config: bool = True,
) -> str:
    item: dict[str, Any] = {"connector": connector}
    if x is not None:
        item["x"] = x
    if y is not None:
        item["y"] = y
    if scale is not None:
        item["scale"] = scale
    if mode is not None:
        item["mode"] = mode
    if transform is not None:
        item["transform"] = transform
    if vrr is not None:
        item["vrr"] = vrr
    if off is not None:
        item["off"] = off
    return update_multiple_outputs([item], config_path=config_path, reload_config=reload_config)


def _parse_vrr_arg(raw: str | None) -> bool | str | None:
    if raw is None:
        return None
    val = raw.strip().lower()
    if val in ("1", "true", "on", "yes"):
        return True
    if val in ("0", "false", "off", "no"):
        return False
    if val == "on-demand":
        return "on-demand"
    raise ValueError(f"Unsupported --vrr value: {raw!r} (expected on, off, or on-demand)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Safely update Niri output.kdl configuration.")
    parser.add_argument("connector", nargs="?", help="Output connector name (e.g. DP-2, eDP-1)")
    parser.add_argument("--x", type=int, help="Logical X position")
    parser.add_argument("--y", type=int, help="Logical Y position")
    parser.add_argument("--scale", type=float, help="Fractional or integer scale factor")
    parser.add_argument("--mode", help='Display mode string (e.g. "2560x1440@164.958")')
    parser.add_argument("--transform", help='Transform ("normal", "90", "180", "270", "flipped", ...)')
    parser.add_argument("--vrr", help="Variable refresh rate: on, off, or on-demand")
    state_group = parser.add_mutually_exclusive_group()
    state_group.add_argument("--off", action="store_true", help="Disable the output in output.kdl")
    state_group.add_argument("--on", action="store_true", help="Enable the output (remove off) in output.kdl")
    parser.add_argument("--bulk", help="JSON array of output configuration objects")
    parser.add_argument("--config", help="Override path to output.kdl")
    parser.add_argument("--no-reload", action="store_true", help="Do not invoke niri msg action load-config-file")
    parser.add_argument(
        "--allow-clamshell-internal",
        action="store_true",
        help="Bypass lid-closed clamshell internal-screen guard",
    )
    args = parser.parse_args()

    reload_cfg = not args.no_reload
    respect_clamshell = not args.allow_clamshell_internal

    if args.bulk:
        bulk_data = json.loads(args.bulk)
        if not isinstance(bulk_data, list):
            raise SystemExit("--bulk payload must be a JSON array")
        update_multiple_outputs(
            bulk_data,
            config_path=args.config,
            reload_config=reload_cfg,
            respect_clamshell=respect_clamshell,
        )
    elif args.connector:
        off_val: bool | None = True if args.off else (False if args.on else None)
        update_multiple_outputs(
            [
                {
                    k: v
                    for k, v in {
                        "connector": args.connector,
                        "x": args.x,
                        "y": args.y,
                        "scale": args.scale,
                        "mode": args.mode,
                        "transform": args.transform,
                        "vrr": _parse_vrr_arg(args.vrr),
                        "off": off_val,
                    }.items()
                    if v is not None
                }
            ],
            config_path=args.config,
            reload_config=reload_cfg,
            respect_clamshell=respect_clamshell,
        )
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
