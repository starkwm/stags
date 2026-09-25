# Command line

[Documentation index](index.md)

Run `stags help` or `stags --help` to print usage. Running `stags` without a command also prints usage.

| Command | Action |
| --- | --- |
| `daemon` | Start the foreground daemon. |
| `query` | Print a JSON snapshot of the active macOS Space. |
| `subscribe` | Print an initial snapshot, then one JSON object per line when the snapshot changes. |
| `view TAG...` | Replace the visible tags. The first tag becomes primary. |
| `view-toggle TAG` | Add or remove one visible tag. |
| `window set TAG...` | Replace a window's tags. |
| `window add TAG` | Add a tag to a window. |
| `window remove TAG` | Remove a tag from a window. |
| `restore` | Show all known tags and restore parked windows in the active Space. |
| `stop` | Restore parked windows, then stop the daemon if restoration succeeds. |

Client commands need a running daemon. Each command accepts `--socket PATH` to use a different control socket. The default is `~/.config/stags/control.sock`. Pass the same path to `daemon` and its clients:

```sh
stags daemon --socket /tmp/stags-test.sock
stags query --socket /tmp/stags-test.sock
stags stop --socket /tmp/stags-test.sock
```

Window commands target the focused window by default. Use `--window ID` with an ID from `query` when focus is ambiguous:

```sh
stags window set work chat --window 12345
```

`--window` is valid only for `window set`, `window add`, and `window remove`. IDs must belong to managed windows in the active macOS Space. Invalid commands and daemon errors exit with a nonzero status and print an error to stderr.

## Query output

`query` returns `activeTags`, `primaryTag`, `tags`, and `windows`. `activeTags` is the visible set; `tags` contains every tag known to the running daemon. Each window has an `id`, `pid`, application name in `app`, `bundleId`, and its assigned `tags`.

Window state includes `desiredVisible`, `minimized`, `nativeFullscreen`, `parked`, and `parkingRecorded`. `desiredVisible` follows tag membership. `parked` checks the current window position; `parkingRecorded` says the recovery journal still holds its original frame. They can differ if an application moves a window or refuses a restore. When available, `frame` has `x`, `y`, `width`, and `height`. A window with a move or recovery problem also has an `error` string.

`subscribe` emits the same snapshot shape. Its first line is the current state; later lines appear when that state changes. Use line-oriented JSON parsing for the stream.
