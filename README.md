# iMut

A sample iOS client for Mut project

## Build instructions

1. Install and configure Gomobile (https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile).
2. Build [Mut](https://github.com/DeepAQ/Mut) project as iOS framework using command `gomobile bind -target ios github.com/DeepAQ/mut/core github.com/DeepAQ/mut/config`, and add `Core.framework` to the workspace.
3. Checkout a copy of [tun2socks-iOS](https://github.com/shadowsocks/tun2socks-iOS/tree/be2ff1739f58a2c52eda65d092597f5f01b388dc), and apply [tun2socks-iOS.patch](tun2socks-iOS.patch).
4. Build `libtun2socks` target, and add the `libtun2socks.a` library to the workspace.
5. Build the app with Xcode.

## License

iMut is licensed under GPLv3.

This project contains 3rd-party open-source software:
- [tun2socks-iOS](https://github.com/shadowsocks/tun2socks-iOS)
