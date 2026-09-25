# Development

[Documentation index](index.md)

Run these commands from the repository root:

```sh
make build   # Debug build
make test    # Swift tests
make lint    # Check Swift formatting
make format  # Format Swift sources
```

The executable is `.build/debug/stags`. `swift run stags daemon` builds and starts it in the foreground.

## Source layout

`Sources/Stags/Stags.swift` parses commands and uses StarkIPC to talk to the daemon. `Sources/StagsCore/TagState.swift` owns tag membership and view rules. `TagDaemon.swift` polls the active Space, handles commands, moves windows, and publishes snapshots. `WindowAccess.swift` reads Accessibility windows. `ParkingGeometry.swift` picks a display edge, and `ParkingJournal.swift` saves original frames for recovery.

`StarkSkyLight` supplies Space queries. The executable uses StarkIPC for its local socket and messages. The daemon checks the active Space before changing a window so a stale ID from another Space cannot be used.

## Tests and desktop checks

The tests cover tag membership, multi-tag views, active Space checks, parking geometry, and the recovery journal. They do not prove that a particular application will accept an Accessibility move.

For a desktop check, run the daemon with Accessibility permission, switch between macOS Spaces, try `view` and `window` commands on ordinary windows, and inspect `query` after each move. Check `restore`, `stop`, Ctrl+C, and restart with a parked window. Include more than one display if you rely on that setup. Native fullscreen, minimized windows, and `swm` automatic tiling need separate attention because they do not follow the ordinary parking path.
