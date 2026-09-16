#!/usr/bin/env bash
# Regression tests for build.sh, run offline against a small fixture catalog in
# a scratch directory. Covers the version fallback and the page head contract.
#
#   bash tests/build.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp "$ROOT/build.sh" "$work/"

{
  printf '# slug\trepo\tsubpath\tname\tcategory\tplatform\tstatus\tsummary\t[version]\n'
  # A fetched version, with a stale authored one beside it: the fetched one wins.
  printf 'fetched\tacme/a\t\tFetched Tool\tBusiness\tWindows\tprivate\tA tool\t0.0.1\n'
  # Nothing fetched, an authored version: used, and marked as having no published release.
  printf 'authored\tacme/b\t\tAuthored Tool\tBusiness\tWindows\tdev\tA tool\t1.57.20\r\n'
  # Nothing fetched and nothing authored.
  printf 'bare\tacme/c\t\tBare Tool\tBusiness\tmacOS\tdev\tA tool\n'
} > "$work/CATALOG.txt"
printf '# slug\tversion\tlicense\nfetched\t2.0.0\tApache-2.0\nauthored\t—\tApache-2.0\nbare\t—\tNot stated\n' > "$work/catalog-cache.tsv"
printf '# slug\tversion\n' > "$work/downloads-cache.tsv"

( cd "$work" && bash build.sh ) > "$work/out.txt" 2>&1
rc=$?

pass=0; fail=0
check () {  # label | expected | actual
  if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi
}
has () { grep -qF -- "$2" "$work/$1" && echo yes || echo no; }

check "build succeeds"                        0 "$rc"
check "fetched version wins"                  yes "$(has fetched.html '<dd>2.0.0</dd>')"
check "authored version used and marked"      yes "$(has authored.html '<dd>1.57.20<small class="ver-note">no published release</small></dd>')"
check "authored version in the roster"        yes "$(has business-tools.html '>1.57.20</td>')"
check "no version shows a dash, unmarked"     yes "$(has bare.html '<dd>—</dd>')"
check "fetched version is not marked"         no  "$(has fetched.html 'ver-note')"
check "every page carries the CSP"            0   "$(grep -L 'http-equiv="Content-Security-Policy"' "$work"/*.html | wc -l | tr -d ' ')"
check "no page loads a third-party font"      0   "$(grep -l 'fonts.googleapis\|fonts.gstatic' "$work"/*.html | wc -l | tr -d ' ')"
check "no inline script"                      0   "$(grep -l '<script>' "$work"/*.html | wc -l | tr -d ' ')"
check "section labels are headings"           0   "$(grep -l '<p class="section-label">' "$work"/*.html | wc -l | tr -d ' ')"

[ "$fail" = 0 ] || cat "$work/out.txt"
printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
