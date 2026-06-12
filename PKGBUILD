# niri-caelestia-shell-meta
# Maintainer: Cantfirmed <cantfirmed at gmx dot com>

pkgname='niri-caelestia-shell-meta'
pkgver=1.0.0
pkgrel=1
pkgdesc='Metapackage containing all dependencies for the Niri-Caelestia shell'
arch=('any')
url='https://github.com/Cantfirmed/niri-caelestia-shell'
license=('GPL-3.0-only')
depends=(
  # Shell
  'quickshell-git'
  'caelestia-cli'

  # Compositor
  'niri'

  # Build tools (required for the C++ QML plugin)
  'cmake'
  'ninja'
  'pkgconf'
  'gcc'
  'qt6-base'
  'qt6-declarative'
  'qt6-shadertools'

  # Core utilities
  'wl-clipboard'
  'cliphist'
  'brightnessctl'
  'ddcutil'
  'gpu-screen-recorder'
  'app2unit'
  'networkmanager'
  'lm_sensors'
  'libqalculate'
  'swappy'
  'fish'
  'bash'

  # Audio / Visualiser
  'pipewire'
  'wireplumber'
  'libcava'
  'aubio'
  'fftw'

  # Script helpers
  'python'
  'jq'
  'libnotify'
  'libxml2'

  # Fonts
  'ttf-rubik-vf'
  'ttf-material-symbols-variable-git'
  'ttf-cascadia-code-nerd'
)
optdepends=(
  'wl-mirror: display mirroring / duplicate mode for external monitors'
  'kitty: default terminal emulator'
  'firefox: default web browser'
  'dolphin: default file manager'
  'foot: alternate terminal emulator'
  'thunar: alternate file manager'
  'libcava: audio visualiser backend'
  'matugen: wallpaper-based colour scheme generation'
)
source=('SKIP')
sha256sums=('SKIP')

package() {
  mkdir -p "$pkgdir/"
}
