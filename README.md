# stags

`stags` is a Swift command-line daemon that gives windows dwm-style tags on one macOS Space. A window can have several tags. The visible view can include several tags, and a window appears when at least one of its tags is in the view.

This is an early implementation. It requires macOS 26 or later and Accessibility permission for the `stags` executable. It uses Accessibility to move inactive windows to a screen edge. macOS may leave a one-pixel sliver visible. Window movement is app-dependent, and `query` reports failures.

## Build and run

```sh
swift build
swift run stags daemon
```

Run client commands in another terminal:

```sh
swift run stags query
swift run stags view work
swift run stags window set work chat
swift run stags view work chat
swift run stags view-toggle chat
swift run stags window add chat --window 12345
swift run stags window remove work --window 12345
swift run stags subscribe
swift run stags stop
```

`window` commands use the focused window unless `--window ID` names a window from `query`. `view` replaces the visible tag set and makes its first tag the primary tag. `view-toggle` adds or removes one tag. New windows receive the primary tag. Neither a window nor the visible view can have zero tags. Unknown tag names are created when used.

The daemon listens at `~/.config/stags/control.sock` by default. Every command accepts `--socket PATH`. `query` returns JSON, and `subscribe` streams one JSON object per line when state changes.

## Recovery and limitations

Before parking a window, the daemon writes its original frame to `${XDG_STATE_HOME:-~/.local/state}/stags/parking.json`. `stags stop`, Ctrl+C, and termination signals restore parked windows before exiting. On restart, the daemon attempts to restore frames left by a previous run before applying the new view. `stags restore` shows all known tags and restores all parked windows while the daemon continues running. Failed moves and restores remain in the journal for a later retry.

Tag assignments and the selected view currently live only for the daemon session. Existing windows receive tag `1` when the daemon starts. There are no assignment rules or saved tags yet. Native fullscreen and minimized windows are not parked. The daemon polls Accessibility every second for new windows; some apps may not expose a movable window or accept an off-screen position. Multi-display placement is best-effort.

`swm` automatic tiling can reflow a parked window back onto the screen. Use `swm`'s floating layout with `stags` until the two daemons have an explicit layout coordination protocol.

Window IDs come from the macOS Accessibility private `_AXUIElementGetWindow` symbol, as they do in `swm`. This lets the CLI use the same numeric IDs as `swm query windows`, but it requires validation on each supported macOS release.

## Development

```sh
swift test
swift format lint --strict -r Sources Tests Package.swift
```

The tests cover tag membership, multi-tag views, display-edge selection, and the recovery journal. Live parking and Accessibility permission still need a manual test on a Mac with real windows.
