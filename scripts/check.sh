#!/usr/bin/env bash
# Static checks run by CI on every PR and push to main. Runs locally too.
# Requires perl and xmllint; shellcheck is used when available.

set -euo pipefail

PLUGIN=SleepEndOfTrack
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

failed=0
fail() { echo "FAIL: $*" >&2; failed=1; }
step() { echo "==> $*"; }

step "Perl syntax"
for pm in "$PLUGIN"/*.pm; do
	perl -Ici/stubs -Mstrict -we 'require "./ci/stubs/main_constants.pl"; require "./$ARGV[0]"' "$pm" \
		|| fail "$pm does not compile"
done

step "XML validity"
xmllint --noout "$PLUGIN/install.xml" repo.xml || fail "invalid XML"

step "Version consistency"
v_install=$(xmllint --xpath 'string(/extension/version)' "$PLUGIN/install.xml")
v_repo=$(xmllint --xpath "string(//plugin[@name='$PLUGIN']/@version)" repo.xml)
url=$(xmllint --xpath "string(//plugin[@name='$PLUGIN']/url)" repo.xml)
[[ $v_install == "$v_repo" ]] || fail "install.xml is $v_install but repo.xml is $v_repo"
[[ $url == */v$v_repo/$PLUGIN-$v_repo.zip ]] || fail "repo.xml url does not match version $v_repo: $url"
echo "version $v_install"

step "Strings"
# Every PLUGIN_* token used in code or install.xml needs EN and FR entries.
perl -e '
	my ($strings, @sources) = @ARGV;
	my (%lang, $key);
	open my $fh, "<:encoding(UTF-8)", $strings or die "$strings: $!";
	while (<$fh>) {
		if    (/^(\S+)\s*$/)          { $key = $1; $lang{$key} //= {} }
		elsif (/^\t(\w+)\t/ && $key)  { $lang{$key}{$1} = 1 }
	}
	my %used;
	for my $f (@sources) {
		open my $s, "<", $f or die "$f: $!";
		local $/; my $c = <$s>;
		$used{$1} = 1 while $c =~ /\b(PLUGIN_[A-Z0-9_]+)\b/g;
	}
	my $bad = 0;
	for my $k (sort keys %used) {
		for my $l (qw(EN FR)) {
			next if $lang{$k}{$l};
			print STDERR "missing $l string for $k\n"; $bad = 1;
		}
	}
	exit $bad;
' "$PLUGIN/strings.txt" "$PLUGIN"/*.pm "$PLUGIN/install.xml" || fail "strings.txt is incomplete"

step "Shell scripts"
if command -v shellcheck >/dev/null; then
	shellcheck scripts/*.sh || fail "shellcheck reported issues"
else
	echo "shellcheck not installed, skipped"
fi

if (( failed )); then echo "Checks failed" >&2; exit 1; fi
echo "All checks passed"
