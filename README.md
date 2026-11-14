# Sleep at end of track — Lyrion Music Server plugin

An app for [Lyrion Music Server](https://lyrion.org) that, when opened, puts the
current player to sleep at the end of the current track (the same as
SqueezePlay's "Sleep at end of song", via the native `jiveendoftracksleep`
command).

Its purpose is a one-tap shortcut: [Material Skin](https://github.com/CDrummond/lms-material)
can't pin its own menus to the home screen, only apps. Pin
"Sleep at end of track" from *Apps* and a single tap schedules sleep.

- Acts on the player selected in the client at the time of the tap.
- Shows `Sleep scheduled at the end of "<title>"`, or `Nothing playing` when
  there is no playing track with a known duration (radio streams, paused player).
- A new tap reschedules on the current track; repeated calls within 5 seconds
  (menu reloads) are ignored.
- English and French strings.

## Installation

In LMS: *Settings → Plugins → Additional repositories*, add

```
https://raw.githubusercontent.com/werdeil/lyrion-sleep-shortcut/main/repo.xml
```

then install **Sleep at end of track** from the plugin list and restart LMS.

## Release

```sh
scripts/release.sh 1.0.1            # bump install.xml, build dist/ zip, update repo.xml
scripts/release.sh --publish 1.0.1  # commit, tag, push, create the GitHub release
```

Requires `zip`, `shasum`, `xmllint`, `perl` and an authenticated `gh`.

## License

[MIT](LICENSE) © 2026 Vincent Verdeil.

The icon is the Material Design "hotel" glyph by Google, licensed under the
Apache License 2.0.
