# WakeUpAuto

WakeUpAuto is a macOS menu bar app that helps restore Wi-Fi when your MacBook wakes after you open the lid.

## How it works

After a lid-open wake, WakeUpAuto gives macOS five seconds to reconnect. It checks the Wi-Fi network you selected by pinging the router, with `1.1.1.1` as a fallback. If the check fails on that network, WakeUpAuto turns Wi-Fi off and back on, then checks again.

By default, Wi-Fi stays off for **3 seconds**, and the app allows **3 retries** after the first attempt. If recovery fails, the menu bar icon shows an exclamation mark and asks you to toggle Wi-Fi manually.

WakeUpAuto waits for system events while idle. Maintenance wakes and opening the lid while the MacBook is already awake with an external display leave the connection alone.

## Build and install

**Requirements:** A MacBook running macOS 27 or later, and Xcode with a macOS 27 SDK to build from source.

From the repository directory, run:

```sh
./build.sh
```

Open `build/WakeUpAuto.app` in Finder. You can copy it to **Applications** for regular use.

## Set up a network

1. Click the menu bar icon that looks like a laptop with a **Z**, then open **Settings…**.
2. Choose the Wi-Fi network to monitor. macOS asks for location access so the app can read Wi-Fi network names. You can also set how long Wi-Fi stays off and how many retries to allow.
3. Turn on **Launch at Login** if you want WakeUpAuto to start when you sign in.

Open **Diagnostics → Open Log…** to see sleep and wake events, connectivity checks, and recovery attempts. The log is stored locally at `~/Library/Logs/WakeUpAuto/WakeUpAuto.txt`. The app runs in the background without opening Terminal.

## License

[GNU General Public License v3.0](LICENSE).
