# Tags and views

[Documentation index](index.md)

A window has one or more tags. The view is the set of tags currently visible. `stags` shows a window when its tags overlap the view and parks it at a display edge otherwise. It does not switch macOS Spaces.

## Assign tags

Existing windows receive tag `1` when the daemon starts. New windows receive the current primary tag. Use the focused window, or pass an ID from `stags query`:

```sh
stags window set work chat
stags window add urgent --window 12345
stags window remove chat --window 12345
```

`set` replaces all tags on a window. `add` and `remove` change one tag. A window must keep at least one tag, and using a new name creates that tag. Tags are names, not numbered macOS Spaces.

## Choose a view

```sh
stags view work chat
stags view-toggle urgent
```

`view` replaces the visible set. Its first argument becomes the primary tag, which new windows receive. `view-toggle` adds or removes one tag without replacing the rest. Adding a tag keeps the current primary tag. Removing the primary tag picks the alphabetically first remaining tag. At least one tag must remain visible.

`stags restore` makes every known tag visible and moves parked windows back to their recorded positions. See [window recovery](recovery.md) for what happens when a window is on another macOS Space.

## macOS Spaces

The daemon discovers and changes windows in the active macOS Space. `query` lists windows from that Space. A window ID from another Space cannot be tagged until you switch to its Space. Tag assignments survive ordinary Space switches while the daemon runs, but they are not saved across daemon restarts.

The daemon checks window and Space state once a second. Native fullscreen and minimized windows are not parked. A fullscreen window outside the view can produce an error because `stags` cannot hide it by moving it.
