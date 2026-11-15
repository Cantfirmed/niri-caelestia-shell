#!/usr/bin/env python3
"""wallfx.py — wallpaper transition maps generator for Caelestia Shell.

Adapted from pocket-dots for Caelestia Quickshell on Wayland/Niri.
Generates 16-bit packed PNG maps for the wallfx shader transition:
  - Contagion: procedural Dijkstra wave-front over Perlin noise in 4px cells.
    Cached into a 12-map pool in ~/.cache/caelestia/wallfx/spread/.
  - Outline: character silhouette cutout via BiRefNet/rembg.
    Precomputed and cached in ~/.cache/caelestia/wallfx/perfil/.
    Falls back cleanly to contagion when rembg/cv2 is unavailable or no character is detected.

Usage:
  wallfx.py spread                     Outputs path to map and smooth map from pool
  wallfx.py elige [auto|perfil|contagio] <img_path>
                                       Outputs 'perfil <map> <line>' or 'contagio <map> <smooth>'
  wallfx.py warm [folder]              Precomputes contagion pool and wallpaper outlines
  wallfx.py perfil <img_path> [--force]
                                       Generates outline map for image; exits 1 if no character
  wallfx.py instalar                   Sets up AI cutout venv using uv
"""

import hashlib
import heapq
import json
import os
import random
import sys

HOME = os.path.expanduser("~")
CACHE = os.path.join(HOME, ".cache", "caelestia", "wallfx")
CONFIG_DIR = os.path.join(HOME, ".config", "caelestia")
VENV = os.path.join(HOME, ".local", "share", "caelestia", "wallfx")
VENV_PY = os.path.join(VENV, "venv", "bin", "python")
WALLS = os.path.join(HOME, "Pictures", "Wallpapers")
if not os.path.isdir(WALLS):
    WALLS = os.path.join(HOME, "Pictures", "wallpapers")

GW, GH = 240, 135
POOL = 12
FIELD_MAX = 1280
SD_RANGE = 16.0
WIDE = 48.0


def _reexec_in_venv():
    """If this python lacks the AI cutout environment, hand over to venv."""
    if sys.executable != VENV_PY and os.path.exists(VENV_PY):
        os.execv(VENV_PY, [VENV_PY, os.path.abspath(__file__), *sys.argv[1:]])


# ───────────────────────────── contagion ─────────────────────────────

def _value_noise(rng, w, h, scale):
    import numpy as np
    nx, ny = int(w / scale) + 3, int(h / scale) + 3
    lat = rng.random((ny, nx))
    xs = np.arange(w) / scale
    ys = np.arange(h) / scale
    ix, iy = xs.astype(int), ys.astype(int)
    fx, fy = xs - ix, ys - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    top = lat[iy][:, ix] * (1 - fx) + lat[iy][:, ix + 1] * fx
    bot = lat[iy + 1][:, ix] * (1 - fx) + lat[iy + 1][:, ix + 1] * fx
    return top * (1 - fy)[:, None] + bot * fy[:, None]


def _blur(a, sigma):
    """Separable Gaussian blur in pure numpy."""
    import numpy as np
    r = int(3 * sigma) + 1
    x = np.arange(-r, r + 1)
    k = np.exp(-x * x / (2.0 * sigma * sigma))
    k /= k.sum()
    a = np.pad(a, r, mode="edge")
    a = sum(k[i] * a[:, i:i + a.shape[1] - 2 * r] for i in range(2 * r + 1))
    a = sum(k[i] * a[i:i + a.shape[0] - 2 * r, :] for i in range(2 * r + 1))
    return a


def _rgb16(v, extra=None):
    """A 0..1 field as 16 bits in G (high) and B (low)."""
    import numpy as np
    q = np.clip(v * 65535.0 + 0.5, 0, 65535).astype(np.uint16)
    rgb = np.zeros(v.shape + (3,), np.uint8)
    if extra is not None:
        rgb[..., 0] = extra
    rgb[..., 1] = q >> 8
    rgb[..., 2] = q & 255
    return rgb


_STEPS = [(-1, 0, 1.0), (1, 0, 1.0), (0, -1, 1.0), (0, 1, 1.0),
          (-1, -1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (1, 1, 1.4142)]


def _arrival(cost, seeds, GW=GW, GH=GH):
    """Dijkstra over a GW x GH cost grid from (index, start time) seeds."""
    INF = float("inf")
    arrival = [INF] * (GW * GH)
    heap = []
    for i, t0 in seeds:
        arrival[i] = t0
        heap.append((t0, i))
    heapq.heapify(heap)
    while heap:
        t, i = heapq.heappop(heap)
        if t != arrival[i]:
            continue
        x, y = i % GW, i // GW
        ci = cost[i]
        for dx, dy, d in _STEPS:
            nx, ny = x + dx, y + dy
            if 0 <= nx < GW and 0 <= ny < GH:
                j = ny * GW + nx
                cand = t + (ci + cost[j]) * 0.5 * d
                if cand < arrival[j]:
                    arrival[j] = cand
                    heapq.heappush(heap, (cand, j))
    return arrival


def _ranked(arrival, shape=(GH, GW)):
    """Arrival times ranked to 0..65535 for steady area expansion."""
    import numpy as np
    a = np.array(arrival)
    rank = np.empty(a.size)
    rank[np.argsort(a, kind="stable")] = np.arange(a.size)
    return (rank / (a.size - 1) * 65535).astype(np.uint16).reshape(shape)


def contagion_map(seed):
    """Generates a contagion map (480x270: 4px cells on 1080p)."""
    import numpy as np
    w, h = GW * 2, GH * 2
    rng = np.random.default_rng(seed)
    n = (0.52 * _value_noise(rng, w, h, rng.uniform(18, 65))
         + 0.30 * _value_noise(rng, w, h, rng.uniform(7, 20))
         + 0.18 * _value_noise(rng, w, h, rng.uniform(2, 6)))
    cost = 0.12 + np.exp(rng.uniform(5, 9) * (n - 0.5)) + rng.uniform(0.15, 0.65) * rng.random((h, w))
    cost = cost.ravel().tolist()
    seeds = []
    for _ in range(int(rng.integers(6, 13))):
        x, y = int(rng.uniform(0.06, 0.94) * w), int(rng.uniform(0.08, 0.92) * h)
        seeds.append((y * w + x, float(rng.uniform(0, (w * h) ** 0.5 * 0.12))))
    return _ranked(_arrival(cost, seeds, w, h), (h, w))


def _write_pair(path, liso, a):
    """Write contagion map and smooth blurred twin."""
    import numpy as np
    from PIL import Image
    h, w = a.shape
    rgb = np.zeros((h, w, 3), np.uint8)
    rgb[..., 0] = a >> 8
    rgb[..., 1] = a & 255
    smooth = _blur(a.astype(np.float64) / 65535.0, 2.5)
    for dest, arr in ((path, rgb), (liso, _rgb16(smooth))):
        tmp = f"{dest}.{os.getpid()}.tmp.png"
        Image.fromarray(arr, "RGB").save(tmp)
        os.replace(tmp, dest)


def spread():
    """Returns (map, smooth) from the pool."""
    d = os.path.join(CACHE, "spread")
    os.makedirs(d, exist_ok=True)
    k = random.randrange(POOL)
    path = os.path.join(d, f"spread-{k}.png")
    liso = os.path.join(d, f"spread-{k}-liso.png")
    if not (os.path.exists(path) and os.path.exists(liso)):
        _write_pair(path, liso, contagion_map(random.randrange(1 << 30)))
    return path, liso


def renew(path):
    """Replace a used pool map with a fresh one in the background."""
    import time
    time.sleep(4)
    k = os.path.basename(path).split("-")[1].split(".")[0]
    d = os.path.dirname(path)
    _write_pair(os.path.join(d, f"spread-{k}.png"), os.path.join(d, f"spread-{k}-liso.png"),
                contagion_map(random.randrange(1 << 30)))


# ───────────────────────────── outline ─────────────────────────────

def _key(img):
    st = os.stat(img)
    return hashlib.sha1(f"{os.path.realpath(img)}|{st.st_size}|{int(st.st_mtime)}".encode()).hexdigest()[:16]


_session = None


def _get_session():
    global _session
    if _session is None:
        os.environ.setdefault("U2NET_HOME", os.path.join(VENV, "models"))
        from rembg import new_session
        try:
            _session = new_session("birefnet-general-lite")
        except Exception:
            _session = new_session("u2net")
    return _session


def perfil(img, force=False):
    """(map, line) for IMG, or None when unavailable or no character detected."""
    d = os.path.join(CACHE, "perfil")
    os.makedirs(d, exist_ok=True)
    base = os.path.join(d, _key(img))
    meta_path = base + ".json"
    if not force and os.path.exists(meta_path):
        try:
            meta = json.load(open(meta_path))
            if not meta.get("ok"):
                return None
            if os.path.exists(base + "-campo.png") and os.path.exists(base + "-linea.png"):
                return base + "-campo.png", base + "-linea.png"
        except (OSError, ValueError):
            pass

    try:
        import cv2
        import numpy as np
        from PIL import Image
        from rembg import remove
    except ImportError:
        return None

    import fcntl
    lock = open(base + ".lock", "w")
    fcntl.flock(lock, fcntl.LOCK_EX)
    if not force and os.path.exists(meta_path):
        try:
            meta = json.load(open(meta_path))
            if not meta.get("ok"):
                return None
            if os.path.exists(base + "-campo.png") and os.path.exists(base + "-linea.png"):
                return base + "-campo.png", base + "-linea.png"
        except (OSError, ValueError):
            pass

    try:
        im = Image.open(img).convert("RGB")
        im.thumbnail((FIELD_MAX, FIELD_MAX))
        mask_path = base + "-mascara.png"
        if os.path.exists(mask_path):
            mask = Image.open(mask_path).convert("L")
        else:
            session = _get_session()
            mask = remove(im, session=session, only_mask=True).convert("L")
            mask.save(mask_path)
        m = np.asarray(mask.resize(im.size), np.float32) / 255.0
        h, w = m.shape
        b = (m > 0.5).astype(np.uint8)
        n, lab, stats, _ = cv2.connectedComponentsWithStats(b, connectivity=8)
        keep = np.zeros(n, bool)
        keep[1:] = stats[1:, cv2.CC_STAT_AREA] >= 0.002 * w * h
        b = keep[lab].astype(np.uint8)
        cover = float(b.mean())
        unsure = float(((m > 0.1) & (m < 0.9)).mean())
        ok = 0.008 <= cover <= 0.72 and unsure <= 0.085
        meta = {"img": img, "ok": ok, "cover": round(cover, 3), "unsure": round(unsure, 3), "w": w, "h": h}
        if not ok:
            json.dump(meta, open(meta_path, "w"))
            return None

        din = cv2.distanceTransform(b, cv2.DIST_L2, 5)
        dout = cv2.distanceTransform(1 - b, cv2.DIST_L2, 5)
        sd = dout - din
        inner = np.clip(din / max(np.percentile(din[b > 0], 99), 1.0), 0, 1)

        rng = np.random.default_rng(int(_key(img)[:8], 16))
        noise = (0.6 * _value_noise(rng, w, h, w / 9.0) + 0.4 * _value_noise(rng, w, h, w / 28.0))
        warped = dout * (0.75 + 0.5 * noise) + noise * 0.08 * max(w, h)
        outside = b == 0
        order = np.zeros((h, w), np.float32)
        vals = warped[outside]
        r = np.empty(vals.size)
        r[np.argsort(vals, kind="stable")] = np.arange(vals.size)
        order[outside] = r / max(vals.size - 1, 1)

        edge = np.zeros((h, w), np.uint8)
        param_at = np.zeros((h, w), np.float32)
        contours, _ = cv2.findContours(b, cv2.RETR_LIST, cv2.CHAIN_APPROX_NONE)
        for c in contours:
            if len(c) < 40 or abs(cv2.contourArea(c)) < 0.0008 * w * h:
                continue
            c = c[:, 0, :]
            seg = np.sqrt((np.diff(c, axis=0, append=c[:1]) ** 2).sum(1))
            s = np.concatenate([[0], np.cumsum(seg)[:-1]])
            L = s[-1] + seg[-1]
            s = (s - s[np.argmin(c[:, 1])]) % L
            p = np.minimum(s, L - s) / (L / 2)
            p[(c[:, 0] <= 1) | (c[:, 0] >= w - 2) | (c[:, 1] <= 1) | (c[:, 1] >= h - 2)] = -1
            edge[c[:, 1], c[:, 0]] = 1
            param_at[c[:, 1], c[:, 0]] = p
        line = np.zeros((h, w), np.uint8)
        if edge.any():
            _, labels = cv2.distanceTransformWithLabels(1 - edge, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
            ys, xs = np.nonzero(edge)
            table = np.concatenate([[0], param_at[ys, xs]])
            near = np.abs(sd) < SD_RANGE
            v = table[labels[near]]
            line[near] = np.where(v < 0, 0, np.clip(v * 255, 1, 255)).astype(np.uint8)

        rgb = np.zeros((h, w, 3), np.uint8)
        rgb[..., 0] = np.clip(dout / WIDE * 255, 0, 255)
        rgb[..., 1] = np.clip(inner * 255, 0, 255)
        rgb[..., 2] = np.clip((sd + SD_RANGE) / (2 * SD_RANGE) * 255, 0, 255)
        smooth = cv2.GaussianBlur(order.astype(np.float32), (0, 0), 4.0)
        linea = _rgb16(smooth, extra=line)
        for suffix, arr, mode in (("-campo.png", rgb, "RGB"), ("-linea.png", linea, "RGB")):
            tmp = f"{base}{suffix}.{os.getpid()}.tmp.png"
            Image.fromarray(arr, mode).save(tmp)
            os.replace(tmp, base + suffix)
        json.dump(meta, open(meta_path, "w"))
        return base + "-campo.png", base + "-linea.png"
    except Exception:
        return None


def contagio(img=None):
    """Returns contagion maps: picks from pool and renews slot in background."""
    path, liso = spread()
    if os.fork() == 0:
        try:
            null = os.open(os.devnull, os.O_RDWR)
            for fd in (0, 1, 2):
                os.dup2(null, fd)
            os.setsid()
            renew(path)
        finally:
            os._exit(0)
    return path, liso


def sin_perfil():
    try:
        with open(os.path.join(CONFIG_DIR, "sin-perfil")) as f:
            return {l.strip() for l in f if l.strip() and not l.startswith("#")}
    except OSError:
        return set()


def warm(folder=None):
    """Precomputes contagion pool maps and wallpaper character outlines."""
    d = os.path.join(CACHE, "spread")
    os.makedirs(d, exist_ok=True)
    for k in range(POOL):
        path, liso = os.path.join(d, f"spread-{k}.png"), os.path.join(d, f"spread-{k}-liso.png")
        if not (os.path.exists(path) and os.path.exists(liso)):
            _write_pair(path, liso, contagion_map(random.randrange(1 << 30)))

    target_dir = folder or WALLS
    if os.path.isdir(target_dir):
        exts = (".jpg", ".jpeg", ".png", ".webp")
        for name in sorted(os.listdir(target_dir)):
            path = os.path.join(target_dir, name)
            if name.lower().endswith(exts) and os.path.isfile(path):
                try:
                    r = perfil(path)
                    print(("perfil   " if r else "contagio ") + " " + name, flush=True)
                except Exception as e:
                    print(f"error    {name}: {e}", file=sys.stderr, flush=True)


def instalar():
    """Sets up the AI cutout environment using uv."""
    import shutil
    import subprocess
    uv = shutil.which("uv")
    if not uv:
        print("wallfx: uv is needed (sudo pacman -S uv)", file=sys.stderr)
        return 1
    os.makedirs(VENV, exist_ok=True)
    subprocess.run([uv, "venv", "-q", os.path.join(VENV, "venv")], check=True)
    subprocess.run([uv, "pip", "install", "-q", "--python", VENV_PY,
                    "rembg", "onnxruntime", "opencv-python-headless", "numpy", "pillow"], check=True)
    print("wallfx: AI cutout environment installed successfully.")
    return 0


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    cmd, rest = argv[0], argv[1:]
    if cmd in ("perfil", "warm", "elige", "instalar"):
        _reexec_in_venv()

    if cmd == "spread":
        print(*contagio(None))
        return 0
    if cmd == "perfil":
        r = perfil(rest[0], force="--force" in rest)
        if not r:
            return 1
        print(*r)
        return 0
    if cmd == "warm":
        warm(rest[0] if rest else None)
        return 0
    if cmd == "instalar":
        return instalar()
    if cmd == "elige":
        mode_pref = "auto"
        img = None
        if len(rest) >= 2:
            mode_pref = rest[0]
            img = rest[1]
        elif len(rest) == 1:
            img = rest[0]

        if not img:
            print("wallfx elige: image path required", file=sys.stderr)
            return 1

        if mode_pref == "contagio" or os.path.basename(img) in sin_perfil():
            print("contagio", *contagio(img))
            return 0

        # Try perfil
        r = perfil(img)
        if r:
            print("perfil", *r)
        else:
            print("contagio", *contagio(img))
        return 0

    print(f"wallfx: unknown command '{cmd}'", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
