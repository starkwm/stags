# Development

[Documentation index](index.md)

Run these commands from the repository root:

```sh
make build    # Debug build
make release  # Optimized build
make test     # Swift tests
make lint     # Check Swift formatting
make format   # Format Swift sources
make clean    # Remove build products
```

To run one suite, use `make test TEST_ARGS='--filter TagStateTests'`.

The executable is `.build/debug/stags`. `swift run stags daemon` builds and starts it in the foreground.

## Update the version

Edit the version string in `Sources/Stags/Version.swift`, then rebuild and check it:

```sh
make build
.build/debug/stags --version
```

Commit `Sources/Stags/Version.swift` with the bump. The version command exits without starting a daemon or opening its control socket.

## Source layout

`CLICommand.swift` parses command-line arguments into local actions or StarkIPC requests. `Stags.swift` runs those actions and prints responses. `TagDaemon.swift` owns the control socket, subscriptions, polling timer, and shutdown. `TagCommandDispatcher.swift` handles requests, polls the active Space, and reconciles windows with the selected view. `TagState.swift` owns tag membership and view rules. `WindowAccess.swift` discovers, moves, and focuses Accessibility windows. `ParkingGeometry.swift` picks a display edge, and `ParkingJournal.swift` saves original frames for recovery.

`StarkSkyLight` supplies Space queries. The executable uses StarkIPC for its local socket and messages. The daemon checks the active Space before changing a window so a stale ID from another Space cannot be used.

## Tests and desktop checks

The tests cover CLI parsing, socket subscriptions, tag membership, multi-tag views, Space changes during polling, parking geometry, and retrying a failed stop with its recovery journal. They do not prove that a particular application will accept an Accessibility move.

For a desktop check, run the daemon with Accessibility permission, switch between macOS Spaces, try `view` and `window` commands on ordinary windows, and inspect `query` after each move. Check `restore`, `stop`, Ctrl+C, and restart with a parked window. Include more than one display if you rely on that setup. Native fullscreen, minimized windows, and `swm` automatic tiling need separate attention because they do not follow the ordinary parking path.
