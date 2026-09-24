# Pinch

![Pinch maps AirPods stem presses to keyboard shortcuts](assets/hero.png)

Pinch turns AirPods stem presses into keyboard shortcuts on a Mac.

| Press | Default |
|---|---|
| Single | Play or pause Spotify or Music |
| Double | ⌥ Space |
| Triple | Previous track in Spotify or Music |

Each press can be set to pass through to music, send any shortcut, or do nothing.
Open settings from the Dock icon, the menu bar icon, or ⌘,.

## How it works

macOS sends AirPods presses to whichever app is "now playing", not to the
keyboard, so key remappers such as Karabiner never see them. Pinch plays a
silent loop to hold that slot and receives the presses itself. A press set to
"Music" is passed on to Spotify or Music with AppleScript, and Pinch takes the
now playing slot back one second later.

The cost: the silent loop keeps the AirPods audio link open, which uses a
little AirPods battery.

## Build

```sh
./build.sh
open Pinch.app
```

On first launch, allow Pinch under Accessibility, then quit and reopen it.
The first press set to "Music" asks to control Spotify or Music.

Pinch is ad-hoc signed, so every rebuild counts as a new app to macOS and
needs Accessibility allowed again.
