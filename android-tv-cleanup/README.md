# Android TV / Google TV cleanup

A small tool to make a slow Android TV or Google TV faster. It removes preinstalled
bloatware, frees cache and stops background apps. It runs on a laptop or desktop
on the **same Wi-Fi as the TV** and talks to the TV over ADB (Android's debugging
connection). Nothing is deleted permanently: system apps are only removed for
the TV's user account, and `restore` brings them back.

## 1. Install ADB on your computer

- **Mac:** install [Homebrew](https://brew.sh), then run `brew install android-platform-tools`
- **Windows:** download "SDK Platform-Tools for Windows" from
  <https://developer.android.com/tools/releases/platform-tools>, unzip it, and add
  the folder to your PATH. Run the script from **Git Bash** (<https://git-scm.com>).
- **Linux:** `sudo apt install adb`

Check it works: `adb version`

## 2. Turn on debugging on the TV (one-time)

1. **Settings → System → About** (on older TVs: Settings → Device Preferences → About).
2. Scroll to **Android TV OS build** (or **Build**) and press OK on it **7 times**,
   until it says "You are now a developer".
3. Go back. Open **Settings → System → Developer options**.
4. Turn on **USB debugging**, and also **Network debugging** or **Wireless debugging**
   if you see it.
5. Note the TV's IP address: **Settings → Network & Internet → your Wi-Fi network**.

## 3. Connect

```bash
cd android-tv-cleanup
./tv-cleanup.sh connect 192.168.1.50      # use your TV's IP address
```

A popup appears on the TV: tick **Always allow from this computer** and press **OK**.

**Pairing with a code (newer Google TV, e.g. Chromecast with Google TV / Android 12+):**
if `connect` fails, open **Developer options → Wireless debugging → Pair device with
pairing code**. The TV shows an IP:port and a 6-digit code. Run:

```bash
adb pair 192.168.1.50:37123               # IP:port from the pairing screen; enter the code
./tv-cleanup.sh connect 192.168.1.50:41234   # IP:port shown under "IP address & port"
```

## 4. Use it

| Command | What it does | Changes anything? |
|---|---|---|
| `./tv-cleanup.sh check` | Shows free storage, memory, the heaviest apps and which bloatware is installed | No |
| `./tv-cleanup.sh clean` | Removes bloatware. Asks before each step and each optional app | Yes |
| `./tv-cleanup.sh speedup` | Clears app cache, stops background apps, optionally makes animations faster | Yes (safe) |
| `./tv-cleanup.sh speedup-undo` | Puts animations back to normal | Yes |
| `./tv-cleanup.sh restore` | Puts back every system app that `clean` removed | Yes |

Suggested order: `check` → `clean` → `speedup` → **restart the TV**.

`clean` has three steps:
1. **Unneeded system apps** (printing, feedback, basic screensavers). It asks once for all of them.
2. **Preinstalled apps you might use** (YouTube Music, Netflix, Prime Video, brand promo apps, Chromecast…). It asks one by one, so say **No** to anything you watch.
3. **Apps installed later** from the Play Store or by the shop. It asks one by one. These are
   fully uninstalled; reinstall them from the Play Store if needed. "Cleaner", "booster"
   and "antivirus" apps usually make a TV *slower*, so they're good to remove.

## What it never touches

The home screen, Google Play Services, Play Store, Google Assistant / voice search,
remote control, setup, HDMI/inputs and Settings. Removing those can stop the TV
from working, so they aren't in `packages.txt`. You can add or remove entries in
`packages.txt` yourself: one line per app, `package | SAFE or OPTIONAL | description`.

## If the TV is still slow

- **Storage:** `check` shows how full the storage is. Above ~85% full, an Android TV
  slows down a lot. Remove big apps you don't use.
- **Restart regularly:** most budget TVs have 1.5–2 GB of RAM. A restart once a week helps.
- **Update:** Settings → System → About → System update, and update apps in the Play Store.
- **Last resort:** a factory reset (Settings → System → Reset) followed by `clean` before
  installing your own apps.

## Undo everything

`./tv-cleanup.sh restore` brings back every system app that `clean` removed. It reads
the list from `removed-packages.log` in this folder, so keep that file. A factory
reset also restores everything.
