<p align="center">
  <img src="assets/icon-1024.png" width="128" alt="Pinch icon">
</p>

<h1 align="center">Pinch</h1>

<p align="center">Turn AirPods stem presses into keyboard shortcuts on your Mac.</p>

![A wireframe AirPods Pro with one, two and three presses mapped to Play / Pause, Option Space and Previous track](assets/hero.png)

## Getting started

1. **Install Pinch.** With Homebrew:

   ```sh
   brew tap rainnworks/tap && brew trust rainnworks/tap
   brew install --cask pinch
   ```

   Or download the latest `Pinch-x.y.z.dmg` from [Releases](https://github.com/RainnWorks/pinch/releases), open it and drag Pinch to Applications.
2. **Open Pinch.** It appears in the menu bar and the Dock.
3. **Allow Accessibility.** Pinch needs it to send key presses. macOS asks on the first launch. If you miss it, the menu bar icon shows a warning triangle: choose **Open Accessibility Settings…** from its menu and turn Pinch on. Pinch restarts itself when the permission arrives.
4. **Double press a stem.** Pinch sends ⌥ Space. To change what each press does, open **Settings** with ⌘,.
5. **Optional:** turn on **Open at login** in Settings.

Pinch needs macOS 14 or later. It checks for updates by itself, or choose **Check for Updates…** from its menu.

## Use

Open **Settings** from the menu bar icon, the Dock icon, or ⌘,.

Pick an action for each press:

| Press | Default | Options |
|---|---|---|
| Single | Play / Pause | Music, a shortcut, or nothing |
| Double | ⌥ Space | Music, a shortcut, or nothing |
| Triple | Previous track | Music, a shortcut, or nothing |

To set a shortcut, choose **Shortcut**, click the button, then type the keys. Esc cancels.

**Music** passes the press on to Spotify, or to Music if Spotify is not open. The first time, macOS asks you to allow Pinch to control that app.

The menu bar menu lists the last 15 presses and what Pinch did with each one.

## How it works

![AirPods stem presses flow through macOS now playing to Pinch, then to a keyboard shortcut or Spotify / Music](assets/how-it-works.png)

AirPods do not act as a keyboard. macOS sends each stem press to whichever app is "now playing", so key remappers such as Karabiner never see it.

Pinch plays silent audio to become the now playing app, and then receives the presses itself. When a press is set to **Music**, Pinch sends it on to Spotify or Music, and one second later takes the now playing slot back.

## Limits

- **Both buds do the same thing.** The AirPods do report which bud you pressed, but macOS gives that only to Apple's own software.
- **Press and hold is not available.** macOS keeps it for noise control and Siri.
- **Another media app can take the presses.** If Spotify or Music starts playing by itself, choose **Reclaim now playing** from the menu.
- **The silent audio keeps the AirPods connected to the Mac.** This uses a little AirPods battery, and the AirPods switch less readily to your iPhone.

## Build from source

```sh
./build.sh
open Pinch.app
```

This makes an ad-hoc signed build. macOS treats each rebuild as a new app, so you must allow Accessibility again after each one.

## Release

Set the new version in `VERSION`, commit, then push a matching tag:

```sh
git tag v$(cat VERSION) && git push origin v$(cat VERSION)
```

GitHub Actions then:

1. builds Pinch and signs it with the RainnWorks Developer ID, through
   [`RainnWorks/apple-signing`](https://github.com/RainnWorks/apple-signing),
2. packs it in a DMG and has Apple notarize it,
3. publishes the DMG and a Sparkle `appcast.xml` on Releases,
4. updates the cask in [`RainnWorks/homebrew-tap`](https://github.com/RainnWorks/homebrew-tap).

Pinch checks that appcast and offers the update itself (Sparkle), so Homebrew
installs are marked `auto_updates` and leave updating to Pinch.
