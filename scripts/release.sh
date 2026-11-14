#!/usr/bin/env bash
# Usage:
#   scripts/release.sh <version>            bump install.xml, build dist/ zip, update repo.xml
#   scripts/release.sh --publish <version>  commit, tag, push and create the GitHub release
#
# GH_REPO overrides the target repository (default werdeil/lyrion-sleep-end-of-track).

set -euo pipefail

PLUGIN=SleepEndOfTrack
GH_REPO=${GH_REPO:-werdeil/lyrion-sleep-end-of-track}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

die()   { echo "error: $*" >&2; exit 1; }
usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

publish=0
if [[ ${1:-} == --publish ]]; then publish=1; shift; fi
VERSION=${1:-}
[[ -n $VERSION ]] || usage
[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must be X.Y.Z (got: $VERSION)"

TAG=v$VERSION
ZIP=dist/$PLUGIN-$VERSION.zip
URL=https://github.com/$GH_REPO/releases/download/$TAG/$PLUGIN-$VERSION.zip

prepare() {
	[[ -z $(git status --porcelain) ]] || die "working tree is not clean"
	git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists"

	perl -0pi -e "s#<version>[^<]*</version>#<version>$VERSION</version>#" "$PLUGIN/install.xml"

	mkdir -p dist
	rm -f "$ZIP"
	zip -q -X -r "$ZIP" "$PLUGIN" -x '*.DS_Store'

	local sha
	sha=$(shasum -a 1 "$ZIP" | cut -d' ' -f1)
	perl -0pi -e "
		s#(<plugin name=\"$PLUGIN\" version=\")[^\"]*#\${1}$VERSION#;
		s#<url>[^<]*</url>#<url>$URL</url>#;
		s#<sha>[^<]*</sha>#<sha>$sha</sha>#;
	" repo.xml

	xmllint --noout "$PLUGIN/install.xml" repo.xml

	echo "Ready: $ZIP (sha1 $sha)"
	git --no-pager diff --stat
	echo
	echo "Review, then publish with: scripts/release.sh --publish $VERSION"
}

publish() {
	command -v gh >/dev/null || die "gh (GitHub CLI) is required"
	[[ -f $ZIP ]] || die "$ZIP not found, run scripts/release.sh $VERSION first"
	git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists"
	git ls-remote --exit-code origin >/dev/null 2>&1 || die "remote 'origin' is not reachable"
	gh repo view "$GH_REPO" >/dev/null 2>&1 || die "GitHub repository $GH_REPO not found"

	local sha
	sha=$(shasum -a 1 "$ZIP" | cut -d' ' -f1)
	grep -q "<sha>$sha</sha>" repo.xml           || die "SHA1 of $ZIP does not match repo.xml"
	grep -q "version=\"$VERSION\"" repo.xml      || die "repo.xml is not at version $VERSION"
	grep -q "<version>$VERSION</version>" "$PLUGIN/install.xml" || die "install.xml is not at version $VERSION"

	git add "$PLUGIN/install.xml" repo.xml
	git commit -m "chore(release): $TAG"
	git tag -a "$TAG" -m "$TAG"

	# Tag and asset first, so repo.xml on main never points to a missing zip.
	git push origin "$TAG"
	gh release create "$TAG" "$ZIP" --repo "$GH_REPO" --title "$PLUGIN $VERSION" --generate-notes
	git push origin HEAD:main

	echo "Published: $URL"
	echo "LMS repository URL: https://raw.githubusercontent.com/$GH_REPO/main/repo.xml"
}

if (( publish )); then publish; else prepare; fi
