# stags

Window tags for macOS.

`stags` assigns one or more tags to each window in the active macOS Space. Choose which tags to show, and the daemon moves other windows to a display edge. It does not switch native Spaces.

## Quick start

Requires macOS 26 or later, Swift 6.2 or later to build, and Accessibility permission for `stags`.

```sh
make build
.build/debug/stags daemon
```

In another terminal, tag the focused window before changing the view:

```sh
.build/debug/stags window set work
.build/debug/stags view work
.build/debug/stags query
```

Run `.build/debug/stags stop` to restore parked windows and stop the daemon. If a parked window is on another macOS Space, switch to that Space and run `.build/debug/stags restore` before stopping. See [getting started](docs/getting-started.md) for setup and [window recovery](docs/recovery.md) for move failures and interrupted sessions.

## Documentation

The [documentation index](docs/index.md) links to all guides.

- [Tags and views](docs/tags-and-views.md)
- [Command line](docs/cli.md)
- [Window recovery](docs/recovery.md)
- [Development](docs/development.md)

`stags` is an early implementation. Some applications refuse off-screen moves, and `swm` automatic tiling can move parked windows back on screen. Use `swm`'s floating layout while the two daemons lack layout coordination.
