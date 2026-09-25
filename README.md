# stags

`stags` is a Swift command-line daemon that gives windows dwm-style tags within the active macOS Space. A window can have several tags. The visible view can include several tags, and a window appears when at least one of its tags is in the view. `stags` does not switch native Spaces.

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

The daemon listens at `~/.config/stags/control.sock` by default. Every command accepts `--socket PATH`. `query` returns JSON for windows in the active macOS Space, and `subscribe` streams one JSON object per line when state changes. Window IDs from another Space cannot be tagged until that Space is active.

## Recovery and limitations

Before parking a window, the daemon writes its original frame to `${XDG_STATE_HOME:-~/.local/state}/stags/parking.json`. `stags stop`, Ctrl+C, and termination signals restore parked windows before exiting. They report a failure and keep the daemon running if a parked window belongs to another native Space. Switch to that Space and run `stags restore`, then stop the daemon. On restart, the daemon attempts to restore frames left by a previous run when their Space becomes active. `stags restore` shows all known tags and restores parked windows in the active Space while the daemon continues running. Failed moves and restores remain in the journal for a later retry.

Tag assignments and the selected view currently live only for the daemon session. Existing windows receive tag `1` when the daemon starts. There are no assignment rules or saved tags yet. Native fullscreen and minimized windows are not parked. The daemon polls Accessibility and WindowServer every second for windows in the active Space; some apps may not expose a movable window or accept an off-screen position. Multi-display placement is best-effort.

`swm` automatic tiling can reflow a parked window back onto the screen. Use `swm`'s floating layout with `stags` until the two daemons have an explicit layout coordination protocol.

Window IDs come from the macOS Accessibility private `_AXUIElementGetWindow` symbol, as they do in `swm`. This lets the CLI use the same numeric IDs as `swm query windows`, but it requires validation on each supported macOS release.

## Development

```sh
swift test
swift format lint --strict -r Sources Tests Package.swift
```

The tests cover tag membership, multi-tag views, active Space membership, display-edge selection, and the recovery journal. Live parking and Accessibility permission still need a manual test on a Mac with real windows.
