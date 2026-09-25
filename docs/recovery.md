# Window recovery

[Documentation index](index.md)

`stags` hides a window by moving it to a display edge. Before the move, it writes the original frame and application identity to `${XDG_STATE_HOME:-~/.local/state}/stags/parking.json`. This file is a recovery journal. It does not save tag assignments or the selected view.

Some apps reject an Accessibility move or clamp the position to the screen. `stags query` reports an `error` for a window when a park or restore fails. A one-pixel strip may remain visible even after a successful move.

## Restore while the daemon runs

```sh
stags restore
```

This shows every known tag and restores parked windows in the active macOS Space. The daemon keeps running. If a parked window belongs to another Space, switch to that Space and run `stags restore` again. You can then select a narrower view.

## Stop the daemon

```sh
stags stop
```

Ctrl+C and termination signals also attempt to restore parked windows. If any recorded window cannot be restored, `stags stop` reports the failure and leaves the daemon running. A signal handler reports the failure to stderr and does the same. Move to the window's macOS Space, run `stags restore`, and retry `stags stop`.

If the process exits unexpectedly, start it again. It reads the journal and tries to restore a recorded window when that window's Space becomes active. Failed entries stay in the journal for another attempt. Do not discard `parking.json` while it contains windows you still need to restore.

`stags` checks the window ID and application identity before using a recovery record. It drops records for apps that have quit. The journal records window positions, not application state.
