#!/usr/bin/env bash
# Regression tests for fetch-downloads.sh, run offline. gh and curl are replaced
# on PATH by stubs that replay fixed release data, so every rule the script
# applies is exercised without a network or a real downloads repository.
#
#   bash tests/fetch-downloads.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin" "$work/docsrc"

# Release notes come from $FAKE_NOTES_DIR/<tag>.md; an absent file means an empty
# description. "api markdown" stands in for GitHub's renderer in document mode:
# a "# " line becomes an <h1> inside the permalink wrapper GitHub adds, anything
# else passes through, which is enough to test what the script does with it.
cat > "$work/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  "auth status")       exit 0 ;;
  "api markdown "*)    for a in "$@"; do case "$a" in text=@*) f="${a#text=@}" ;; esac; done
                       sed -E 's#^\# (.*)$#<div class="markdown-heading"><h1 class="heading-element">\1</h1><a id="user-content-x" class="anchor" aria-label="Permalink: \1" href="\#x"><span aria-hidden="true" class="octicon octicon-link"></span></a></div>#' "$f" ;;
  *"/releases/tags/"*) for a in "$@"; do case "$a" in */releases/tags/*) tag="${a##*/releases/tags/}" ;; esac; done
                       cat "$FAKE_NOTES_DIR/$tag.md" 2>/dev/null; exit 0 ;;
  *"/releases?"*)      cat "$FAKE_RELEASES" ;;
  "api repos/"*)       printf '%s\n' "$FAKE_PRIVATE" ;;
  *)                   exit 1 ;;
esac
SH
# A URL containing "blocked" answers 404 and one containing "unreachable" cannot
# be reached, the way curl reports a file behind a login and a host it could not
# reach. With -o, the file is served from $FAKE_DOCS_DIR by its last path part.
cat > "$work/bin/curl" <<'SH'
#!/usr/bin/env bash
url="${!#}"; out=""; prev=""
for a in "$@"; do [ "$prev" = "-o" ] && out="$a"; prev="$a"; done
case "$url" in
  *blocked*)     [ "$out" = /dev/null ] && printf '404'; echo "curl: (22) The requested URL returned error: 404" >&2; exit 22 ;;
  *unreachable*) echo "curl: (6) Could not resolve host" >&2; [ "$out" = /dev/null ] && printf '000'; exit 6 ;;
esac
if [ -n "$out" ] && [ "$out" != /dev/null ]; then cp "$FAKE_DOCS_DIR/${url##*/}" "$out" || exit 22; exit 0; fi
printf '200'
SH
chmod +x "$work/bin/gh" "$work/bin/curl"

REPO="acme/downloads"
DL="https://github.com/$REPO/releases/download"
SHA="6b5916dffcfa6f593b1db7890f2ddc485318e99fa263acf73aa28ebb877b53cd"

# The authored catalog (CATALOG.txt layout, with an empty subpath column, and a
# CRLF line as a Windows checkout would produce) and the fetched cache.
printf '# slug\trepo\tsubpath\tname\tcategory\tplatform\tstatus\tsummary\n' > "$work/catalog.txt"
printf 'alpha\tacme/alpha\t\tAlpha\tBusiness\tWindows\treleased\tA tool\n' >> "$work/catalog.txt"
printf 'alpha-pro\tacme/alpha-pro\t\tAlpha Pro\tBusiness\tWindows\tprivate\tA tool\r\n' >> "$work/catalog.txt"
printf 'beta-tool\tacme/beta\tBeta.lrplugin\tBeta Tool\tLightroom\tPlugin\tbeta\tA tool\n' >> "$work/catalog.txt"
printf '# generated\n# slug\tversion\tlicense\n' > "$work/catalog-cache.tsv"
printf 'alpha\t1.2.0\tApache-2.0\nalpha-pro\t2.0.0\tApache-2.0\nbeta-tool\t0.3.0\tApache-2.0\n' >> "$work/catalog-cache.tsv"

mkdir "$work/notes"
for t in alpha-v1.3.0-rc1 alpha-v1.2.0 alpha-v1.1.0 alpha-pro-v2.0.0 beta-tool-v0.3.0 alpha-v1.4.0; do
  printf 'What changed in %s.\n' "$t" > "$work/notes/$t.md"
done
printf '# Read me\n\nSee the [guide](#guide) and [site](https://example.com).\n' > "$work/docsrc/README.md"
printf '# Guide\n\nHow to use it.\n' > "$work/docsrc/USER_GUIDE.md"
printf '# Guide\n\n<img src="shot.png">\n' > "$work/docsrc/IMAGE_GUIDE.md"
printf '# Guide\n\nSee <a href="docs/more.md">more</a>.\n' > "$work/docsrc/RELATIVE_GUIDE.md"

rel ()  { printf '%s\t%s\t%s\thttps://github.com/%s/releases/tag/%s\t\t\t\t\n' "$1" "$2" "$3" "$REPO" "$1"; }
file () { printf '%s\t%s\t%s\thttps://github.com/%s/releases/tag/%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$REPO" "$1" "$4" "$5" "$6" "$7"; }
docs () {  # tag | prerelease | published | [guide source file]
  file "$1" "$2" "$3" README.md 100 "sha256:$SHA" "$DL/$1/README.md"
  file "$1" "$2" "$3" USER_GUIDE.md 100 "sha256:$SHA" "$DL/$1/${4:-USER_GUIDE.md}"
}

# A good repository: an older stable release, the newest stable one, a newer
# prerelease that must not displace it, a tool with only a prerelease and no
# GitHub digest, a slug that shares a prefix with another, and an orphan tag.
good_releases () {
  rel  alpha-v1.3.0-rc1 true  2026-03-01T00:00:00Z
  file alpha-v1.3.0-rc1 true  2026-03-01T00:00:00Z alpha-1.3.0-rc1.zip 100 "sha256:$SHA" "$DL/alpha-v1.3.0-rc1/alpha-1.3.0-rc1.zip"
  docs alpha-v1.3.0-rc1 true  2026-03-01T00:00:00Z
  rel  alpha-v1.2.0     false 2026-02-01T00:00:00Z
  file alpha-v1.2.0     false 2026-02-01T00:00:00Z alpha-1.2.0.zip 2048 "sha256:$SHA" "$DL/alpha-v1.2.0/alpha-1.2.0.zip"
  file alpha-v1.2.0     false 2026-02-01T00:00:00Z alpha-1.2.0.dmg 4096 "sha256:$SHA" "$DL/alpha-v1.2.0/alpha-1.2.0.dmg"
  docs alpha-v1.2.0     false 2026-02-01T00:00:00Z
  rel  alpha-v1.1.0     false 2026-01-01T00:00:00Z
  file alpha-v1.1.0     false 2026-01-01T00:00:00Z alpha-1.1.0.zip 10 "sha256:$SHA" "$DL/alpha-v1.1.0/alpha-1.1.0.zip"
  rel  alpha-pro-v2.0.0 false 2026-02-10T00:00:00Z
  file alpha-pro-v2.0.0 false 2026-02-10T00:00:00Z alpha-pro.msi 5 "sha256:$SHA" "$DL/alpha-pro-v2.0.0/alpha-pro.msi"
  docs alpha-pro-v2.0.0 false 2026-02-10T00:00:00Z
  rel  beta-tool-v0.3.0 true  2026-02-15T00:00:00Z
  file beta-tool-v0.3.0 true  2026-02-15T00:00:00Z beta.zip 7 "" "$DL/beta-tool-v0.3.0/beta.zip"
  docs beta-tool-v0.3.0 true  2026-02-15T00:00:00Z
  rel  orphan-v1.0.0    false 2026-02-20T00:00:00Z
}
# good_releases plus a newer alpha release built from the arguments given.
newer_alpha () {
  good_releases
  rel alpha-v1.4.0 false 2026-04-01T00:00:00Z
  "$@"
}

fails=0
check () {  # description | condition result (0 = pass)
  if [ "$2" = 0 ]; then echo "ok   - $1"; else echo "FAIL - $1"; fails=$((fails + 1)); fi
}
run () {  # releases-file | private -> sets out, code
  out="$(PATH="$work/bin:$PATH" FAKE_RELEASES="$1" FAKE_PRIVATE="${2:-false}" \
         FAKE_NOTES_DIR="$work/notes" FAKE_DOCS_DIR="$work/docsrc" \
         DOWNLOADS_REPO="$REPO" CATALOG_FILE="$work/catalog.txt" CACHE_FILE="$work/catalog-cache.tsv" DOWNLOADS_CACHE="$work/cache.tsv" \
         DOWNLOADS_DOCS="$work/docs" bash "$ROOT/fetch-downloads.sh" 2>&1)"
  code=$?
}
run_failing () {  # like run, but seeds the cache and documents first so each case proves on its own that a failure leaves them alone
  echo SENTINEL > "$work/cache.tsv"
  rm -rf "$work/docs"; mkdir -p "$work/docs/previous"; echo SENTINEL > "$work/docs/previous/notes.html"
  run "$@"
}
cache_rows () { awk -F'\t' '!/^#/' "$work/cache.tsv"; }
unchanged () {
  [ "$(cat "$work/cache.tsv")" = "SENTINEL" ] && [ "$(cat "$work/docs/previous/notes.html" 2>/dev/null)" = "SENTINEL" ] \
    && [ -z "$(find "$work" -maxdepth 1 -name 'docs.staging.*')" ]
}

# --- a good repository -------------------------------------------------------
good_releases > "$work/good.tsv"
rm -rf "$work/cache.tsv" "$work/docs"; mkdir -p "$work/docs/stale-app"
run "$work/good.tsv"
check "good repository succeeds" "$code"
check "the newest stable release wins over a newer prerelease" \
  "$(cache_rows | awk -F'\t' '$1=="alpha" && $2!="1.2.0"{b=1} $1=="alpha"{n++} END{exit b || n!=2}'; echo $?)"
check "a tool with only a prerelease lists it, marked as one" \
  "$(cache_rows | awk -F'\t' '$1=="beta-tool" && $2=="0.3.0" && $4=="true"{f=1} END{exit !f}'; echo $?)"
check "the sha256: prefix is stripped from GitHub's digest" \
  "$(cache_rows | awk -F'\t' -v h="$SHA" '$7=="alpha-1.2.0.zip" && $9==h{f=1} END{exit !f}'; echo $?)"
check "a file without a digest is kept with an empty checksum and a warning" \
  "$(cache_rows | awk -F'\t' '$7=="beta.zip" && $9=="" && NF==10{f=1} END{exit !f}' && grep -q 'beta.zip has no SHA-256' <<<"$out"; echo $?)"
check "a slug sharing a prefix gets its own release, not its neighbour's" \
  "$(cache_rows | awk -F'\t' '$1=="alpha-pro" && $3=="alpha-pro-v2.0.0"{f=1} $1=="alpha" && $3 ~ /pro/{b=1} END{exit !f || b}'; echo $?)"
check "a tag naming no catalogued app is reported and left out" \
  "$(grep -q 'orphan-v1.0.0 names no catalogued app' <<<"$out" && ! cache_rows | grep -q orphan; echo $?)"
check "a private-status tool with a public download is warned about" \
  "$(grep -q 'alpha-pro is catalogued as private' <<<"$out"; echo $?)"
check "README.md and USER_GUIDE.md are documents, not downloads" \
  "$(! cache_rows | awk -F'\t' '{print $7}' | grep -qE '^(README|USER_GUIDE)\.md$'; echo $?)"
check "each listed tool gets rendered notes, README and user guide" \
  "$(for s in alpha alpha-pro beta-tool; do for k in notes readme guide; do [ -s "$work/docs/$s/$k.html" ] || exit 1; done; done; echo $?)"
check "the notes shown belong to the release that was chosen" \
  "$(grep -q 'What changed in alpha-v1.2.0' "$work/docs/alpha/notes.html"; echo $?)"
check "document headings drop two levels to sit under the page's sections" \
  "$(grep -qE '<h3[ >][^<]*Read me</h3>' "$work/docs/alpha/readme.html" && ! grep -q '<h1' "$work/docs/alpha/readme.html"; echo $?)"
check "GitHub's heading permalinks, which would point nowhere on the site, are removed" \
  "$(! grep -qE 'markdown-heading|class="anchor"' "$work/docs/alpha/readme.html"; echo $?)"
check "no Markdown source is left beside the rendered documents" \
  "$( [ -z "$(find "$work/docs" -name '*.md')" ]; echo $?)"
check "the documents directory is replaced whole, dropping tools no longer listed" \
  "$( [ ! -e "$work/docs/stale-app" ]; echo $?)"

# --- failures leave the previous cache and documents in place --------------------
run_failing "$work/good.tsv" true
check "a private downloads repository is refused" "$( [ "$code" != 0 ] && grep -q 'is private' <<<"$out" && unchanged; echo $?)"

newer_alpha docs alpha-v1.4.0 false 2026-04-01T00:00:00Z > "$work/nofiles.tsv"
run_failing "$work/nofiles.tsv"
check "a newest release with no files fails instead of falling back" "$( [ "$code" != 0 ] && grep -q 'alpha-v1.4.0 is published with no files' <<<"$out" && unchanged; echo $?)"

newer_alpha file alpha-v1.4.0 false 2026-04-01T00:00:00Z a.zip 1 "sha256:$SHA" "$DL/alpha-v1.4.0/blocked.zip" > "$work/blocked.tsv"
{ cat "$work/blocked.tsv"; docs alpha-v1.4.0 false 2026-04-01T00:00:00Z; } > "$work/blocked2.tsv"
run_failing "$work/blocked2.tsv"
check "a file a visitor cannot download fails the fetch" "$( [ "$code" != 0 ] && grep -q 'not downloadable without signing in — HTTP 404' <<<"$out" && unchanged; echo $?)"

{ newer_alpha file alpha-v1.4.0 false 2026-04-01T00:00:00Z a.zip 1 "sha256:$SHA" "$DL/alpha-v1.4.0/unreachable.zip"
  docs alpha-v1.4.0 false 2026-04-01T00:00:00Z; } > "$work/unreach.tsv"
run_failing "$work/unreach.tsv"
check "an unreachable host is reported as unreachable, not as a missing file" "$( [ "$code" != 0 ] && grep -q 'could not reach' <<<"$out" && unchanged; echo $?)"

{ newer_alpha file alpha-v1.4.0 false 2026-04-01T00:00:00Z a.zip 1 "sha256:$SHA" "https://example.com/a.zip"
  docs alpha-v1.4.0 false 2026-04-01T00:00:00Z; } > "$work/offsite.tsv"
run_failing "$work/offsite.tsv"
check "a download URL outside the downloads repository is refused" "$( [ "$code" != 0 ] && grep -q 'unexpected download URL' <<<"$out" && unchanged; echo $?)"

{ newer_alpha file alpha-v1.4.0 false 2026-04-01T00:00:00Z a.zip 1 "sha256:$SHA" "$DL/alpha-v1.4.0/a.zip"
  file alpha-v1.4.0 false 2026-04-01T00:00:00Z README.md 100 "sha256:$SHA" "$DL/alpha-v1.4.0/README.md"; } > "$work/noguide.tsv"
run_failing "$work/noguide.tsv"
check "a release without USER_GUIDE.md is refused" "$( [ "$code" != 0 ] && grep -q 'alpha-v1.4.0 has no USER_GUIDE.md' <<<"$out" && unchanged; echo $?)"

{ newer_alpha file alpha-v1.4.0 false 2026-04-01T00:00:00Z a.zip 1 "sha256:$SHA" "$DL/alpha-v1.4.0/a.zip"
  docs alpha-v1.4.0 false 2026-04-01T00:00:00Z; } > "$work/nonotes.tsv"
mv "$work/notes/alpha-v1.4.0.md" "$work/notes-held.md"
run_failing "$work/nonotes.tsv"
mv "$work/notes-held.md" "$work/notes/alpha-v1.4.0.md"
check "a release with no release notes is refused" "$( [ "$code" != 0 ] && grep -q 'alpha-v1.4.0 has no release notes' <<<"$out" && unchanged; echo $?)"

{ newer_alpha file alpha-v1.4.0 false 2026-04-01T00:00:00Z a.zip 1 "sha256:$SHA" "$DL/alpha-v1.4.0/a.zip"
  docs alpha-v1.4.0 false 2026-04-01T00:00:00Z IMAGE_GUIDE.md; } > "$work/image.tsv"
run_failing "$work/image.tsv"
check "a document with an image is refused" "$( [ "$code" != 0 ] && grep -q 'contains an image' <<<"$out" && unchanged; echo $?)"

{ newer_alpha file alpha-v1.4.0 false 2026-04-01T00:00:00Z a.zip 1 "sha256:$SHA" "$DL/alpha-v1.4.0/a.zip"
  docs alpha-v1.4.0 false 2026-04-01T00:00:00Z RELATIVE_GUIDE.md; } > "$work/relative.tsv"
run_failing "$work/relative.tsv"
check "a document with a relative link is refused" "$( [ "$code" != 0 ] && grep -q 'has a relative link' <<<"$out" && unchanged; echo $?)"

{ newer_alpha file alpha-v1.4.0 false 2026-04-01T00:00:00Z a.zip 1 "sha256:$SHA" "$DL/alpha-v1.4.0/a.zip"
  file alpha-v1.4.0 false 2026-04-01T00:00:00Z README.md 100 "sha256:$SHA" "$DL/alpha-v1.4.0/README.md"
  file alpha-v1.4.0 false 2026-04-01T00:00:00Z USER_GUIDE.md 100 "sha256:$SHA" "$DL/alpha-v1.4.0/blocked-guide.md"; } > "$work/privguide.tsv"
run_failing "$work/privguide.tsv"
check "a document a visitor cannot download is refused" "$( [ "$code" != 0 ] && grep -q 'could not download guide of alpha-v1.4.0 without signing in' <<<"$out" && unchanged; echo $?)"

out="$(DOWNLOADS_REPO='https://github.com/acme/downloads' bash "$ROOT/fetch-downloads.sh" 2>&1)"; code=$?
check "a repository given as a URL is refused on arrival" "$( [ "$code" != 0 ] && grep -q 'must be owner/name' <<<"$out"; echo $?)"

out="$(DOWNLOADS_DOCS='../elsewhere' bash "$ROOT/fetch-downloads.sh" 2>&1)"; code=$?
check "a documents directory that climbs out is refused" "$( [ "$code" != 0 ] && grep -q 'DOWNLOADS_DOCS must name a directory' <<<"$out"; echo $?)"

echo
[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
