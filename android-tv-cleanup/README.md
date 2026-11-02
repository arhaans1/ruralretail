# Android TV / Google TV cleanup (made for a Sansui Google TV)

Makes a slow Google TV faster by **switching off** preinstalled bloatware you never use,
clearing cache, and optimising apps so they open faster.

- **Nothing is uninstalled.** Apps are only switched off, and one command switches them all back on.
- **Your own apps are never touched.** Anything you installed from the Play Store is left alone.
- **It asks before every change.**

## What is ADB? (no cables needed)

ADB ("Android Debug Bridge") is a free tool from Google that lets a computer send
commands to an Android device. Your Google TV runs Android, so a laptop on the
**same Wi-Fi** can connect to it wirelessly with ADB, with no cable. This is
what the YouTube videos show: Claude runs on a laptop at home and uses ADB to
talk to the TV over Wi-Fi.

You need a computer (Mac, Windows or Linux) at home on the same Wi-Fi as the TV.
The TV can't do this on its own, and a phone app can't do the same job.

## Option A: let Claude do it for you

1. Install **Claude Code** on your laptop (<https://claude.com/claude-code>), or use the Claude desktop app.
2. Do **step 1 and step 2** below (install ADB, turn on debugging on the TV).
3. Open this folder in Claude Code and say:
   *"Connect to my TV at 192.168.x.x and run tv-cleanup.sh check, then help me clean it."*
   Claude will run the commands and explain each app before switching it off.

## Option B: run it yourself

### 1. Install ADB on your computer
- **Mac:** install [Homebrew](https://brew.sh), then `brew install android-platform-tools`
- **Windows:** download "SDK Platform-Tools for Windows" from
  <https://developer.android.com/tools/releases/platform-tools>, unzip it, and add the
  folder to your PATH. Run the script from **Git Bash** (<https://git-scm.com>).
- **Linux:** `sudo apt install adb`

Check it works: `adb version`

### 2. Turn on debugging on the TV (one-time, about 2 minutes)
1. On the TV: **Settings → System → About**.
2. Scroll to **Android TV OS build** and press OK on it **7 times** until it says
   "You are now a developer".
3. Go back to **Settings → System → Developer options**.
4. Turn on **USB debugging**, and also **Wireless debugging / Network debugging** if listed.
5. Note the TV's IP address: **Settings → Network & Internet → your Wi-Fi name** (looks like `192.168.1.50`).

### 3. Connect
```bash
cd android-tv-cleanup
./tv-cleanup.sh connect 192.168.1.50      # your TV's IP address
```
A popup appears on the TV: tick **Always allow from this computer** and press **OK**.

**If that doesn't connect** (common on newer Google TVs): on the TV open
**Developer options → Wireless debugging → Pair device with pairing code**. It shows an
IP:port and a 6-digit code. Then run:
```bash
adb pair 192.168.1.50:37123                  # IP:port from the pairing screen, then type the code
./tv-cleanup.sh connect 192.168.1.50:41234   # IP:port shown under "IP address & port"
```

### 4. Clean and speed up
| Command | What it does | Changes anything? |
|---|---|---|
| `./tv-cleanup.sh check` | Shows storage, memory, heaviest apps, and which apps could be switched off | No |
| `./tv-cleanup.sh clean` | Switches off bloatware. Asks first | Yes (reversible) |
| `./tv-cleanup.sh speedup` | Clears cache, stops background apps, optimises apps to open faster, optionally faster animations | Yes (safe) |
| `./tv-cleanup.sh restore` | Switches back on everything `clean` turned off | Yes |
| `./tv-cleanup.sh speedup-undo` | Puts animations back to normal speed | Yes |

Order: `check` → `clean` → `speedup` → **restart the TV**.

`clean` has three steps:
1. **Hidden background apps** that no TV needs (printing, feedback, basic screensavers). It asks once for the group.
2. **Optional Google extras** (YouTube Music, YouTube Kids, Chromecast, ambient screensaver, text-to-speech). It asks one by one.
3. **Apps that came preinstalled by Sansui or its partners.** It lists each one by its package name
   (e.g. `com.something.appname`) and asks one by one. Say **y** only to apps you never open.
   If you're not sure what one is, say **n**.

## What it never touches
- Apps you installed yourself.
- The home screen, Settings, Play Store, Google Play Services, Google Assistant / voice search,
  the remote, setup, HDMI/inputs and Live TV.

## More ways to make it faster
- **Storage:** `check` shows how full it is. Above ~85% full, Google TVs slow down a lot.
  Clear cache inside big apps, or remove ones you don't use.
- **Apps-only mode:** in **Settings → Accounts & Sign-in → your account → Apps only mode**.
  It turns off the home-screen movie and show suggestions. The home screen becomes much
  lighter and faster, but you lose the recommendations and Play Movies.
- **Restart weekly:** budget TVs have about 1.5–2 GB of memory. A restart clears it.
- **Update:** Settings → System → About → System update, and update apps in the Play Store.

## Undo
`./tv-cleanup.sh restore` switches everything back on. It reads the list from
`removed-packages.log` in this folder, so keep that file. You can also switch any app back on
from the TV: **Settings → Apps → See all apps → Show system apps → (app) → Enable**.
