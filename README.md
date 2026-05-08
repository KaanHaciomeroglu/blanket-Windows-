<img src="brand/logo.svg" alt="Blanket" width="128" height="128" align="left"/>

# Blanket

**Listen to different sounds**

<br>

[![GNMOME Circle](https://gitlab.gnome.org/Teams/Circle/-/raw/master/assets/button/badge.svg)](https://circle.gnome.org/)
[![Please do not theme this app](https://stopthemingmy.app/badge.svg)](https://stopthemingmy.app)

[![GitHub](https://img.shields.io/github/license/rafaelmardojai/blanket.svg)](https://github.com/rafaelmardojai/blanket/blob/master/COPYING)
[![Donate](https://img.shields.io/badge/PayPal-Donate-gray.svg?style=flat&logo=paypal&colorA=0071bb&logoColor=fff)](https://paypal.me/RafaelMardojaiCM)
[![Liberapay](https://img.shields.io/liberapay/receives/rafaelmardojai.svg?logo=liberapay)](https://liberapay.com/rafaelmardojai/donate)

<p align="center">
  <img src="brand/screenshot-1-dark.png"/>
</p>

## Description
Improve focus and increase your productivity by listening to different sounds. Blanket can also be used to help you to fall asleep in a noisy environment.

## Install

<a href="https://flathub.org/apps/details/com.rafaelmardojai.Blanket"><img width="200" alt="Download on Flathub" src="https://flathub.org/api/badge?svg&locale=en"/></a>

### Third Party Packages 

| Distribution | Package | Maintainer |
|:-:|:-:|:-:|
| Alpine Linux (edge) | [`blanket`](https://pkgs.alpinelinux.org/packages?name=blanket) | mio |
| Arch Linux (extra) | [`blanket`](https://archlinux.org/packages/extra/any/blanket/) | [Balló György](https://github.com/City-busz) |
| Fedora (Copr) | Copr: [`tuxino/Blob`](https://copr.fedorainfracloud.org/coprs/tuxino/Blob/), package: `blanket` | Tuxino |
| NixOS | [`blanket`](https://search.nixos.org/packages?channel=unstable&show=blanket&from=0&size=50&sort=relevance&type=packages&query=blanket) | onny |
| openSUSE  | [`blanket`](https://build.opensuse.org/package/show/multimedia%3Aapps/blanket) | [Michael Vetter](https://github.com/jubalh) |
| Ubuntu (PPA) | [`Stable Releases`](https://launchpad.net/~apandada1/+archive/ubuntu/blanket), [`Daily Builds`](https://launchpad.net/~apandada1/+archive/ubuntu/blanket-daily) | [Archisman Panigrahi](https://github.com/apandada1) |
| MX Linux | [`blanket`](http://mxrepo.com/mx/repo/pool/main/b/blanket/) | [SwampRabbit](https://github.com/SwampRabbit) |

### Build from source (Linux)

You can clone and run from GNOME Builder.

#### Requirements

- Python 3 `python`
- PyGObject `python-gobject`
- GTK4 `gtk4`
- libadwaita (>= 1.5.0) `libadwaita`
- GStreamer 1.0 `gstreamer`
- Meson `meson`
- Ninja `ninja`

Alternatively, use the following commands to build it with meson.
```bash
meson builddir --prefix=/usr/local
sudo ninja -C builddir install
```

### Windows — Otomatik Kurulum (Önerilen)

Tek komutla her şeyi kurar: MSYS2 (yoksa), bağımlılıklar, UI derleme ve başlatıcı oluşturma.

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

Kurulum sonunda `Blanket.bat` oluşur — çift tıklayarak uygulamayı başlatabilirsiniz.

---

### Build from source (Windows — Manuel)

Blanket runs on Windows via [MSYS2](https://www.msys2.org/). The Linux-only features (MPRIS media keys, D-Bus, PulseAudio) are automatically disabled; all sounds and UI work normally.

#### 1. Install MSYS2

Download and install MSYS2 from https://www.msys2.org/. The default install path (`C:\msys64`) is assumed; if you install elsewhere, add the `mingw64\bin` directory to your PATH.

#### 2. Install dependencies

Open the **MSYS2 MinGW64** shell and run:

```bash
pacman -S mingw-w64-x86_64-gtk4 \
           mingw-w64-x86_64-libadwaita \
           mingw-w64-x86_64-gstreamer \
           mingw-w64-x86_64-gst-plugins-base \
           mingw-w64-x86_64-gst-plugins-good \
           mingw-w64-x86_64-python-gobject \
           mingw-w64-x86_64-blueprint-compiler
```

#### 3. Clone the repository

```powershell
git clone https://github.com/rafaelmardojai/blanket.git
cd blanket
```

#### 4. Build resources

Run once to compile UI templates, icons, sounds, and GSettings schema:

```powershell
python setup_windows.py
```

This generates a `build/` directory containing `blanket.gresource` and `gschemas.compiled`.

#### 5. Run

```powershell
python run_windows.py
```

`run_windows.py` automatically detects and uses MSYS2's Python (which has PyGObject), so you can run it from any shell — no need to open the MSYS2 shell each time.

> **Note:** Re-run `setup_windows.py` only when UI files or sounds change. Normal Python edits do not require a rebuild.

## Translations
Blanket is translated into several languages. If your language is missing or incomplete, please help to [translate Blanket in Weblate](https://hosted.weblate.org/engage/blanket/).

<a href="https://hosted.weblate.org/engage/blanket/">
<img src="https://hosted.weblate.org/widget/blanket/blanket/horizontal-auto.svg" alt="Translation status" />
</a>

## Credits
Developed by **[Rafael Mardojai CM](https://github.com/rafaelmardojai)** and [contributors](https://github.com/rafaelmardojai/blanket/graphs/contributors).

Thanks to Jorge Toledo for the name idea.

For detailed information about sounds licensing, [check this file](https://github.com/rafaelmardojai/blanket/blob/master/SOUNDS_LICENSING.md).

## Donate
If you want to support my work, you can donate me, [here you can find how](https://rafaelmardojai.com/donate/).

## Related Projects
- [Blankie](https://github.com/codybrom/blankie) - Native macOS app inspired by Blanket
- [feeltheblow](https://feeltheblow.web.app/) - Web App inspired by Blanket
- [Soothing Noise Player](https://f-droid.org/en/packages/ie.delilahsthings.soothingloop/),  [Napify](https://github.com/itsPronay/napify) - Android apps inspired by Blanket
- [Blanket Web](https://apps.roanapur.de/blanket/) - Web clone of Blanket
- [Blanket+](https://apps.microsoft.com/detail/9P4VKD1WQQ9G?hl=neutral&gl=TR&ocid=pdpshare) - Windows version of blanket
