# MPV for iOS

[![mpv](https://img.shields.io/badge/mpv-v0.41.0-blue.svg)](https://github.com/mpv-player/mpv)
[![ffmpeg](https://img.shields.io/badge/ffmpeg-n9.0.2-blue.svg)](https://github.com/FFmpeg/FFmpeg)
[![license](https://img.shields.io/github/license/mpvkit/MPVKit)](https://github.com/mpvkit/MPVKit/main/LICENSE)

> A video player for iPhone (could be used on iPad)
>
> This repo is for personal use and will not be maintained frequently


Forked from [MPVKit](https://github.com/mpvkit/MPVKit)

## Requirements
iOS 16.4 or later, a computer, USB cable, Apple ID.

## Installation

### Install SideStore
1. On your phone, turn on **Developer Mode**: Settings → Privacy & Security → Developer Mode (if it is not shown, connect the device to your computer first), then restart.
2. Download [iloader](https://iloader.site/) on your computer and open it.
3. Connect your device with the cable, unlock it, and tap **Trust**.
4. In iloader, sign in with your Apple ID and install **SideStore** (choose the **stable** version).
5. On your phone: Settings → General → VPN & Device Management → tap your Apple ID → **Trust**.
6. In iloader, open **Manage Pairing File** and click **Place Pairing File** next to SideStore.

### Install LocalDevVPN

1. Install **LocalDevVPN** from the App Store.
2. Open it, turn it on, and allow the VPN configuration.
3. Keep it on whenever you install or refresh apps with SideStore.

### Install mpv

1. Download `mpv.ipa` from the [Releases](https://github.com/th3end-vn/MPV_iOS/releases) page onto your phone (save it to the Files app).
2. Connect to Wi-Fi then turn on LocalDevVPN, tap **Connect**.
3. Open **SideStore** → **My Apps** → tap **+** → select `mpv.ipa`.
4. Wait for the install to finish, then open the app.

### Refresh every 7 days

Apps signed with a free Apple ID expire after **7 days**.

1. Turn on LocalDevVPN and connect to Wi-Fi.
2. Open **SideStore** → **My Apps** → tap **Refresh All** (or tap the days counter next to the app).

SideStore can also refresh in the background (Settings → Background Refresh), but this is not guaranteed. If an app has already expired, refresh it the same way.


## License

`MPVKit` source alone is licensed under the LGPL v3.0.

`MPVKit` bundles (`frameworks`, `xcframeworks`), which include both `libmpv` and `FFmpeg` libraries, are also licensed under the LGPL v3.0. However, if the source code is built using the optional `enable-gpl` flag or prebuilt binaries with `-GPL` postfix are used, then `MPVKit` bundles become subject to the GPL v3.0.
