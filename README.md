# iMut

A sample iOS client for Mut project

## Build instructions

1. Install and configure Gomobile (https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile).
2. Build [Mut](https://github.com/DeepAQ/Mut) project as iOS framework using command `gomobile bind -target ios github.com/DeepAQ/mut/core github.com/DeepAQ/mut/config`, and add `Core.framework` to the workspace.
3. Build the app with Xcode.

## License

iMut is licensed under GPLv3.
