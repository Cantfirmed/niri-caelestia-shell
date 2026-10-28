# Biri Shaders Live Uniform Studio & M3 Palette Binding

## Status: Done

## Description
Expand the Biri shader integration (`services/BiriShaders.qml`) with real-time GLSL uniform control and automatic Material 3 color binding.
Users can tweak shader parameters (blur, chromatic aberration, glow spread, scanline density, vignette) using live sliders in Nexus, while pulse rings and border effects dynamically derive their color palettes directly from the active theme (`Colours.palette`).

## Checklist
- [x] Profile shader compilation and reload latency in Niri (`niri/shaders/`)
- [x] Add interactive parameter sliders in `modules/nexus/pages/ShadersPage.qml`
- [x] Implement template generator injecting Material 3 theme colors (`m3primary`, `m3tertiary`, `m3surface`) into GLSL sources on theme switch
- [x] Add quick preset manager (Cyberpunk, Retro CRT, Minimal Clean, Ambient Glow)
- [x] Benchmark GPU utilization across active shader presets
