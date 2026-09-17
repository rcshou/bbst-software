#!/usr/bin/env bash
# Regression tests for fetch-catalog.sh, run offline. gh is replaced on PATH by a
# stub that replays fixed repository data, so the version rules are exercised
# without a network.
#
#   bash tests/fetch-catalog.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/repos"

# Each fake repository is a folder under $FAKE_REPOS holding `license` (the SPDX
# id), an optional `release` (latest release tag), an optional `tags` (one tag
# per line) and any repository content, served base64-encoded.
cat > "$work/bin/gh" <<'SH'
#!/usr/bin/env bash
[ "$*" = "auth status" ] && exit 0
for a in "$@"; do case "$a" in repos/*) target="${a#repos/}" ;; esac; done
jq=""; prev=""
for a in "$@"; do [ "$prev" = "--jq" ] && jq="$a"; prev="$a"; done
case "$target" in
  */releases/latest) f="$FAKE_REPOS/${target%/releases/latest}/release"; [ -f "$f" ] || exit 1; cat "$f" ;;
  */tags*)           f="$FAKE_REPOS/${target%%/tags*}/tags"; [ -f "$f" ] && cat "$f"; exit 0 ;;
  */contents/*)      f="$FAKE_REPOS/${target%%/contents/*}/${target#*/contents/}"
                     # `base64 -w0` is GNU-only; BSD base64 wraps by default and
                     # has no -w, so fold the newlines out instead.
                     [ -f "$f" ] || exit 1; base64 < "$f" | tr -d '\n' ;;
  *)                 d="$FAKE_REPOS/$target"; [ -d "$d" ] || exit 1
                     case "$jq" in .name) basename "$d" ;; *) cat "$d/license" ;; esac ;;
esac
SH
chmod +x "$work/bin/gh"

repo () {  # owner/name | license
  mkdir -p "$work/repos/$1"; printf '%s\n' "$2" > "$work/repos/$1/license"
}

pass=0; fail=0
check () {  # label | expected | actual
  if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi
}
version_of () { awk -F'\t' -v s="$1" '!/^#/ && $1==s {print $2}' "$work/cache.tsv"; }

# A release tag with a product prefix, as Project2Excel publishes.
repo acme/prefixed Apache-2.0; printf 'prefixed-v1.0.12\n' > "$work/repos/acme/prefixed/release"
# A bare "v" tag.
repo acme/plain Apache-2.0;    printf 'v2.3.4\n' > "$work/repos/acme/plain/release"
# No release: the highest bare version tag wins, and a prefixed tag is ignored.
repo acme/tagged Apache-2.0;   printf 'v1.9.6\nv1.10.0\nother-v9.9.9\n' > "$work/repos/acme/tagged/tags"
# A tag that is not a version is shown as it is, not mangled.
repo acme/named Apache-2.0;    printf 'nightly\n' > "$work/repos/acme/named/release"
# A Lightroom plugin: the version comes from Info.lua, whatever the tags say.
repo acme/plugin Apache-2.0;   printf 'v7.0.0\n' > "$work/repos/acme/plugin/release"
mkdir -p "$work/repos/acme/plugin/Tool.lrplugin"
printf 'return {\n  VERSION = { major = 2, minor = 1, revision = 0, build = 1, },\n}\n' > "$work/repos/acme/plugin/Tool.lrplugin/Info.lua"

{
  printf '# slug\trepo\tsubpath\tname\tcategory\tplatform\tstatus\tsummary\n'
  printf 'prefixed\tacme/prefixed\t\tP\tBusiness\tWindows\tprivate\ts\n'
  printf 'plain\tacme/plain\t\tP\tBusiness\tWindows\tprivate\ts\n'
  printf 'tagged\tacme/tagged\t\tT\tBusiness\tWindows\tprivate\ts\r\n'
  printf 'named\tacme/named\t\tN\tBusiness\tWindows\tprivate\ts\n'
  printf 'plugin\tacme/plugin\tTool.lrplugin\tL\tLightroom\tPlugin\tprivate\ts\n'
  # The optional ninth column: an authored version beside a real release is
  # reported, and one with nothing to fetch is left for build.sh to use.
  printf 'stale\tacme/plain\t\tS\tBusiness\tWindows\tprivate\ts\t0.0.1\n'
  printf 'unreleased\tacme/norelease\t\tU\tBusiness\tWindows\tdev\ts\t3.0.0\n'
} > "$work/catalog.txt"
repo acme/norelease Apache-2.0

( cd "$work" && PATH="$work/bin:$PATH" FAKE_REPOS="$work/repos" \
    CATALOG_FILE="$work/catalog.txt" CACHE_FILE="$work/cache.tsv" \
    bash "$ROOT/fetch-catalog.sh" ) > "$work/out.txt" 2>&1
rc=$?

check "fetch succeeds"                    0 "$rc"
check "product-prefixed release tag"      "1.0.12" "$(version_of prefixed)"
check "bare v release tag"                "2.3.4" "$(version_of plain)"
check "highest bare tag without release"  "1.10.0" "$(version_of tagged)"
check "non-version tag left as it is"     "nightly" "$(version_of named)"
check "plugin version from Info.lua"      "2.1.0" "$(version_of plugin)"
check "release still wins over authored"  "2.3.4" "$(version_of stale)"
check "authored beside release is warned" "0" "$(grep -q 'remove the authored version (0.0.1) for stale' "$work/out.txt"; echo $?)"
check "nothing fetched stays unversioned" "—" "$(version_of unreleased)"
check "no warning without a release"      "1" "$(grep -q 'for unreleased' "$work/out.txt"; echo $?)"

[ "$fail" = 0 ] || cat "$work/out.txt"
printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
