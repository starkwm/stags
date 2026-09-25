# Getting started

[Documentation index](index.md)

## Requirements

- macOS 26 or later
- Swift 6.2 or later to build from source
- Accessibility permission for the `stags` executable
- A logged-in desktop session with ordinary application windows

`stags` uses Accessibility to move windows and private macOS APIs to match window IDs with the active Space. Those APIs and some applications' window behavior can change across macOS releases.

## Build and start

From the repository root:

```sh
swift build
swift run stags daemon
```

The daemon runs in the foreground. Grant access to the executable in System Settings > Privacy & Security > Accessibility if macOS prompts for it, then start the daemon again. The default control socket is `~/.config/stags/control.sock`.

Use a second terminal for commands. A source build has no login service or installed command on your `PATH`:

```sh
swift run stags query
swift run stags window set work chat
swift run stags view work
swift run stags view work chat
swift run stags stop
```

The daemon starts with tag `1`. `window set work chat` assigns both tags to the focused window. `view work` then shows that window and parks windows still on `1`. `view work chat` shows windows on either tag. The examples in the other guides use `stags` as the command name. For a source build, use `swift run stags` or `.build/debug/stags` instead. Run `swift run stags help` for the full syntax or read the [command line reference](cli.md).

Before trying this with windows you care about, read [window recovery](recovery.md). `stags` records a window's original position before parking it, but some applications reject moves or keep part of the window visible.

## Use it with swm

If `swm` manages the same windows, choose its floating layout. Automatic tiling can move a parked window back on screen. There is no layout coordination between the two daemons yet.
