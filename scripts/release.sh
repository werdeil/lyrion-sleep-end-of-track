#!/usr/bin/env bash
# Release du plugin SleepEndOfTrack pour le dépôt Lyrion (repo.xml).
#
#   scripts/release.sh <version>            prépare : version dans install.xml,
#                                           zip dans dist/, SHA1 et URL dans repo.xml
#   scripts/release.sh --publish <version>  publie : commit, tag, push, release GitHub
#
# Variable optionnelle : GH_REPO (défaut werdeil/lyrion-sleep-shortcut)

set -euo pipefail

PLUGIN=SleepEndOfTrack
GH_REPO=${GH_REPO:-werdeil/lyrion-sleep-shortcut}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

die()  { echo "erreur : $*" >&2; exit 1; }
usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

publish=0
if [[ ${1:-} == --publish ]]; then publish=1; shift; fi
VERSION=${1:-}
[[ -n $VERSION ]] || usage
[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version attendue au format X.Y.Z (reçu : $VERSION)"

TAG=v$VERSION
ZIP=dist/$PLUGIN-$VERSION.zip
URL=https://github.com/$GH_REPO/releases/download/$TAG/$PLUGIN-$VERSION.zip

prepare() {
	[[ -z $(git status --porcelain) ]] || die "l'arbre de travail n'est pas propre"
	git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "le tag $TAG existe déjà"

	# 1. Version dans install.xml
	perl -0pi -e "s#<version>[^<]*</version>#<version>$VERSION</version>#" "$PLUGIN/install.xml"

	# 2. Zip (le dossier du plugin à la racine de l'archive)
	mkdir -p dist
	rm -f "$ZIP"
	zip -q -X -r "$ZIP" "$PLUGIN" -x '*.DS_Store'

	# 3. SHA1, version et URL dans repo.xml
	local sha
	sha=$(shasum -a 1 "$ZIP" | cut -d' ' -f1)
	perl -0pi -e "
		s#(<plugin name=\"$PLUGIN\" version=\")[^\"]*#\${1}$VERSION#;
		s#<url>[^<]*</url>#<url>$URL</url>#;
		s#<sha>[^<]*</sha>#<sha>$sha</sha>#;
	" repo.xml

	xmllint --noout "$PLUGIN/install.xml" repo.xml

	echo "Prêt : $ZIP (sha1 $sha)"
	git --no-pager diff --stat
	echo
	echo "Vérifiez, puis publiez avec : scripts/release.sh --publish $VERSION"
}

publish() {
	command -v gh >/dev/null || die "gh (GitHub CLI) est requis"
	[[ -f $ZIP ]] || die "$ZIP introuvable : lancez d'abord scripts/release.sh $VERSION"
	git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "le tag $TAG existe déjà"
	git ls-remote --exit-code origin >/dev/null 2>&1 || die "remote 'origin' inaccessible"
	gh repo view "$GH_REPO" >/dev/null 2>&1 || die "dépôt GitHub $GH_REPO introuvable"

	local sha
	sha=$(shasum -a 1 "$ZIP" | cut -d' ' -f1)
	grep -q "<sha>$sha</sha>" repo.xml           || die "le SHA1 de $ZIP ne correspond pas à repo.xml"
	grep -q "version=\"$VERSION\"" repo.xml      || die "repo.xml n'est pas en version $VERSION"
	grep -q "<version>$VERSION</version>" "$PLUGIN/install.xml" || die "install.xml n'est pas en version $VERSION"

	git add "$PLUGIN/install.xml" repo.xml
	git commit -m "chore(release): $TAG"
	git tag -a "$TAG" -m "$TAG"

	# Le tag et l'asset d'abord : repo.xml sur main ne pointe jamais vers un zip absent.
	git push origin "$TAG"
	gh release create "$TAG" "$ZIP" --repo "$GH_REPO" --title "$PLUGIN $VERSION" --generate-notes
	git push origin HEAD:main

	echo "Publié : $URL"
	echo "Dépôt à ajouter dans Lyrion : https://raw.githubusercontent.com/$GH_REPO/main/repo.xml"
}

if (( publish )); then publish; else prepare; fi
