#!/usr/bin/env bash
# Reads the public downloads repository and writes downloads-cache.tsv: for each
# catalogued app, the files of its newest release there. Read-only: GETs through
# the gh CLI, plus one anonymous HEAD request per file.
#
#   bash fetch-downloads.sh
#
# The application repositories are private, and GitHub answers 404 to anyone
# not signed in with access to them, so their release files cannot be linked
# from a public site. A build meant for the public is published a second time,
# to one public repository, and this reads that one.
#
# RELEASE TAGS    <slug>-v<version>, the slug exactly as pinned in CATALOG.txt
#
#     project2excel-v1.0.2      restore-missing-photos-v1.22.0
#
# Every app shares the one repository, so the tag prefix is the only thing that
# says which product a file belongs to. A tag naming no catalogued slug is
# reported and left out, never matched to the nearest name.
#
# An app appears on the downloads page once it has a published release there.
# Drafts are ignored, so create the release as a draft, upload its files, then
# publish it: a visitor never sees a release before its files are in place.
#
# EVERY RELEASE ALSO CARRIES, written for the people downloading it:
#   release notes    the release description on GitHub
#   README.md        uploaded with the files
#   USER_GUIDE.md    uploaded with the files
# The site shows all three on its own download page, so visitors never need the
# GitHub release page, which always adds source archives and a tag. The two
# documents are not listed as downloads. A release missing any of them is
# refused. Links in them must be absolute or #anchors, and images are not
# supported: a relative path would break on the site, and an image would load
# from a host the privacy policy does not name.
#
# The cache is committed, like catalog-cache.tsv, so a diff shows exactly which
# files changed when a release lands.
set -uo pipefail

DOWNLOADS_REPO="${DOWNLOADS_REPO:-rcshou/bbst-downloads}"
CATALOG_FILE="${CATALOG_FILE:-CATALOG.txt}"
CACHE_FILE="${CACHE_FILE:-catalog-cache.tsv}"
DOWNLOADS_CACHE="${DOWNLOADS_CACHE:-downloads-cache.tsv}"
DOWNLOADS_DOCS="${DOWNLOADS_DOCS:-downloads-docs}"
DOC_MAX_BYTES=1048576

die () { echo "downloads: $*" >&2; exit 1; }

# The repository name can arrive through the environment, so check its shape on
# arrival: owner/name and nothing else, never a URL or a path.
printf '%s' "$DOWNLOADS_REPO" | grep -Eq '^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$' \
  || die "DOWNLOADS_REPO must be owner/name, got '$DOWNLOADS_REPO'"
# The documents directory is replaced wholesale, so refuse anything that could
# name more than a directory of its own.
case "$DOWNLOADS_DOCS" in
  ""|/|.|..|*//*|./*|../*|*/.|*/..|*/./*|*/../*)
    die "DOWNLOADS_DOCS must name a directory, got '$DOWNLOADS_DOCS'" ;;
esac
command -v gh   >/dev/null 2>&1 || die "gh CLI not found"
command -v curl >/dev/null 2>&1 || die "curl not found"
gh auth status >/dev/null 2>&1  || die "gh is not logged in — run 'gh auth login'"
[ -f "$CATALOG_FILE" ] || die "$CATALOG_FILE not found"
[ -f "$CACHE_FILE" ] || die "$CACHE_FILE not found — run 'bash fetch-catalog.sh' first"

echo "downloads: reading releases from https://github.com/$DOWNLOADS_REPO"

err="$(mktemp)"; raw="$(mktemp)"; rows="$(mktemp)"; docrows="$(mktemp)"; tmp="$(mktemp)"; apps="$(mktemp)"; stage=""
trap 'rm -f "$err" "$raw" "$rows" "$docrows" "$tmp" "$apps"; [ -z "$stage" ] || rm -rf "$stage"' EXIT

# The catalogued apps, in catalog order: slug, status (authored in CATALOG.txt)
# and version (fetched into the cache). awk rather than `read`, because an empty
# subpath column would collapse under tab's IFS-whitespace rules.
awk -F'\t' -v OFS='\t' '
  FNR == NR { if ($0 !~ /^#/ && NF >= 2) ver[$1] = $2; next }
  { sub(/\r$/, "") }
  $0 ~ /^#/ || NF < 8 { next }
  { print $1, $7, ($1 in ver && ver[$1] != "" ? ver[$1] : "—") }
' "$CACHE_FILE" "$CATALOG_FILE" > "$apps"
[ -s "$apps" ] || die "$CATALOG_FILE lists no apps"

# "Not there" and "could not ask" have different remedies, so say which.
if ! vis="$(gh api "repos/$DOWNLOADS_REPO" --jq '.private|tostring' 2>"$err")"; then
  if grep -q 'HTTP 404' "$err"; then
    die "$DOWNLOADS_REPO does not exist, or this login cannot see it"
  fi
  die "could not reach GitHub for $DOWNLOADS_REPO: $(head -1 "$err")"
fi
[ "$vis" = "false" ] \
  || die "$DOWNLOADS_REPO is private, so every file would be a 404 for visitors — make it public"

# One row per published release with an empty file name, then one row per file
# it carries. The release row keeps a release with no files visible, which is a
# broken publish rather than something to skip past.
if ! gh api --paginate "repos/$DOWNLOADS_REPO/releases?per_page=100" --jq '
    .[] | select(.draft | not) | . as $r
    | ( [$r.tag_name, ($r.prerelease|tostring), ($r.published_at // ""), $r.html_url, "", "", "", ""],
        ($r.assets[] | select(.state == "uploaded")
         | [$r.tag_name, ($r.prerelease|tostring), ($r.published_at // ""), $r.html_url,
            .name, (.size|tostring), (.digest // ""), .browser_download_url]) )
    | @tsv' > "$raw" 2>"$err"; then
  die "could not list releases of $DOWNLOADS_REPO: $(head -1 "$err")"
fi

# Match each release to a catalogued slug, keep each slug's newest release, and
# validate everything that will be written into a page. Release data is
# untrusted input, even from our own repository.
awk -F'\t' -v OFS='\t' -v repo="$DOWNLOADS_REPO" -v docfile="$docrows" '
  function warn(m) { print "downloads: warning: " m > "/dev/stderr" }
  function fail(m) { print "downloads: " m > "/dev/stderr"; bad = 1 }
  FNR == NR {
    n++; order[n] = $1; stat[$1] = $2; ver[$1] = $3
    next
  }
  {
    tag = $1; own = ""
    for (i = 1; i <= n; i++) {
      p = order[i] "-v"
      if (index(tag, p) == 1 && substr(tag, length(p) + 1, 1) ~ /[0-9]/ && length(order[i]) > length(own))
        own = order[i]
    }
    if (own == "") {
      if (!(tag in orphan)) { orphan[tag] = 1; warn("tag " tag " names no catalogued app, so nothing from it is listed") }
      next
    }
    if ($5 == "") { pre[tag] = $2; pub[tag] = $3; rel[tag] = $4; owner[tag] = own; files[tag] += 0; next }
    # The two documents travel with the files but are shown, not offered.
    if ($5 == "README.md" || $5 == "USER_GUIDE.md") { doc[tag, $5] = $8; next }
    k = ++files[tag]; fname[tag, k] = $5; fsize[tag, k] = $6; fdig[tag, k] = $7; furl[tag, k] = $8
  }
  END {
    for (i = 1; i <= n; i++) {
      s = order[i]; best = ""
      for (t in owner) {
        if (owner[t] != s) continue
        # A stable release beats any prerelease; between two of a kind, the newer.
        if (best == "" || (pre[t] == "false" && pre[best] == "true") || (pre[t] == pre[best] && pub[t] > pub[best]))
          best = t
      }
      if (best == "") continue
      v = substr(best, length(s) + 3)
      if (v !~ /^[0-9][0-9A-Za-z.+-]*$/) { fail(best ": version \"" v "\" is not a version number"); continue }
      if (index(rel[best], "https://github.com/" repo "/releases/tag/") != 1) { fail(best ": unexpected release page URL"); continue }
      if (files[best] == 0) { fail(best " is published with no files — upload them, or unpublish it"); continue }
      missing = 0
      split("README.md USER_GUIDE.md", names, " ")
      for (j = 1; j <= 2; j++) {
        u = doc[best, names[j]]
        if (u == "") { fail(best " has no " names[j] " — upload one written for the people downloading it"); missing = 1 }
        else if (index(u, "https://github.com/" repo "/releases/download/") != 1) { fail(best ": " names[j] " has an unexpected download URL"); missing = 1 }
      }
      if (missing) continue
      print s, best, "readme", doc[best, "README.md"] > docfile
      print s, best, "guide", doc[best, "USER_GUIDE.md"] > docfile
      if (v != ver[s]) warn(s " is catalogued at version " ver[s] " but its newest download is " v)
      if (stat[s] == "private" || stat[s] == "dev") warn(s " is catalogued as " stat[s] " but now has a public download — update its status in CATALOG.txt")
      for (k = 1; k <= files[best]; k++) {
        u = furl[best, k]; d = fdig[best, k]; sub(/^sha256:/, "", d)
        if (index(u, "https://github.com/" repo "/releases/download/") != 1) { fail(best ": " fname[best, k] " has an unexpected download URL"); continue }
        if (fsize[best, k] !~ /^[0-9]+$/) { fail(best ": " fname[best, k] " has no size"); continue }
        if (length(d) != 64 || d ~ /[^0-9a-f]/) { warn(best ": " fname[best, k] " has no SHA-256 from GitHub; the page shows none"); d = "" }
        print s, v, best, pre[best], substr(pub[best], 1, 10), rel[best], fname[best, k], fsize[best, k], d, u
      }
    }
    exit bad
  }' "$apps" "$raw" > "$rows" || { echo "downloads: cache not replaced" >&2; exit 1; }

# GitHub reporting a file is not proof a visitor can fetch it. Ask the way a
# visitor does: no credentials, following the redirect to the file store.
fail=0
while IFS= read -r line; do
  url="${line##*$'\t'}"; file="$(printf '%s' "$line" | cut -f7)"; tag="$(printf '%s' "$line" | cut -f3)"
  code="$(curl -sS -o /dev/null -I -L --max-time 30 -w '%{http_code}' "$url" 2>"$err")"
  case "$code" in
    200) ;;
    000|"") echo "downloads: could not reach $url to check $file ($tag): $(head -1 "$err")" >&2; fail=1 ;;
    *)      echo "downloads: $file ($tag) is not downloadable without signing in — HTTP $code" >&2; fail=1 ;;
  esac
done < "$rows"
[ "$fail" = "0" ] || { echo "downloads: cache not replaced" >&2; exit 1; }

# Apply a sed expression to a file in place, on either sed.
#
# GNU sed takes the suffix `-i` uses attached (`-i.bak`) and treats a bare
# `-i` as "no backup"; BSD sed always reads the suffix as the next argument,
# so `sed -i -E 'expr' file` quietly takes "-E" as the suffix and then runs
# the expression without extended regular expressions -- every capture group
# becomes a literal parenthesis and the substitution fails with "\1 not
# defined in the RE". Writing to a sibling file and renaming avoids the
# incompatibility, and the rename is atomic.
edit_in_place () {  # sed-expression | file
  local rewritten="$2.rewritten"
  sed -E "$1" "$2" > "$rewritten" && mv "$rewritten" "$2"
}

# Render each release's notes, README and user guide into page fragments. GitHub's
# own Markdown renderer does the work, in document mode (the way it renders a
# README, not a comment), and it escapes scripts and drops event handlers and
# javascript: links. It wraps each heading with a permalink whose target id it
# prefixes, so the link would go nowhere here; the wrapper is removed. Headings
# then drop two levels so a document's own "# Title" sits under the section
# heading the page gives it.
render () {  # markdown-file | html-file | label
  if ! gh api markdown -F text=@"$1" -f mode=markdown > "$2" 2>"$err"; then
    echo "downloads: could not render $3: $(head -1 "$err")" >&2; return 1
  fi
  edit_in_place 's#<div class="markdown-heading">(<h[1-6][^>]*>.*</h[1-6]>)<a id="user-content-[^"]*" class="anchor"[^>]*>.*</a></div>#\1#' "$2"
  if grep -qi '<img' "$2"; then
    echo "downloads: $3 contains an image; images are not supported in release documents" >&2; return 1
  fi
  local bad
  bad="$(grep -oiE 'href="[^"]*"' "$2" | grep -viE '^href="(https?://|mailto:|#)' | head -1)"
  if [ -n "$bad" ]; then
    echo "downloads: $3 has a relative link ($bad); use an absolute URL or a #anchor" >&2; return 1
  fi
  edit_in_place 's#<(/?)h[456]([ >])#<\1h6\2#g; s#<(/?)h3([ >])#<\1h5\2#g; s#<(/?)h2([ >])#<\1h4\2#g; s#<(/?)h1([ >])#<\1h3\2#g' "$2"
}

stage="$(mktemp -d "${DOWNLOADS_DOCS%/}.staging.XXXXXX")" || die "cannot create a staging directory beside $DOWNLOADS_DOCS"
while IFS=$'\t' read -r slug tag; do
  mkdir -p "$stage/$slug"
  if ! gh api "repos/$DOWNLOADS_REPO/releases/tags/$tag" --jq '.body // ""' > "$stage/$slug/notes.md" 2>"$err"; then
    echo "downloads: could not read the release notes of $tag: $(head -1 "$err")" >&2; fail=1; continue
  fi
  if ! grep -q '[^[:space:]]' "$stage/$slug/notes.md"; then
    echo "downloads: $tag has no release notes — write them in the release description" >&2; fail=1; continue
  fi
  render "$stage/$slug/notes.md" "$stage/$slug/notes.html" "the release notes of $tag" || fail=1
done < <(cut -f1,3 "$rows" | sort -u)
# Fetched without credentials, like the files, so a document only we can read
# never reaches the page.
while IFS=$'\t' read -r slug tag kind url; do
  md="$stage/$slug/$kind.md"
  if ! curl -sS -L --fail --max-time 60 --max-filesize "$DOC_MAX_BYTES" -o "$md" "$url" 2>"$err"; then
    echo "downloads: could not download $kind of $tag without signing in: $(head -1 "$err")" >&2; fail=1; continue
  fi
  render "$md" "$stage/$slug/$kind.html" "the $kind of $tag" || fail=1
done < "$docrows"
[ "$fail" = "0" ] || { echo "downloads: cache not replaced" >&2; exit 1; }
rm -f "$stage"/*/*.md

printf '# generated by fetch-downloads.sh — do not edit by hand\n' > "$tmp"
printf '# slug\tversion\ttag\tprerelease\tpublished\trelease_url\tfile\tsize\tsha256\turl\n' >> "$tmp"
cat "$rows" >> "$tmp"
awk -F'\t' '{ c[$1]++; v[$1] = $2; if (!seen[$1]++) o[++n] = $1 }
  END { for (i = 1; i <= n; i++) printf "  %-30s %-10s %d file(s)\n", o[i], v[o[i]], c[o[i]]
        if (n == 0) print "  no catalogued app has a published release yet" }' "$rows"
# The documents and the cache change together: a page must never pair one
# release's files with another's documents.
rm -rf "$DOWNLOADS_DOCS" && mv "$stage" "$DOWNLOADS_DOCS" && stage="" \
  || die "could not replace $DOWNLOADS_DOCS; cache not replaced"
mv "$tmp" "$DOWNLOADS_CACHE"; trap 'rm -f "$err" "$raw" "$rows" "$docrows"' EXIT
echo "downloads: wrote $DOWNLOADS_CACHE and $DOWNLOADS_DOCS/"
