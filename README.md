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
- A "Cancel sleep" item (shown while a sleep timer is active) cancels it.
- English and French strings.

## Installation

In LMS: *Settings → Plugins → Additional repositories*, add

```
https://raw.githubusercontent.com/werdeil/lyrion-sleep-end-of-track/main/repo.xml
```

then install **Sleep at end of track** from the plugin list and restart LMS.

## Checks

`scripts/check.sh` runs on every pull request and push to `main` (*CI* workflow):
Perl compilation (against stubs of the LMS modules in `ci/stubs`), XML validity,
version consistency between `install.xml` and `repo.xml`, EN/FR entries in
`strings.txt` for every `PLUGIN_*` string used, and `shellcheck`. Run it locally
before pushing (requires `perl` and `xmllint`, plus `shellcheck` if installed).

## Release

From GitHub: *Actions → Release → Run workflow*, enter the version (`X.Y.Z`).
The workflow runs the same script as below.

Or locally:

```sh
scripts/release.sh 1.0.1            # bump install.xml, build dist/ zip, update repo.xml
scripts/release.sh --publish 1.0.1  # commit on release/v1.0.1, tag, create the GitHub release, open a PR to main
```

Requires `zip`, `shasum`, `xmllint`, `perl` and an authenticated `gh`.

`main` is protected, so the release commit (version bump and `repo.xml`) goes
through a pull request: LMS users get the new version once it is merged. The
workflow needs *Settings → Actions → General → Allow GitHub Actions to create
and approve pull requests* to open it.

## Sponsor

If this plugin is useful to you, you can support its development through [GitHub Sponsors](https://github.com/sponsors/werdeil). It is entirely optional: the plugin stays free and MIT-licensed either way.

## License

[MIT](LICENSE) © 2026 Vincent Verdeil.

The icon is the Material Design "hotel" glyph by Google, licensed under the
Apache License 2.0.
