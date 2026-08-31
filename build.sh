#!/usr/bin/env bash
# Generates every page of the Bluebonnet Studios catalog from one shared shell.
# Run from the repository root:  bash build.sh
set -euo pipefail

UPDATED="2026-08-29"

# Contact and Q&A routes. Discussions must be enabled on the repository for the
# Q&A links to resolve; see README.
REPO="https://github.com/rcshou/bbst-software"
CONTACT_EMAIL="dev@bbst.us"

# Percent-encode spaces so a prefilled discussion title survives the URL.
urlenc () { printf "%s" "$1" | sed "s/ /%20/g"; }

# Escape the four characters that would otherwise be read as markup. Applied
# once, where catalog data enters TOOLS, so every consumer below is safe without
# having to remember. Deliberate HTML — tool_prose, the page shells — is authored
# in this file and is never routed through here.
esc () { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }

# --- catalog data ------------------------------------------------------------
# Two sources, joined on the slug:
#
#   CATALOG.txt        authored — slug, repo, subpath, name, category,
#                      platform, status, summary. Reviewed, and the only place
#                      the site's own words about a tool are decided.
#   catalog-cache.tsv  fetched — slug, version, license. The two facts that
#                      change upstream without anyone editing this repository.
#
#   bash build.sh             build from the cache as it stands
#   bash build.sh --refresh   refresh versions and licences first, then build
CATALOG_FILE="${CATALOG_FILE:-CATALOG.txt}"
CACHE_FILE="${CACHE_FILE:-catalog-cache.tsv}"

if [ "${1:-}" = "--refresh" ]; then
  bash fetch-catalog.sh || { echo "build: fetch failed; not building from a stale cache" >&2; exit 1; }
fi

[ -f "$CATALOG_FILE" ] || { echo "build: $CATALOG_FILE not found" >&2; exit 1; }
if [ ! -f "$CACHE_FILE" ]; then
  echo "build: $CACHE_FILE not found — run 'bash fetch-catalog.sh' first" >&2
  exit 1
fi

# Join the two files into the tab-separated internal form:
#   name  slug  category  version  platform  status  summary  license
# Tab throughout, so a character that can appear in a summary can never be
# mistaken for a field separator. awk splits on every tab, so an empty column is
# preserved rather than collapsed — which is why the join happens here and not in
# a `read` loop, where tab's IFS-whitespace behaviour would shift the fields.
#
# Every column is required, so an empty one is an error rather than something to
# paper over: the loops below read this back with IFS, and a blank field there
# would silently misalign the row.
TOOLS="$(
  awk -F'\t' -v OFS='\t' '
    FNR==NR { if ($0 !~ /^#/ && NF>=3) { ver[$1]=$2; lic[$1]=$3 } ; next }
    /^#/ || $0 ~ /^[[:space:]]*$/ { next }
    NF<8 { printf("build: %s line %d has %d columns, expected 8\n", FILENAME, FNR, NF) > "/dev/stderr"; bad=1; next }
    {
      slug=$1
      for (i=4; i<=8; i++)
        if ($i == "") { printf("build: [%s] column %d is empty\n", slug, i) > "/dev/stderr"; bad=1 }
      print $4, slug, $5, (slug in ver && ver[slug] != "" ? ver[slug] : "—"), $6, $7, $8,
            (slug in lic && lic[slug] != "" ? lic[slug] : "Not stated")
    }
    END { if (bad) exit 1 }
  ' "$CACHE_FILE" "$CATALOG_FILE"
)" || { echo "build: $CATALOG_FILE is not usable" >&2; exit 1; }
[ -n "$TOOLS" ] || { echo "build: $CATALOG_FILE has no usable rows" >&2; exit 1; }

# Escape every field once, here, rather than at each of the two dozen points
# where one reaches the page.
TOOLS="$(
  printf '%s\n' "$TOOLS" | while IFS=$'\t' read -r name slug cat ver plat stat desc lic; do
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(esc "$name")" "$slug" "$(esc "$cat")" "$(esc "$ver")" \
      "$(esc "$plat")" "$stat" "$(esc "$desc")" "$(esc "$lic")"
  done
)"

# A slug becomes a filename and a URL, so it must stay a plain identifier no
# matter what lands in CATALOG.txt.
printf '%s\n' "$TOOLS" | while IFS=$'\t' read -r _ slug _rest; do
  case "$slug" in
    *[!a-z0-9-]*|'') echo "build: invalid slug '$slug' — use lowercase letters, digits and hyphens" >&2; exit 1 ;;
  esac
done || exit 1

# key | page | display label. The page filename is pinned for the same reason a
# slug is: renaming a category must never break a published link.
CATEGORIES='Business|business-tools.html|Business Tools
Web & Mobile|web-apps.html|Web & Mobile
Lightroom|lightroom-plugins.html|Lightroom Plugins
Geoscience|geoscience-tools.html|Geoscience Tools'
# Escape these the same way TOOLS is escaped, so category lookups compare like
# with like. Without this, a category containing "&" would never match its own
# rows — the catalog value arrives escaped and this table would not be.
CATEGORIES="$(
  printf '%s\n' "$CATEGORIES" | while IFS='|' read -r k p l; do
    printf '%s|%s|%s\n' "$(esc "$k")" "$p" "$(esc "$l")"
  done
)"
tool_field () {  # slug field-index
  printf '%s\n' "$TOOLS" | awk -F'\t' -v s="$1" -v n="$2" '$2==s{print $n; exit}'
}
count_in () {  # category
  printf '%s\n' "$TOOLS" | awk -F'\t' -v c="$1" '$3==c' | wc -l | tr -d ' '
}
total_tools () { printf '%s\n' "$TOOLS" | wc -l | tr -d ' '; }
cat_page () { printf '%s\n' "$CATEGORIES" | awk -F'|' -v c="$1" '$1==c{print $2; exit}'; }
cat_label () { printf '%s\n' "$CATEGORIES" | awk -F'|' -v c="$1" '$1==c{print $3; exit}'; }

# --- shared shell ------------------------------------------------------------
page_open () {  # title | description | nav-current
  local title="$1" desc="$2" navcur="${3:-}"
  local catmark="" aboutmark=""
  [ "$navcur" = "catalog" ] && catmark=' aria-current="page"'
  [ "$navcur" = "about" ] && aboutmark=' aria-current="page"'
cat <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>$title</title>
  <meta name="description" content="$desc" />
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,500;0,6..72,600;1,6..72,400&family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" />
  <link rel="icon" href="favicon.svg" type="image/svg+xml" />
  <link rel="stylesheet" href="styles.css" />
  <script>
    /* Apply the stored theme before first paint so the page never flashes. */
    (function(){try{var t=localStorage.getItem("bbst-theme");
    if(t==="light"||t==="dark")document.documentElement.setAttribute("data-theme",t);}catch(e){}})();
  </script>
</head>
<body>
  <a class="skip" href="#main">Skip to content</a>

  <header class="topbar">
    <div class="topbar-inner">
      <a class="brand" href="index.html">
        <svg class="mark" width="14" height="16" viewBox="0 0 14 16" aria-hidden="true" focusable="false">
          <rect class="stem" x="6.3" y="7" width="1.4" height="9" rx="0.7" />
          <circle class="petal" cx="7" cy="3.6" r="3.6" />
          <circle class="spot" cx="7" cy="2.6" r="1.15" />
        </svg>
        Bluebonnet Studios
      </a>
      <div class="topbar-right">
        <nav class="mainnav" aria-label="Primary">
          <a href="index.html"$catmark>Catalog</a>
          <a href="about.html"$aboutmark>About</a>
          <a href="index.html#access">Access</a>
        </nav>
        <button class="theme-toggle" type="button" aria-label="Switch color theme">
          <svg viewBox="0 0 16 16" aria-hidden="true" focusable="false">
            <circle cx="8" cy="8" r="6.5" fill="none" stroke="currentColor" stroke-width="1.4" />
            <path d="M8 1.5A6.5 6.5 0 0 1 8 14.5Z" fill="currentColor" />
          </svg>
        </button>
      </div>
    </div>
  </header>
HTML
}

page_close () {
cat <<HTML
  <footer class="site-foot">
    <div class="site-foot-inner">
      <span>Bluebonnet Studios</span>
      <span>Catalog updated $UPDATED &middot; <a href="index.html#access">Access</a> &middot; <a href="privacy.html">Privacy</a> &middot; <a href="mailto:$CONTACT_EMAIL">$CONTACT_EMAIL</a></span>
    </div>
  </footer>
  <script src="theme.js"></script>
</body>
</html>
HTML
}

rail () {  # current-page-file | active-slug
  local cur="${1:-}" mode="${2:-current}"
  printf '    <nav class="rail" aria-label="Categories">\n'
  printf '      <h2>Categories</h2>\n'
  rail_link "index.html" "All tools" "$(total_tools)" "$cur" "$mode"
  printf '%s\n' "$CATEGORIES" | while IFS='|' read -r c page label; do
    rail_link "$page" "$c" "$(count_in "$c")" "$cur" "$mode"
  done
  printf '      <p class="rail-note">Binaries are distributed privately. This catalog publishes version and availability only.</p>\n'
  printf '    </nav>\n'
}

rail_link () {  # href | label | count | current-file | mode
  local mark=""
  if [ "$1" = "$4" ]; then
    # "related" marks the category a tool belongs to: highlighted, but not
    # the page the reader is actually on, so aria-current would be a lie.
    if [ "${5:-current}" = "related" ]; then mark=' class="is-active"'
    else mark=' aria-current="page"'; fi
  fi
  printf '      <a href="%s"%s>%s <em>%s</em></a>\n' "$1" "$mark" "$2" "$3"
}


# --- page art ---------------------------------------------------------------
# One ornament per page, placed by its shape: the wide arch crowns the home
# page, the wide garland closes a page as a tailpiece, and the two tall stems
# run down the aside column of a tool page. All are decorative, so they carry
# an empty alt and are hidden from assistive technology.
art_file () {  # page key -> path|width|height
  case "$1" in
    index)                      printf 'assets/bluebonnet-header.png|1280|435' ;;
    about|privacy|geoscience-tools)
                                printf 'assets/bluebonnet-footer.png|860|391' ;;
    business-tools|lightroom-plugins|web-apps)
                                printf 'assets/bluebonnet-header.png|1280|435' ;;
    project2excel|markdown-renderer|bakmil-metro|restore-missing-photos|geocrawler|cassandra-risking)
                                printf 'assets/bluebonnet-side-left.png|380|824' ;;
    *)                          printf 'assets/bluebonnet-side-right.png|380|950' ;;
  esac
}

art () {  # page key | kind (crown | tail | column)
  local spec file w h
  spec="$(art_file "$1")"
  file="${spec%%|*}"; spec="${spec#*|}"; w="${spec%%|*}"; h="${spec#*|}"
  local lazy=' loading="lazy"'
  [ "$2" = "crown" ] && lazy=''
  printf '      <div class="art art-%s"><img src="%s" width="%s" height="%s" alt="" aria-hidden="true" decoding="async"%s /></div>\n' \
    "$2" "$file" "$w" "$h" "$lazy"
}

# --- status vocabulary -------------------------------------------------------
status_chip () {
  case "$1" in
    released) printf '<span class="chip is-released">Released</span>' ;;
    beta)     printf '<span class="chip is-beta">Beta</span>' ;;
    private)  printf '<span class="chip is-private">Private release</span>' ;;
    *)        printf '<span class="chip is-dev">In development</span>' ;;
  esac
}
status_action () {  # status | access-href
  case "$1" in
    released|beta) printf '<a class="btn" href="%s">Download</a>' "$2" ;;
    private)       printf '<a class="btn" href="%s">Request</a>' "$2" ;;
    *)             printf '<span class="btn" aria-disabled="true">Unreleased</span>' ;;
  esac
}

# --- roster table ------------------------------------------------------------
roster () {  # access-href | category-filter (empty = all)
  local access="$1" filter="${2:-}"
  local catth="" cattd=""
  # a filtered page already names its category in the section label
  [ -z "$filter" ] && catth='<th scope="col">Category</th>'
  printf '      <div class="tablewrap">\n        <table class="roster">\n          <thead>\n            <tr>\n'
  printf '              <th scope="col">Tool</th>\n'
  [ -n "$catth" ] && printf '              %s\n' "$catth"
  printf '              <th scope="col">Version</th>\n'
  printf '              <th scope="col">Platform</th>\n'
  printf '              <th scope="col">Status</th>\n'
  printf '              <th scope="col"><span class="visually-hidden">Availability</span></th>\n'
  printf '            </tr>\n          </thead>\n          <tbody>\n'
  printf '%s\n' "$TOOLS" | while IFS=$'\t' read -r name slug cat ver plat stat desc lic; do
    [ -n "$name" ] || continue
    if [ -n "$filter" ] && [ "$cat" != "$filter" ]; then continue; fi
    cattd=""
    [ -z "$filter" ] && cattd="              <td class=\"num\" data-label=\"Category\">$cat</td>"
    printf '            <tr>\n'
    printf '              <td class="tool"><a href="%s.html">%s</a><small>%s</small></td>\n' "$slug" "$name" "$desc"
    [ -n "$cattd" ] && printf '%s\n' "$cattd"
    printf '              <td class="num" data-label="Version">%s</td>\n' "$ver"
    printf '              <td class="num" data-label="Platform">%s</td>\n' "$plat"
    printf '              <td data-label="Status">%s</td>\n' "$(status_chip "$stat")"
    printf '              <td class="act" data-label="Get">%s</td>\n' "$(status_action "$stat" "$access")"
    printf '            </tr>\n'
  done
  printf '          </tbody>\n        </table>\n      </div>\n'
}

access_section () {
cat <<HTML
      <section id="access">
        <p class="section-label">Access and releases</p>
        <div class="access-box">
          <p>Bluebonnet Studios builds and releases from private repositories. This catalog is the
             public record: it publishes each tool&rsquo;s version, platform and availability, while the
             binaries themselves ship through their own channels. <strong>Nothing here is a
             subscription, and nothing here phones home.</strong></p>
          <p>Questions are answered in the open. Ask on GitHub Discussions and the answer stays
             searchable for whoever asks the same thing next; email is there for release requests
             and anything that should not be public.</p>
          <div class="routes">
            <div>
              <h3>Ask a question</h3>
              <p>Public Q&amp;A on GitHub Discussions — how a tool works, whether it fits, what it
                 does not do. Answers get marked, so the thread stays useful.</p>
              <a class="btn" href="$REPO/discussions/new?category=q-a">Start a discussion</a>
            </div>
            <div>
              <h3>Report a problem</h3>
              <p>Something in this catalog wrong, a broken link, or a defect in a tool you have a
                 build of. Issue forms will route it.</p>
              <a class="btn" href="$REPO/issues/new/choose">Open an issue</a>
            </div>
            <div>
              <h3>Request a release</h3>
              <p>For a private release, or to hear when a tool reaches general availability. Use
                 email if the request itself should stay private.</p>
              <a class="btn" href="mailto:$CONTACT_EMAIL">$CONTACT_EMAIL</a>
            </div>
          </div>
          <dl class="legend">
            <div>
              <dt><span class="chip is-released">Released</span></dt>
              <dd>Generally available. A version number and a download are published here.</dd>
            </div>
            <div>
              <dt><span class="chip is-beta">Beta</span></dt>
              <dd>Feature-complete and usable, still collecting reports before general release.</dd>
            </div>
            <div>
              <dt><span class="chip is-private">Private release</span></dt>
              <dd>Built, versioned and in daily use. Distributed on request rather than published.</dd>
            </div>
            <div>
              <dt><span class="chip is-dev">In development</span></dt>
              <dd>Being built. Described here so you know it exists, with nothing to hand out yet.</dd>
            </div>
          </dl>
        </div>
      </section>
HTML
}

# --- licensing ---------------------------------------------------------------
# Read from CATALOG.txt, which records what each repository's LICENSE file
# declares. "Not stated" means the repository carries no LICENSE file, not that
# the tool is unlicensed.
tool_license () { tool_field "$1" 8; }
tool_copyright () {
  printf 'Bluebonnet Studios'
}

# --- tool page ---------------------------------------------------------------
tool_page () {  # slug
  local slug="$1"
  local name cat ver plat stat desc
  name="$(tool_field "$slug" 1)"; cat="$(tool_field "$slug" 3)"
  ver="$(tool_field "$slug" 4)"; plat="$(tool_field "$slug" 5)"
  stat="$(tool_field "$slug" 6)"; desc="$(tool_field "$slug" 7)"
  local cpage cl
  cpage="$(cat_page "$cat")"; cl="$(cat_label "$cat")"

  page_open "$name — Bluebonnet Studios" "$(tool_meta_desc "$slug")" ""
cat <<HTML
  <div class="page-head">
    <div class="page-head-inner">
      <div>
        <p class="eyebrow"><a href="$cpage">$cl</a></p>
        <h1>$name</h1>
$(sub="$(tool_subtitle "$slug")"; [ -n "$sub" ] && printf '        <p class="subtitle">%s</p>' "$sub")
        <div class="head-meta">
          $(status_chip "$stat")
          <span class="ver">Version $ver &middot; $plat</span>
        </div>
        <p>$(tool_lede "$slug")</p>
      </div>
    </div>
  </div>

  <div class="layout">
HTML
  rail "$cpage" "related"
cat <<HTML
    <main class="content" id="main">
      <div class="tool-body">
        <div class="prose">
HTML
  tool_prose "$slug"
cat <<HTML
        </div>

        <div class="tool-side">
        <div class="aside-dock">
        <div class="aside-stack">
        <aside class="aside">
          <h2>At a glance</h2>
          <dl>
            <div><dt>Version</dt><dd>$ver</dd></div>
            <div><dt>Status</dt><dd>$(status_word "$stat")</dd></div>
            <div><dt>Platform</dt><dd>$plat</dd></div>
            <div><dt>Category</dt><dd><a href="$cpage">$cat</a></dd></div>
            <div><dt>License</dt><dd>$(tool_license "$slug")</dd></div>
            <div><dt>Copyright</dt><dd>$(tool_copyright "$slug")</dd></div>
            <div><dt>Updated</dt><dd>$UPDATED</dd></div>
          </dl>
          <div class="aside-act">
            $(status_action "$stat" "index.html#access")
            <p>$(access_note "$stat")</p>
            <p class="aside-ask"><a href="$REPO/discussions/new?category=q-a&amp;title=$(urlenc "Question about $name")">Ask about $name</a> on GitHub Discussions, or email <a href="mailto:$CONTACT_EMAIL">$CONTACT_EMAIL</a>.</p>
          </div>
        </aside>
$(tool_release "$slug" "$ver")
        </div>
        </div>
$(art "$slug" column)
        </div>
      </div>

      <section>
        <p class="section-label">More in $cl</p>
HTML
  roster "index.html#access" "$cat"
cat <<HTML
      </section>
    </main>
  </div>
HTML
  page_close
}

status_word () {
  case "$1" in
    released) printf 'Released' ;;
    beta) printf 'Beta' ;;
    private) printf 'Private release' ;;
    *) printf 'In development' ;;
  esac
}
access_note () {
  case "$1" in
    released|beta) printf 'Published build. Version and release notes are listed above.' ;;
    private) printf 'Built and versioned, distributed on request rather than published.' ;;
    *) printf 'Still being built. Nothing to download yet.' ;;
  esac
}

# --- per-tool copy -----------------------------------------------------------
# Long-form, public-facing copy, keyed by slug. Written for someone deciding
# whether a tool solves their problem — not a README, and not derived from one
# mechanically. Each page states what the tool is for, what it actually does,
# and what it deliberately does not do.

# A subtitle says what the tool does in plain words, for a reader who has only
# ever seen its name. Names and slugs are pinned; this carries the explanation.
tool_subtitle () {
  case "$1" in
    project2excel)            printf 'Read a Microsoft Project schedule without Microsoft Project' ;;
    pdf-classifier)           printf 'Know which pages need OCR before you pay for it' ;;
    markdown-renderer)        printf 'See what your Markdown will look like everywhere else' ;;
    bakmil-metro)             printf 'When the next Bakmil shuttle leaves' ;;
    apk-finder)               printf 'Android apps for the devices Google left out' ;;
    similars-and-statistics)  printf 'Four catalog chores, one plugin' ;;
    restore-missing-photos)   printf 'Put the files Lightroom lost back where the catalog expects them' ;;
    location-caption)         printf 'The temple, not the province' ;;
    geocrawler)               printf 'Find out what is actually in your data repository' ;;
    segy-coordinate-security) printf 'Share seismic data without giving away where it was shot' ;;
    cassandra-risking)        printf 'Chance of success, with the evidence still attached' ;;
  esac
}

# The latest release, in the reader's terms. Written from each project's own
# user-facing release notes where it keeps them, not from its engineering
# changelog: the point is what a person would notice, not what the diff touched.
# A tool with no release notes for the version on show simply has no box.
tool_release () {  # slug | version
  local body; body="$(tool_release_notes "$1")"
  [ -n "$body" ] || return 0
  printf '        <aside class="release-box" aria-labelledby="rel-%s">\n' "$1"
  printf '          <p class="release-kicker" id="rel-%s">New in %s</p>\n' "$1" "$2"
  printf '%s\n' "$body"
  printf '        </aside>\n'
}

tool_release_notes () {
  case "$1" in
    pdf-classifier) cat <<'HTML'
          <ul>
            <li><b>Text in the Mac app is readable again.</b> It now uses the size macOS itself uses for interface text, matching the Windows app.</li>
            <li><b>The page picture follows the page you are on.</b> Previously the arrows and the page box moved the extracted text while the picture stayed put.</li>
            <li><b>The &ldquo;Follow page selection&rdquo; tick box no longer collides</b> with the one beside it on macOS.</li>
          </ul>
HTML
    ;;
    geocrawler) cat <<'HTML'
          <ul>
            <li><b>Clearer labels for well-log formats.</b> A LIS file that cannot be read now reads as <em>read failed</em> rather than &ldquo;unsupported&rdquo; &mdash; LIS is a format Geocrawler supports and attempts, so a failure there is about that file, not the format.</li>
            <li><b>The LAS tab has Format and Status columns</b>, so a LAS 3.0 file shows as unsupported at a glance instead of looking like an ordinary well with missing data.</li>
          </ul>
HTML
    ;;
    similars-and-statistics) cat <<'HTML'
          <ul>
            <li><b>Fix invalid capture date no longer fails part-way through.</b> The tool could abort with a Lightroom context error before it finished; the operation now holds its context open for the whole run.</li>
            <li><b>One similar-photo tool instead of two.</b> The separate structural-comparison item is gone &mdash; the main histogram search already applies the same structural check, so the second menu entry only offered a slower route to the same answer.</li>
          </ul>
HTML
    ;;
    restore-missing-photos) cat <<'HTML'
          <ul>
            <li><b>Scanning the same folder twice is now instant.</b> Each source folder&rsquo;s index is kept for the rest of the Lightroom session, so a second pass over a large NAS share reuses it instead of walking the whole tree again.</li>
            <li><b>Every match is re-checked before it is offered.</b> A cached index can describe a folder as it was earlier, so a file that has since moved is verified on disk first, dropped from the index if gone, and counted in the results.</li>
            <li><b>A failed scan is now reported as a failure.</b> A disconnected disk or NAS share during indexing raises an explicit error instead of quietly producing &ldquo;not found&rdquo; results.</li>
          </ul>
HTML
    ;;
    markdown-renderer) cat <<'HTML'
          <ul>
            <li><b>Table and figure captions.</b> <code>Table:</code> and <code>Figure:</code> captions are recognised, rendered, and checked in the diagnostics.</li>
            <li><b>A native desktop menu</b> for Open, Export, Search, Cleanup, Full Check, Preferences and Help, with more reliable recent-files handling.</li>
            <li><b>Toolbar buttons stay put</b> when the window is resized, and the first click on an inactive macOS window now registers.</li>
            <li><b>More openable file types</b> &mdash; <code>.mdown</code>, <code>.mkd</code>, <code>.mkdn</code>, <code>.mdwn</code> and <code>.txt</code>.</li>
          </ul>
HTML
    ;;
  esac
}

tool_meta_desc () {
  case "$1" in
    project2excel) printf 'Convert Microsoft Project .mpp files into editable Excel workbooks — drawn Gantt chart, task data, resources, assignments and relations — on a machine that has never had Project installed.' ;;
    pdf-classifier) printf 'Classify PDFs by the real quality of their text layer and get a per-page OCR routing decision, before spending anything on OCR.' ;;
    markdown-renderer) printf 'A desktop Markdown viewer with accurate tables, KaTeX maths, a full portability check, non-destructive cleanup and self-contained HTML export.' ;;
    bakmil-metro) printf 'Next-departure times for the Bakmil to Nərimanov metro shuttle in Baku, in a web app that opens instantly and needs no account.' ;;
    apk-finder) printf 'Find, compatibility-check and install Android apps on devices with no Google Play Services — built for Chinese-market car head units, degoogled phones and custom ROMs.' ;;
    similars-and-statistics) printf 'A Lightroom Classic plugin that groups visually similar photographs, reports file-type statistics, flags corrupt HEIC files and fixes wrong capture dates.' ;;
    restore-missing-photos) printf 'A Lightroom Classic plugin that finds files matching photos the catalog reports as missing and puts them back where the catalog expects them.' ;;
    location-caption) printf 'A Lightroom Classic plugin that suggests the actual landmark a GPS-tagged photo was taken at, from OpenStreetMap data, and writes nothing until you approve it.' ;;
    geocrawler) printf 'Audit a subsurface data repository: catalog SEG-Y and LAS files, read their headers, detect coordinate systems, find duplicates, and export the result to Excel.' ;;
    segy-coordinate-security) printf 'Audit, sanitize and independently verify SEG-Y files before sharing them, replacing map coordinates with one consistent local grid while preserving line geometry.' ;;
    cassandra-risking) printf 'Geological chance-of-success risking for exploration prospects, keeping the evidence and reviewer context attached to every number.' ;;
  esac
}

tool_lede () {
  case "$1" in
    project2excel) printf 'Opens a Microsoft Project <code>.mpp</code> file and writes a real Excel workbook — a drawn Gantt chart, the task data behind it, resources, assignments and relationships — on a machine that has never had Project installed.' ;;
    pdf-classifier) printf 'Looks at what is actually in a PDF&rsquo;s text layer, page by page, and tells you which pages need OCR and which do not. It performs no OCR itself, and it has no opinion about which OCR engine you use next.' ;;
    markdown-renderer) printf 'A Markdown viewer that renders what you will actually publish — real tables, KaTeX maths, GFM alerts — and then tells you which parts of your document are likely to break somewhere else.' ;;
    bakmil-metro) printf 'Tells you when the next shuttle leaves, and nothing else. No account, no install, no tracking — open it at the platform and the answer is already on screen.' ;;
    apk-finder) printf 'Most APK finders assume Google Play Services exist. This one assumes nothing: it detects what your device actually has, then tells you honestly whether an app will work on it and what you would lose if it does not.' ;;
    similars-and-statistics) printf 'Four jobs a large Lightroom catalog eventually needs doing, in one plugin: find the photographs you already have twice, count what file types you are actually holding, catch HEIC files that have gone bad, and fix capture dates that disagree with the folder they sit in.' ;;
    restore-missing-photos) printf 'Lightroom marks a photo as missing when the file moves out from under it. This searches the folders you point it at for files matching those photos and puts them back at the paths the catalog still expects.' ;;
    location-caption) printf 'City names are rarely the answer. This reads a photograph&rsquo;s GPS position, asks OpenStreetMap what is actually there, and proposes the specific landmark — the temple, not the province — for you to approve before anything is written.' ;;
    geocrawler) printf 'Crawls a folder tree of subsurface data and tells you what is in it: which files are seismic, which are well logs, what their headers claim, which are duplicates, and which claims should not be trusted.' ;;
    segy-coordinate-security) printf 'Prepares SEG-Y data for a vendor or a data room by removing direct georeferencing while preserving line geometry, then verifies the result independently — and is careful about what it does and does not promise.' ;;
    cassandra-risking) printf 'Calculates geological chance of success and keeps a snapshot of the evidence each number was based on, so a risking decision can still be explained — and defended — months later.' ;;
  esac
}

tool_prose () {
case "$1" in
project2excel) cat <<'HTML'
<h2>What it is for</h2>
<p>A Microsoft Project schedule is usually read by far more people than ever author one. The planner has Project; the engineers, the commercial team, the client and the subcontractors mostly do not, and buying each of them a licence to look at a Gantt chart is not a serious proposal. What those readers actually want is the schedule in the tool they already use all day.</p>
<p>Project2Excel opens an <code>.mpp</code> file and writes a real Excel workbook — not a screenshot of a chart, and not a flat CSV dump that loses the hierarchy. The result is something a reader can filter, sort, comment on and paste into a report, on a machine that has never had Project installed.</p>

<h2>What it produces</h2>
<p>One workbook, with the schedule split across the sheets you would otherwise build by hand:</p>
<ul>
  <li><strong>Gantt View</strong> — task hierarchy, durations, dates, progress and resources, with calendar-aware shading for nonworking days, milestone markers, critical-task highlighting, and thin FS/SS/FF/SF dependency connectors drawn behind the bars.</li>
  <li><strong>Task Data</strong> — the filterable source data, with real task IDs, readable dependency notation, and baseline, actual, constraint and calendar fields.</li>
  <li><strong>Resources</strong> — the project&rsquo;s resource catalog, with rate, calendar and contact fields.</li>
  <li><strong>Assignments</strong> — task-to-resource assignments with resolved names, units, work and cost.</li>
  <li><strong>Relations</strong> — one row per relationship, with endpoint IDs and names, type, lag and lag units.</li>
</ul>
<p>The Gantt is drawn with Excel&rsquo;s own primitives rather than pasted as a picture, so it stays legible when someone widens a column or changes the timescale.</p>

<h2>How it reads the file</h2>
<p>The <code>.mpp</code> format is not documented for outside use, so the conversion is done by MPXJ, a mature open-source Java library that reads Project files directly. That means a Java runtime is involved — but a trimmed one ships inside the application, along with the reader itself. There is no system-wide Java to install, no <code>JAVA_HOME</code> to set, and no version conflict with anything else on the machine.</p>

<h2>Two ways to run it</h2>
<p>A desktop application for Windows and macOS covers the ordinary case: pick a file, choose a timescale, write the workbook. A command-line interface covers the rest — batch conversion, scheduled jobs, or a pipeline step — with switches for output path, timescale and overwrite behaviour.</p>

<h2>Installing it</h2>
<p>The Windows installer defaults to a per-user install that needs no administrator rights, which matters on a locked-down corporate machine; an administrator can still choose an all-users install, and both modes can be driven unattended. On macOS the app is dragged out of its disk image in the usual way. The macOS build is checked at package time to confirm nothing in it links outside the bundle or the system frameworks.</p>

<h2>What it does not do</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Being a Project editor.</strong> The conversion runs one way. Nothing you change in the workbook travels back to the <code>.mpp</code>, and the tool never modifies the file it read.</p>
  <p><strong>Uploading your schedule to convert it.</strong> Everything happens on your machine, with a bundled reader and a bundled runtime. Project plans carry budgets, staffing and delivery dates; none of that needs to leave the desktop to become a spreadsheet.</p>
</div>
HTML
;;
markdown-renderer) cat <<'HTML'
<h2>What it is for</h2>
<p>Markdown is portable in theory and inconsistent in practice. A document that looks right in one editor loses its tables in a wiki, drops its footnotes on a static site, or renders its maths as literal dollar signs somewhere else. The usual way to discover this is to publish and find out.</p>
<p>Markdown Renderer is a viewer that shows the document accurately, and then goes a step further: it examines the source and reports what is likely to break elsewhere, and why. The aim is not just to display the output, but to explain the difference between what you wrote and what another renderer will make of it.</p>

<h2>Reading a document</h2>
<p>Full Markdown rendering through markdown-it-py, with intelligent table handling — Auto, Markdown or HTML render modes, and per-table diagnostics explaining which was chosen and why. KaTeX renders both inline and display maths. A sidebar table of contents scrolls to any heading, live search highlights matches as you type, zoom runs from 50 to 200% and persists between sessions, and local images resolve properly. Parser profiles — Strict, GFM, Document — change how the backend actually parses, not merely how it complains.</p>

<h2>The full check</h2>
<p>Beyond preview, the app can audit a document for the things that make Markdown travel badly:</p>
<ul>
  <li><strong>Flavor and portability</strong> — superscripts, footnotes, task lists, strikethrough, definition lists, admonitions, custom heading IDs, TeX-style maths delimiters.</li>
  <li><strong>Structure</strong> — multiple H1s, repeated heading text, skipped heading levels, heading markers missing their space.</li>
  <li><strong>Lists</strong> — suspicious indentation, mixed markers, missing spaces, and Unicode bullets that look like lists but are not.</li>
  <li><strong>Links and footnotes</strong> — missing, duplicate and unused definitions; malformed inline link and image syntax.</li>
  <li><strong>Code and malformed source</strong> — unclosed fences, and the other cases where one broken block quietly swallows the rest of the file.</li>
  <li><strong>Tables</strong> — raw HTML tables, suspicious pipe structure, and tables complex enough to require HTML rather than a portable pipe form.</li>
  <li><strong>Encoding and copied text</strong> — invisible Unicode characters and the wrapping patterns that PDF, OCR, email and chat-copy workflows leave behind.</li>
</ul>

<h2>Cleanup that does not overwrite anything</h2>
<p>Cleanup runs in two layers. A safe pass always runs, reparsing the document and writing it back in a consistent layout for headings, lists, blocks and tables. On top of that, a conservative set of optional fixes maps directly to diagnostics the check already reported — heading markers missing a space, list markers missing a space, fake Unicode bullets, invisible spacing characters.</p>
<p>Crucially, cleanup does not touch the file on disk. It updates the preview and the in-memory document so you can read the result first, with a summary in the lower pane and a saveable cleanup log. If you want to keep it, you export it. If cleanup or repair changes exist only in memory, the app asks before you open another document or quit.</p>

<h2>Guardrails</h2>
<p>Large documents raise a warning, expensive automatic resource checks are skipped, and files above the safe open limit are blocked rather than allowed to hang the window. Raw HTML in the source is sanitized before both preview and HTML export, so a document from somewhere else cannot execute anything.</p>

<h2>What it does not do</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Being a Markdown editor.</strong> There is a source edit mode with formatting buttons and save-back, but the app is built around reading and checking a document rather than authoring one from scratch.</p>
  <p><strong>Guessing silently.</strong> Where a table or a construct is ambiguous, the diagnostics panel says which interpretation was used and what made it choose that — so a surprising render is explainable rather than mysterious.</p>
</div>
HTML
;;
bakmil-metro) cat <<'HTML'
<h2>What it is for</h2>
<p>The Bakmil ↔ Nərimanov shuttle runs on its own timetable, and the question anyone standing on the platform has is the same one every time: when does the next one leave? That question deserves an answer in one screen, immediately, on a phone with poor reception — not an app to install, an account to make, or a page that loads a carousel first.</p>
<p>Open it and the next departures are already on screen. That is the entire product.</p>

<h2>How the schedule stays current</h2>
<p>The timetable is refreshed automatically once a day from Baku Metro&rsquo;s own scheduling endpoint. That endpoint is undocumented and unofficial — it was found by inspecting the operator&rsquo;s own site, not published as an API — which shapes how the update is handled.</p>
<p>If the source ever stops returning valid data, the job does not publish what it got. The previously published schedule is left exactly as it was and the failure is recorded separately, so the app keeps showing the last known-good timetable rather than an empty screen or invented times. Stale but true beats fresh and wrong when someone is deciding whether to run for a train.</p>

<h2>Built small on purpose</h2>
<p>Plain HTML, CSS and JavaScript, with no framework and no build step. The update script has no third-party dependencies at all — it runs on Node&rsquo;s built-ins — so there is no dependency tree to audit and nothing to go stale in the background. It installs as a progressive web app if you want it on a home screen, and works as an ordinary page if you do not.</p>

<h2>What it does not do</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Asking who you are.</strong> No account, no login, no analytics, no tracking. The app does not know or care who is looking at it.</p>
  <p><strong>Claiming to be official.</strong> Bakı Metropoliteni is not affiliated with this project and does not endorse it. The schedule comes from their data; the app carries that disclaimer in plain sight rather than implying an endorsement it does not have.</p>
</div>
HTML
;;
apk-finder) cat <<'HTML'
<h2>What it is for</h2>
<p>Many Chinese-market vehicles ship an Android-based infotainment system with no Google Play Services, no Play Store, and no consistent alternative. The same is true of degoogled phones and plenty of custom ROMs. On hardware like that, the ordinary way of getting an app — open the Play Store — simply does not exist, and the tools that fill the gap almost all assume Google is present anyway. They either misbehave, or they hedge every answer into uselessness.</p>
<p>APK Finder is built the other way round: assume nothing about Google, detect what is really on the device, and report compatibility — and any functionality you would lose — specifically rather than vaguely.</p>

<h2>It profiles the device first</h2>
<p>On first launch it profiles the hardware: Android version, CPU architecture, display, hardware features, and crucially which service framework is actually present — Google Play Services, the Play Store, microG, Huawei Mobile Services, or none at all. That profile is stored locally, can be re-detected on demand, and can be exported as a diagnostic to clipboard or file. Every compatibility answer afterwards is measured against that real device rather than an assumed one.</p>
<p>On supported head units it will also make a best-effort attempt to identify the vehicle model and infotainment software version, and show it at the top of the app. When it cannot, it stays silent and blocks nothing.</p>

<h2>Searching several sources at once</h2>
<p>It searches F-Droid, IzzyOnDroid and APKPure together, merging results for the same app into a single card so you compare versions rather than hunt across three interfaces. Each source can be switched off independently in Settings if you would rather not use it.</p>

<h2>Compatibility, checked twice</h2>
<p>The first check is <strong>preliminary</strong>, built from repository metadata and shown before you download anything, so an obviously incompatible build can be ruled out immediately. The second is <strong>authoritative</strong>, run against the actual downloaded APK and checked against your real Android version, CPU architecture, hardware features and requested permissions.</p>

<h2>The Google-dependency report</h2>
<p>This is the part built specifically for devices without Google. A downloaded APK is inspected for Play Services and Firebase usage, and what it finds is classified rather than lumped together — Maps, Sign-In, Play Integrity, Billing, Push Messaging, Analytics, Location, Cast. Each one comes with a plain-English explanation of what will actually happen if Google services are absent. &ldquo;This app uses Google Sign-In, so you will not be able to log in&rdquo; is a usable answer; &ldquo;this app may not work&rdquo; is not.</p>

<h2>Downloading and installing</h2>
<p>Downloads stream with progress and can be cancelled, and every file is verified by SHA-256 against the hash the repository published. Installation hands off to Android&rsquo;s standard package installer — no root, no silent install — and reports the real completion status rather than assuming success.</p>

<h2>Built for a dashboard</h2>
<p>Content is centred and width-capped instead of stretching across a very wide landscape display, and touch targets are larger than Android&rsquo;s defaults. This is an app used at arm&rsquo;s length, on a screen bolted into a dashboard, often without anything resembling a precise pointer.</p>

<h2>Non-negotiables</h2>
<div class="compare">
  <p class="compare-label">By design</p>
  <p><strong>No Google anywhere in its own dependency graph.</strong> No Play Services, Firebase, Sign-In, Maps SDK, Play Billing, Play Integrity or Analytics. A tool for Google-free devices that itself depends on Google would be a contradiction.</p>
  <p><strong>Nothing is transmitted.</strong> No telemetry, no analytics, no ads. All compatibility analysis and APK inspection run entirely on the device — nothing about your hardware, your downloads or your search terms goes anywhere.</p>
  <p><strong>Warnings cannot be globally silenced.</strong> Google-dependency and signature-mismatch warnings can only be overridden per download, deliberately, by you. There is no setting that turns them all off and lets you forget.</p>
</div>
HTML
;;
pdf-classifier) cat <<'HTML'
<h2>What it is for</h2>
<p>OCR is the expensive step in any document pipeline — whether the cost is per-page cloud pricing, GPU time, or an afternoon of someone&rsquo;s attention. In most real archives a large share of the PDFs already carry a perfectly good text layer and need no OCR at all, while others carry one that looks present and is quietly useless. Sorting those apart by hand does not scale, and guessing wrong is expensive in both directions: OCR everything and you pay for work already done; trust the text layer blindly and you extract garbage.</p>
<p>PDF Classifier is the step before the expensive step. Point it at a file or a folder, and it tells you, page by page, which pages need OCR and which do not — then gets out of the way.</p>

<h2>How it decides</h2>
<p>&ldquo;Does this PDF have a text layer?&rdquo; is the wrong question — plenty of PDFs have one that is unusable. Each page is judged on the things that actually predict whether extraction will work:</p>
<ul>
  <li><strong>Text density</strong>, measured against the space the page actually occupies.</li>
  <li><strong>Artifacts</strong> — <code>(cid:123)</code> sequences, replacement characters, mojibake from a bad encoding.</li>
  <li><strong>Script consistency</strong>, so a page that drifts between alphabets is caught.</li>
  <li><strong>Bounding-box coverage</strong> and <strong>reading order</strong>, which is where a technically-present text layer usually fails.</li>
</ul>
<p>The result is a per-page and per-document verdict, and a <strong>recommended processing mode</strong> that downstream tooling can route on directly, rather than a coarse yes-or-no flag. A document is rarely uniformly good or bad, and the per-page verdict is what lets you OCR six pages of a two-hundred-page report instead of all of it.</p>

<h2>Where the verdict lives</h2>
<p>By default the summary is written back into the PDF itself as namespaced XMP metadata, with a compact DocInfo fallback and roundtrip verification. That makes the file self-describing: whatever moves it next can read the decision without a companion file to lose or a database to query. Re-embedding replaces the previous block in place rather than leaving stale classification data beside it.</p>
<p>Embedded metadata is checked against a content fingerprint before it is trusted, so a PDF that was re-saved after classification is never silently treated as already classified — the one failure mode that would quietly corrupt a routing decision.</p>
<p>Alongside that, every scan writes run-level JSONL and CSV reports and records itself in a local SQLite history that survives deleting or moving a run&rsquo;s output folder. Sidecar JSON is available but off by default, and when enabled its location is explicit rather than assumed. CSV exports carry a UTF-8 byte-order mark, so Excel renders Cyrillic and Azerbaijani text instead of guessing the system codepage.</p>

<h2>The desktop application</h2>
<p>The app opens by asking which of two jobs you are doing, before the database is touched at all.</p>
<p><strong>The regular application</strong> has seven tabs. <em>Dashboard</em> shows all-time and last-run statistics with clickable drilldowns straight into filtered results. <em>Scan</em> runs a folder, recursively, with excludes. <em>Results</em> filters, searches, exports and offers a context menu, with per-row columns for classification source, completeness and sidecar write status, and tinting for dry runs. <em>PDF Detail</em> gives a per-page table, a page preview, a provenance summary, and a three-way human-review override that persists. <em>Metadata</em>, <em>Settings</em> and <em>Logs</em> complete it, with settings separating appearance and persistence from classification thresholds. Single-file actions run on a background thread, so the window never freezes mid-scan.</p>
<p><strong>Quick One-File Classification</strong> does exactly one PDF with no database involved — no connection, no migration, no run recorded, no effect on the dashboard or history. It reuses the same classifier, the same review interface and the same metadata schema as the full workflow, and stamps its output so it stays import-ready if you later decide it belongs in the record.</p>

<h2>Also a command line and a library</h2>
<p>Everything the interface does is available from the CLI — classify one file, scan a tree, read, verify or embed metadata, set a human override — and a small Python API exposes the routing decision to downstream OCR tools directly, so the classifier can sit inside a pipeline rather than in front of a person.</p>

<h2>Languages</h2>
<p>Language reporting is deliberately narrow. English, Russian and Azerbaijani are reported as document languages; mixed documents among them are expected rather than penalised, and formula symbols are treated as scientific notation rather than as language text. Other scripts are used as artifact and unsupported-script diagnostics, but are never claimed as supported OCR routes — a claim the tool cannot honestly make is worse than no claim.</p>

<h2>What it deliberately does not do</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Bundling an OCR engine and an opinion.</strong> It performs no OCR and depends on no OCR engine — not Tesseract, PaddleOCR, MinerU or anything else. It produces a routing decision; you keep the choice of what acts on it, and you can change that choice later without reclassifying.</p>
  <p><strong>Rewriting your source files without being asked.</strong> Metadata embedding is on by default in the desktop app&rsquo;s settings and off by default on the CLI&rsquo;s scan command unless you explicitly ask for it. Nothing else in a source PDF is touched.</p>
</div>
HTML
;;
similars-and-statistics) cat <<'HTML'
<h2>What it is for</h2>
<p>A photo library that has been running for years accumulates a specific set of problems. The same shot exists three times because it was imported from three cards. Nobody knows how much of the catalog is JPEG and how much is raw. A batch of HEIC files copied off a phone has gone quietly bad. And a folder of pictures from 2019 has capture dates in 1970 because a camera lost its battery.</p>
<p>None of these is hard to fix once you can see it. All of them are invisible until something surfaces them. This plugin adds four tools to Lightroom Classic that do exactly that, under <strong>Library &rsaquo; Plug-in Extras</strong>.</p>

<h2>Find similar photographs</h2>
<p>Groups visually similar images in the current selection using HSV colour-histogram comparison with a structural-correlation check on top. That combination matters: a histogram alone will happily group two unrelated sunsets, and structure alone is slow and brittle. Together they find the burst of near-identical frames you meant to cull, and the same photograph imported twice at different sizes.</p>
<p>Results are offered back as Lightroom collections, so you review and delete inside Lightroom with everything you normally have to hand — you are never asked to make deletion decisions inside a plugin dialog.</p>

<h2>File-type statistics</h2>
<p>Reports what the selection actually contains, by file type. Useful before a migration, before buying storage, or when deciding whether a raw-to-DNG conversion is worth the afternoon it will cost.</p>

<h2>Corrupt HEIC detection</h2>
<p>HEIC files fail in a particularly unhelpful way: the catalog still shows a thumbnail, and the underlying file is unreadable. The plugin validates HEIC containers directly and flags the ones that have gone bad, so you find out while the originals may still exist elsewhere rather than years later.</p>

<h2>Capture-date repair</h2>
<p>Flags photographs whose capture year disagrees with the folder they are filed in — the usual signature of a camera clock that reset. You tell the plugin what your library&rsquo;s root folder is called, and it works out each photo&rsquo;s expected year from its path.</p>

<h2>How it runs</h2>
<p>The comparison work is done by small native helpers bundled inside the plugin, not in Lua — image comparison across thousands of files is not something a scripting layer should attempt. The libraries they depend on ship inside the plugin folder with their load paths rewritten, so there is nothing to install alongside it and no Homebrew dependency on the machine that runs it.</p>

<h2>What it does not do</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Deleting anything.</strong> Every tool reports and organises. Removing a photograph stays a decision you make in Lightroom, with the photographs in front of you.</p>
  <p><strong>Scanning your whole catalog uninvited.</strong> All four tools work on the current selection and nothing else.</p>
</div>
HTML
;;
restore-missing-photos) cat <<'HTML'
<h2>What it is for</h2>
<p>Lightroom records where every photograph lives. Move the files with Finder, restore from a backup to a different path, or swap a drive letter, and the catalog is left pointing at places nothing exists — every affected photo marked missing, all its edits and metadata intact but detached from any actual pixels.</p>
<p>The files usually still exist. They are on the backup drive, or the NAS, or the old disk in a drawer. What is missing is the correspondence between the catalog&rsquo;s expected path and where the file actually sits now. This plugin rebuilds that correspondence and, if you want, copies the files back to the paths the catalog already expects — so no relinking is needed afterwards.</p>

<h2>The workflow</h2>
<p>Use Lightroom&rsquo;s own <strong>Find All Missing Photos</strong>, select what you want to recover, and run the plugin. It shows the paths the catalog is expecting, and optionally saves them to a text file for reference. Then you point it at a folder that might contain replacements — a backup drive, a NAS share, an old export — and it scans.</p>
<p>The selection is captured when the workflow starts and held for its whole duration, so it survives you clicking around in Lightroom mid-scan. It is discarded when the workflow ends.</p>

<h2>Indexing, and why it counts rather than estimates</h2>
<p>Indexing walks the chosen folder once. There is deliberately no preliminary counting pass, because counting the tree takes about as long as indexing it and would nearly double the wait for a progress bar. So the dialog shows a running count — <em>Indexing files… (1,250 indexed)</em> — rather than a percentage it would have to invent. It can be cancelled, and a cancelled index is discarded rather than half-used.</p>
<p>Each folder&rsquo;s index is kept in memory for the rest of the Lightroom session. Scanning the same share again — including on a later <em>Search Another Folder</em> pass — reuses it instead of walking the tree a second time. Nothing is written to disk, and a plugin reload or a Lightroom restart always forces a fresh scan.</p>
<p>Because a reused index describes the folder as it was earlier, every match is verified to still exist immediately before it is accepted. One that has since moved is dropped from the index so it is not offered again, and the results report how many were caught that way.</p>

<h2>When something goes wrong</h2>
<p>If the source disk or NAS share disconnects part-way through, you get an explicit <strong>Indexing Failed</strong> error with a path to the error log — not a generic Lightroom task failure, and not a results screen full of &ldquo;not found&rdquo; that looks like a completed scan. An incomplete index is never treated as a finished one. That distinction is the difference between retrying a scan and wrongly concluding your backup does not have the files.</p>

<h2>Duplicates</h2>
<p>When several files match one missing photo, you choose how it behaves: <strong>manual review</strong>, where you decide each case, or <strong>first match</strong>, where it takes the first and keeps moving. The active mode is shown in the folder-picker title before every scan, so it is never a surprise, and it can be changed from the plugin&rsquo;s menu or from Plug-in Manager — both read and write the same setting.</p>

<h2>What it does not do</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Touching your catalog.</strong> The plugin copies files into place. It does not rewrite catalog paths, edit metadata, or modify the originals it finds.</p>
  <p><strong>Searching anything you did not point it at.</strong> It reads the folders you choose and the photos you selected, and nothing else.</p>
</div>
HTML
;;
location-caption) cat <<'HTML'
<h2>What it is for</h2>
<p>A GPS-tagged photograph knows its coordinates, and reverse geocoding will happily turn those into a city. But &ldquo;Siem Reap&rdquo; is not what the picture is of — the picture is of Bayon Temple. The useful name is almost always more specific than the administrative one, and it is exactly the name that is hardest to remember six months later when you are captioning a trip.</p>
<p>This plugin reads a photograph&rsquo;s position, asks OpenStreetMap what is actually at that spot, and proposes the specific landmark — temple, monument, museum, hotel, archaeological site, park — for you to approve.</p>

<h2>How it decides</h2>
<p>Photographs are grouped into coordinate clusters first, so a series shot around one site is looked up once rather than once per frame. Everything within the configured radius — 500 m by default — is considered together, then ranked so that a specific landmark outranks the complex containing it, which outranks the surrounding city, <em>when the evidence supports it</em>. That last clause matters: the ranking is evidence-led, so an ambiguous position produces an honest set of candidates rather than a confident wrong answer.</p>

<h2>Nothing is written until you approve it</h2>
<p>Every suggestion goes through a review dialog. Accept it, pick a different candidate, edit the text yourself, or exclude the photograph entirely. Only then is anything written.</p>
<p>What gets written is deliberately narrow: the approved place goes to Lightroom&rsquo;s <strong>Sublocation</strong> field, and you choose whether it replaces the existing value or is appended to it. Caption, City, State/Province, Country, ISO country code, title, keywords, copyright, capture time and GPS are all left alone. Nothing is written to your original files or to XMP sidecars.</p>

<h2>What leaves your machine</h2>
<p>Before the first lookup, the plugin shows a one-time disclosure. GPS coordinates from the selected photographs are sent to the configured geocoding service to retrieve place names — that is the whole point of the tool and it cannot work otherwise. Image files, thumbnails, filenames, captions and your identity are never sent. Requests are throttled and cached to stay within the public services&rsquo; usage policies.</p>

<h2>Where it currently stands</h2>
<p>Everything testable outside a running Lightroom process is implemented and unit tested — candidate ranking, metadata formatting, caching, provider clients, coordinate grouping — including tests against real captured responses from the live geocoding services. The modules that talk to Lightroom itself are written against the documented, long-stable Lightroom Classic SDK, but have not been fully exercised inside Lightroom.</p>
<p>That is why this is listed as a beta, and why the honest advice is to run it against a disposable test catalog first. The plugin never touches anything beyond your current selection either way, but a plugin that writes metadata deserves to earn trust on a catalog you can throw away.</p>

<h2>What it does not do</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Captioning your library unattended.</strong> There is no bulk mode that writes without review. Every photograph is approved individually, because a plausible wrong landmark is worse than no landmark.</p>
  <p><strong>Sending your photographs anywhere.</strong> Coordinates go out. Images never do.</p>
</div>
HTML
;;
geocrawler) cat <<'HTML'
<h2>What it is for</h2>
<p>Exploration data accumulates faster than anyone catalogs it. A project folder inherited from a partner, a drive returned by a contractor, or twenty years of a company&rsquo;s own work all arrive as the same thing: a file tree nobody can characterise without opening it. How much of this is seismic? How many wells? Is this the same survey as that one, under a different name? Which of these files claim a coordinate system, and should we believe them?</p>
<p>Geocrawler answers those questions by reading the data rather than the folder names. It crawls the tree, categorises what it finds, opens the headers, and produces a report you can hand to someone else.</p>

<h2>What it reads</h2>
<ul>
  <li><strong>SEG-Y</strong> — binary and textual headers, geometry, survey metadata, and the byte layouts that vary between vendors more than the standard suggests they should.</li>
  <li><strong>LAS well logs</strong> — curves, headers and well identification, with format and status reported separately so an unsupported LAS 3.0 file is distinguishable from a supported file that failed to read.</li>
  <li><strong>Coordinate reference systems</strong> — detected from the data, with EPSG codes and project context where they can be established.</li>
</ul>

<h2>Duplicates</h2>
<p>Duplicate detection works at file level and at folder level. The folder-level check is the one that earns its keep: it is common to find the same survey delivered twice into differently named directories, and comparing content rather than names is what surfaces it. That is usually the single largest reclaimable chunk of a repository.</p>

<h2>What comes out</h2>
<p>A PySide6 desktop application for reviewing results interactively, and exports for everyone who was not at the screen: Excel workbooks for stakeholder review and handoff, and Markdown reports for quick documentation. The catalog data underneath supports ongoing data management rather than being a one-off summary.</p>

<h2>Why it is careful about what it claims</h2>
<p>A header is an assertion, not a fact. Files routinely carry coordinate systems that were never correct, byte layouts that do not match the standard they name, and survey names that disagree with their contents. Geocrawler reports what a file claims, marks what it inferred, and distinguishes &ldquo;this format is not supported&rdquo; from &ldquo;this file failed to read&rdquo; — because those lead to completely different next actions, and conflating them wastes an afternoon.</p>

<h2>What it does not do</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Interpreting your data.</strong> It is an inventory and quality tool. It tells you what you have and what is questionable about it; it does not process seismic or interpret logs.</p>
  <p><strong>Moving or deleting anything.</strong> The crawl is read-only. Acting on a duplicate report stays a human decision with a human&rsquo;s knowledge of which copy is authoritative.</p>
</div>
HTML
;;
segy-coordinate-security) cat <<'HTML'
<h2>What it is for</h2>
<p>Seismic data has to be shared — with a processing vendor, a farm-in partner, a data room — and the coordinates in it are frequently the most sensitive thing it carries. Where a survey was shot can reveal an exploration position long before anyone wants that known. But stripping the coordinates outright breaks the data: line geometry, relative positions and bin topology all have to survive, or what you shipped is no longer usable seismic.</p>
<p>This tool removes direct georeferencing while preserving the geometry, applying one consistent local-grid transformation across a whole delivery set — then independently verifies the result before you hand it over.</p>

<h2>Three steps, in this order</h2>
<p><strong>Audit</strong> reads every trace by default and examines all three standard coordinate pairs, the scalars, the units, and both the primary and extended textual headers. A quick mode exists for exploration but deliberately cannot be used to build a plan — a sanitization decision should not rest on a sample.</p>
<p><strong>Plan</strong> produces one reviewable transformation for the whole dataset: rotation, scale, reflection and target origin. Every populated field, whether selected or excluded, is checked against the scalar before the plan is written, so a magnitude that cannot be re-encoded is rejected up front rather than surfacing as an overflow mid-sanitize. Excluding a field the audit flagged as genuinely georeferenced requires you to acknowledge that explicitly.</p>
<p><strong>Sanitize</strong> writes copies. Inputs are never modified and existing outputs are never overwritten. The whole set is written to a staging directory, every file is reopened and checked, and the result is promoted atomically only once all of them succeed — so an interrupted run cannot leave a half-sanitized delivery that looks finished.</p>
<p><strong>Verify</strong> then checks the output independently, and can also be pointed at a delivery someone else produced, on its own terms.</p>

<h2>What is preserved, and what is replaced</h2>
<p>Direct map coordinates in the standard CDP, source and receiver header locations are replaced. Binary headers, seismic samples, trace order, inline and crossline words and bin topology are left unchanged, so the output still loads as seismic. Textual headers are replaced with a controlled functional header that declares the preserved inline/crossline bytes, the transformed X/Y bytes, the scalar, the units and the sample layout — and states plainly that the local grid has no external reference.</p>
<p>Vendor-specific or duplicated coordinates in nonstandard header bytes are not rewritten automatically. They are reported for review, and a reviewed mapping can be declared in the plan so it is transformed along with the standard fields, restricted to a fixed set of safe offsets.</p>

<h2>The honest security boundary</h2>
<p>This is the part worth reading before relying on the tool. Preserved geometry remains a recognisable fingerprint. If someone already holds another copy of the same survey, the shape of the acquisition can be matched against it. The tool therefore reports <strong>no direct georeferencing detected</strong> — never that re-identification is impossible, because that would be a claim it cannot support.</p>
<p>The audit, the plan and the internal manifest disclose source paths, coordinate evidence and the transformation itself. They are working files and must stay out of the external delivery.</p>

<h2>The desktop application</h2>
<p>Audit, Transformation Plan, Sanitize, Verify, Verify Existing, Geometry QA, 3D Survey QA and Settings screens, with Verify Existing sitting outside the pipeline so a third-party file can be checked independently. Geometry QA displays one line or every verified line and fits the map to the loaded geometry. A bundled, fully offline Azerbaijan and Caspian Sea basemap outline is available as a background that needs no network at all, and public map tiles stay disabled until explicitly allowed — you should not have to send survey geometry to a tile server to look at it. A saved plan can be reloaded to reuse its rotation, scale and scalar when adding more lines or a 3D volume to an existing batch.</p>

<h2>What it does not do</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Promising anonymity.</strong> It removes direct georeferencing and says so precisely. It does not claim the result cannot be matched to a survey by someone who already has one.</p>
  <p><strong>Touching your originals.</strong> Sanitize reads inputs and writes copies. It never modifies a source file and never overwrites an existing output.</p>
</div>
HTML
;;
cassandra-risking) cat <<'HTML'
<h2>What it is for</h2>
<p>A prospect&rsquo;s chance of success is a number that gets quoted in meetings for years and explained approximately once. By the time anyone asks why the seal risk was 0.6, the spreadsheet has been copied twice, the person who set it has moved on, and the reasoning exists only as a recollection. The number survives; the evidence behind it does not.</p>
<p>Cassandra structures geological risking so the evidence stays attached. Each assessment records the interpretation, the data it rests on, and the reviewer context — and a published scenario freezes all of it together, so the number can still be defended months later.</p>

<h2>Geological chance of success, and only that</h2>
<p>The scope is deliberately narrow. Cassandra calculates geological Pg and refuses to mix it with economics — no EMV, no recoverable volumes, no development chance. Those are real questions, but blending them into one figure is how a geological risk becomes an unfalsifiable commercial one. Keeping them apart is what lets a geologist defend the part they are actually responsible for.</p>

<h2>How an assessment is structured</h2>
<p>The classic components — <strong>Play, Source, Charge, Reservoir, Seal</strong> and <strong>Trap</strong> — each get their own assessment tab, with shared play risk kept explicitly separate from prospect and segment risk. That separation runs through the whole model:</p>
<ul>
  <li><strong>Play</strong> — the shared geological chance for the selected play: working petroleum system, regional seal preservation, migration fairway.</li>
  <li><strong>Segment</strong> — the local interpretation currently selected, such as one mapped closure.</li>
  <li><strong>Prospect</strong> — a roll-up of stored segment results within the active play, handling single- and multi-segment prospects.</li>
  <li><strong>Cross-play</strong> — a review layer across plays for the same prospect, covering independent plays, overlapping plays and alternative concepts.</li>
</ul>

<h2>The evidence base</h2>
<p>Every geological hypothesis can carry attached data and evidence alongside the judgment itself, with reviewer comments in the same place. Both judgment-led and evidence-native workflows are supported, because real assessments are a mix: some components rest on a measurement, others on an experienced opinion, and pretending otherwise makes the record less honest rather than more rigorous. Several datasets of the same type can coexist against one hypothesis, each labelled, so two seismic interpretations do not silently overwrite one another.</p>

<h2>DHI, kept separate</h2>
<p>Direct hydrocarbon indicators are handled as an explicit likelihood-ratio update on top of the geological assessment, rather than folded invisibly into a component. You can see what the base geological case was and what the DHI did to it — which is the only way a reviewer can disagree with one without discarding the other.</p>

<h2>Publishing and reopening</h2>
<p>Before a scenario is frozen, the app checks circulation and publish readiness. A published scenario becomes read-only and keeps its reproducibility metadata and review context, so the snapshot is genuinely a snapshot. Reopening it creates a new draft rather than editing the published record — the earlier decision stays intact and quotable, and the revision is visibly a revision.</p>
<p>Exports produce a risk narrative with that metadata attached, rather than a bare number.</p>

<h2>What it does not do</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Replacing geological interpretation with automation.</strong> The application structures, records and calculates. The interpretation is the geologist&rsquo;s, and the tool is designed to make that authorship explicit rather than to obscure it behind a model.</p>
  <p><strong>Reaching for a server.</strong> This release is a desktop application working against local project files. It does not sync, and it does not offer a portfolio aggregation workflow.</p>
</div>
HTML
;;
esac
}

# --- category page copy ------------------------------------------------------
cat_head () {  # category -> "h1|intro|meta"
case "$1" in
  Business) printf '%s' 'Reporting and document work, <span class="hl">without the busywork.</span>|Three applications for the repetitive middle of office work: getting a schedule out of the tool that authored it, deciding which documents need expensive processing, and reading long technical Markdown without surprises.|Project2Excel, PDF Classifier and Markdown Renderer: schedule conversion, PDF routing and Markdown tooling from Bluebonnet Studios.' ;;
  "Web &amp; Mobile") printf '%s' 'Away from the desk, <span class="hl">and asking nothing of you.</span>|Two applications for hardware a desktop tool never reaches — a phone at a metro platform, and an Android head unit with no Google Play Services. Both answer their question without an account, and neither reports anything back.|Bakmil Metro Schedule and APK Finder: a Baku metro shuttle web app, and a Google-independent Android app finder for car head units.' ;;
  Lightroom) printf '%s' 'The catalog chores <span class="hl">nobody wants to do twice.</span>|Three plugins for Lightroom Classic that take on the unglamorous work of a large library: finding the photographs you already have twice, putting missing files back where the catalog expects them, and naming the place a photograph was actually taken.|Lightroom Classic plugins for similar-photo detection, restoring missing files, and landmark-accurate location captions.' ;;
  Geoscience) printf '%s' 'Subsurface data, <span class="hl">audited and honest.</span>|Three tools for exploration work, sharing one habit: they say what they know, mark what they inferred, and refuse to turn a guess into a fact.|Geocrawler, SEG-Y Coordinate Security and Cassandra Risking: subsurface data audit, seismic sanitization and prospect risking.' ;;
esac
}

category_page () {  # category
  local c="$1" page label h1 intro meta info
  page="$(cat_page "$c")"; label="$(cat_label "$c")"
  info="$(cat_head "$c")"
  h1="$(printf '%s' "$info" | cut -d'|' -f1)"
  intro="$(printf '%s' "$info" | cut -d'|' -f2)"
  meta="$(printf '%s' "$info" | cut -d'|' -f3)"

  page_open "$label — Bluebonnet Studios" "$meta" ""
cat <<HTML
  <div class="page-head">
    <div class="page-head-inner">
      <div>
        <p class="eyebrow">$label</p>
        <h1>$h1</h1>
        <p>$intro</p>
      </div>
      <div class="stats">
        <div><b>$(count_in "$c")</b><span>Tools</span></div>
        <div><b>$(total_tools)</b><span>In catalog</span></div>
      </div>
    </div>
  </div>

  <div class="layout">
HTML
  rail "$page"
cat <<HTML
    <main class="content" id="main">
      <section>
        <p class="section-label">$label</p>
HTML
  roster "index.html#access" "$c"
cat <<HTML
      </section>

      <section>
        <p class="section-label">Detail</p>
        <div class="details">
HTML
  printf '%s\n' "$TOOLS" | while IFS=$'\t' read -r name slug tcat ver plat stat desc lic; do
    [ "$tcat" = "$c" ] || continue
    cat <<HTML
        <article class="detail" id="$slug">
          <div class="detail-head">
            <h3><a href="$slug.html">$name</a></h3>
            $(status_chip "$stat")
          </div>
          <p>$(tool_lede "$slug")</p>
          <dl class="facts">
            <div><dt>Version</dt><dd>$ver</dd></div>
            <div><dt>Platform</dt><dd>$plat</dd></div>
            <div><dt>License</dt><dd>$(tool_license "$slug")</dd></div>
            <div><dt>Read more</dt><dd><a href="$slug.html">$slug.html</a></dd></div>
          </dl>
        </article>
HTML
  done
cat <<HTML
        </div>
      </section>
$(art "${page%.html}" tail)
    </main>
  </div>
HTML
  page_close
}

# --- about page --------------------------------------------------------------

# --- privacy policy ----------------------------------------------------------
# Published because the Microsoft Store listing needs a policy at a public URL.
# Every claim below was verified against the application sources on 2026-08-30;
# the per-application network table is the part that must stay true.
privacy_page () {
  page_open "Privacy — Bluebonnet Studios" \
    "How Bluebonnet Studios software handles your data: what stays on your device, what touches a network, and what the publisher receives." \
    ""
cat <<'HTML'
  <div class="page-head">
    <div class="page-head-inner">
      <div>
        <p class="eyebrow">Privacy policy</p>
        <h1>What stays on your machine, <span class="hl">and what does not.</span></h1>
        <p>Effective 30 August 2026. This policy covers every application listed in this
           catalog and this website itself.</p>
      </div>
    </div>
  </div>

  <div class="layout">
HTML
  rail "privacy.html"
cat <<'HTML'
    <main class="content" id="main">
      <div class="prose">
        <h2>Summary</h2>
        <p>Bluebonnet Studios software has <strong>no user accounts, no sign-in, no advertising,
           no analytics and no telemetry.</strong> The publisher receives nothing from any
           application. Your documents, photographs and data are read on your own device and are
           never uploaded.</p>
        <p><strong>No application in this catalog uses your location.</strong> None of them asks
           your device where you are, and none contains any code capable of it. Where coordinates
           appear at all, they are values already stored inside the files you chose to process —
           the position a camera recorded in a photograph, or the survey geometry inside a seismic
           file — never a reading of where you are.</p>
        <p>Four of the ten applications do contact a network, for reasons named below. None of
           them sends your file contents anywhere, and each is listed rather than glossed over.</p>

        <h2>What each application does with the network</h2>
        <table>
          <thead><tr><th>Application</th><th>Network use</th></tr></thead>
          <tbody>
            <tr><td>Project2Excel</td><td><strong>None.</strong> Runs fully offline</td></tr>
            <tr><td>Markdown Renderer</td><td><strong>None.</strong> Runs fully offline</td></tr>
            <tr><td>Similars and Photo Statistics</td><td><strong>None.</strong> Runs fully offline</td></tr>
            <tr><td>Restore Missing Photos</td><td><strong>None.</strong> Runs fully offline</td></tr>
            <tr><td>Cassandra Risking</td><td><strong>None.</strong> Runs fully offline</td></tr>
            <tr><td>PDF Classifier</td><td>Checks for application updates only</td></tr>
            <tr><td>Geocrawler</td><td>Checks for application updates only</td></tr>
            <tr><td>SEG-Y Coordinate Security</td><td>Optional map tiles, off until you enable them</td></tr>
            <tr><td>Location Caption Assistant</td><td>Looks up place names for coordinates already stored in your photographs</td></tr>
            <tr><td>Bakmil Metro Schedule</td><td>A website; loads and caches its own timetable</td></tr>
          </tbody>
        </table>

        <h2>Information stored on your device</h2>
        <p>Applications store their own settings, and most keep a rotating local diagnostic log.
           <strong>Log entries can include the file paths of documents you open and files you
           create</strong>, because that is what makes a fault report usable. Document contents
           are not written to logs. All of it stays on your device, none of it is accessible to
           the publisher, and you can delete it at any time — the application recreates what it
           needs on next launch.</p>
HTML
cat <<'HTML'
        <h2 id="project2excel">Project2Excel</h2>
        <p>This section is the policy for the Microsoft Store listing of Project2Excel.</p>
        <p>Project2Excel converts Microsoft Project <code>.mpp</code> files that you select into
           Excel <code>.xlsx</code> workbooks. Reading and conversion happen entirely on your
           device, using components bundled inside the application. <strong>It makes no network
           requests and can be used with networking disabled.</strong> Nothing you open, convert
           or save is sent anywhere.</p>
        <p>It stores the following locally, none of which leaves your device or is accessible to
           the publisher:</p>
        <ul>
          <li><strong>Settings</strong> — your export preferences and the folders last used for opening and saving, in the application's per-user application data location.</li>
          <li><strong>Diagnostic log</strong> — a rotating local log of roughly 1&nbsp;MB across up to five files, recording events such as when an export started and finished, how many tasks were exported, and any warnings. <strong>These entries include the file paths of the project files you convert and the workbooks you create.</strong> Task notes from your project files are deliberately excluded.</li>
          <li><strong>Temporary files</strong> — while reading a project file the application writes a temporary file to your system temporary folder and deletes it once conversion completes.</li>
          <li><strong>Output files</strong> — the workbooks it creates are written only where you choose.</li>
        </ul>
        <p>You can delete the settings file and the logs at any time. In the Microsoft Store
           version these files live in the application's own per-user package data folder and are
           removed when you uninstall it.</p>
        <p>The application bundles open-source components, including the MPXJ project-file
           library, a Java runtime, the Qt framework and OpenPyXL. They execute locally and
           transmit nothing. The Microsoft Store handles distribution, installation and updates
           under Microsoft's own privacy practices; the publisher receives only the aggregate
           acquisition statistics the Store provides.</p>

        <h2>The four applications that contact a network</h2>
        <h3>PDF Classifier and Geocrawler — update checks</h3>
        <p>Both can check whether a newer version exists, against a local network share first and
           a public release channel second. The check sends nothing about you or your documents.
           A downloaded package is never executed before its checksum has been verified, and
           nothing installs without your explicit confirmation.</p>

        <h3>SEG-Y Coordinate Security — optional map tiles</h3>
        <p>The geometry view can draw a background map using public OpenStreetMap tiles.
           <strong>This is off until you enable it in Settings</strong> and authorise it for the
           current view. When enabled, the tile server receives the map areas you look at, which
           necessarily indicates the region your survey covers. A bundled offline basemap outline
           is available as an alternative that needs no network at all.</p>

        <h3>Location Caption Assistant — place names for coordinates in your photographs</h3>
        <p><strong>This plug-in does not use your location, and no application in this catalog
           does.</strong> None of them asks your device where you are, and none contains any code
           capable of it.</p>
        <p>What it works with is a coordinate <em>inside the data you chose to process</em>. When
           a camera or phone records a photograph it can store the position where the picture was
           taken in the file itself. For photographs you have selected in Lightroom, the plug-in
           reads that stored coordinate from the catalog and asks two public OpenStreetMap
           services — Nominatim and Overpass — what landmarks exist at that position, so it can
           suggest "Bayon Temple" rather than "Siem Reap". It is the same act as typing a
           coordinate into a map search, on data already in your own files.</p>
        <p>Your photographs are never uploaded — only the coordinate. Nearby photographs are
           grouped so each area is looked up once rather than once per photograph. Requests
           identify the plug-in and the studio's contact address, as those services' usage
           policies require. Nominatim and Overpass are operated by the OpenStreetMap Foundation
           under their own privacy terms. Nothing is written to your catalog until you approve
           each suggestion, and photographs with no stored coordinate are skipped entirely.</p>

        <h2>This website</h2>
        <p>This site sets no cookies and runs no analytics. Three things are worth naming:</p>
        <ul>
          <li><strong>Fonts</strong> are loaded from Google Fonts, so Google receives your IP address and browser details when a page loads.</li>
          <li><strong>Hosting</strong> is GitHub Pages, so GitHub receives the same request information.</li>
          <li><strong>Your theme choice</strong> is remembered in your browser's local storage under <code>bbst-theme</code>. It never leaves your browser, and clearing site data removes it.</li>
        </ul>

        <h2>Information the publisher receives</h2>
        <p><strong>None.</strong> No usage data, no crash reports, no file contents, no file names.
           If you email support or open a GitHub discussion or issue, the publisher receives
           whatever you put in it — a GitHub discussion is public and visible to anyone.</p>

        <h2>Children</h2>
        <p>These are general-purpose professional tools. They do not knowingly collect information
           from anyone, including children.</p>

        <h2>Changes to this policy</h2>
        <p>A revised version will be published at this address with an updated effective date.</p>

        <h2>Contact</h2>
        <p>Questions about this policy: <a href="mailto:dev@bbst.us">dev@bbst.us</a></p>
      </div>
HTML
  art privacy tail
cat <<'HTML'
    </main>
  </div>
HTML
  page_close
}

about_page () {
  page_open "About — Bluebonnet Studios" \
    "Bluebonnet Studios builds small, precise tools for document workflows, photo catalogs, subsurface data and devices without Google services." \
    "about"
cat <<'HTML'
  <div class="page-head">
    <div class="page-head-inner">
      <div>
        <p class="eyebrow">About</p>
        <h1>A small studio that builds <span class="hl">specific tools.</span></h1>
        <p>Bluebonnet Studios builds software for people whose work is stuck between
           applications: a schedule trapped in the tool that authored it, a folder of PDFs that
           may or may not be readable, a photo catalog with twenty years of accumulated mess, a
           seismic dataset that has to leave the building without giving away where it came from,
           a car with an Android screen and no way to install anything on it.</p>
      </div>
    </div>
  </div>

  <div class="layout">
HTML
  rail "about.html"
cat <<'HTML'
    <main class="content" id="main">
      <div class="prose">
        <h2>How the tools are built</h2>
        <p>Most of this catalog is native desktop software — five PySide6 applications on
           Windows and macOS, and one built on Tauri. The rest goes where a desktop program
           cannot: three Lightroom Classic plugins, a web app that installs nothing, and an
           Android app for car head units with no Play Store. Whatever the platform, they open
           fast, they work offline, and they keep their data on your machine.</p>
        <ul>
          <li><strong>Nothing phones home.</strong> No telemetry, no account, no licence server.
              Where a tool touches the network at all — a map tile, an update check — it is off
              until you turn it on, and it says so.</li>
          <li><strong>One version number per application</strong>, held in a single source and read
              back at runtime, so the number in the About dialog is the number that was built.</li>
          <li><strong>Uncertainty is reported, not resolved.</strong> Several of these tools work on
              data where a confident wrong answer is worse than a flagged ambiguity, and they are
              written that way on purpose.</li>
          <li><strong>Long operations show progress and can be cancelled</strong>, and batch runs end
              with real totals rather than a cheerful summary.</li>
        </ul>

        <h2>Releases and updates</h2>
        <p>The applications share a common update mechanism that checks a local network share first
           and a public release channel second. A package is never executed before its checksum has
           been verified, and nothing installs without explicit confirmation. No credentials are
           embedded in any shipped application.</p>
        <p>This site is the public record of what exists. Binaries themselves stay in private
           distribution — see <a href="index.html#access">Access and releases</a> for what each
           status means and how to ask about a build.</p>

        <h2>Licensing</h2>
        <p>Most of the catalog is released under the Apache License 2.0, copyright Bluebonnet
           Studios. Each tool page states the licence that applies to it. Where a licence has not
           been declared yet, the page says &ldquo;Not stated&rdquo; rather than implying one.</p>

        <h2>Where the name comes from</h2>
        <p>Lupinus texensis, the Texas bluebonnet: royal-cobalt petals, a pale banner spot that
           turns magenta once the flower has been pollinated, yellow-green buds at the top of the
           raceme that have not opened yet, and vivid grass underneath. That is the whole palette
           this site is built from, and the reason the mark is a flower on a stem rather than a
           logotype.</p>
        <p>The status colours come from the same place, and mean what the flower means: grass for
           what is available, bud yellow for what has not opened, the pollinated magenta for what
           has been handed out on request, and no colour at all for what has not started.</p>
      </div>
HTML
  art about tail
cat <<HTML
    </main>
  </div>
HTML
  page_close
}

# --- index page --------------------------------------------------------------
# --- home page category panels ----------------------------------------------
# The home page names the four categories and what each is for; the roster
# itself lives on the category pages. One short line per category — the longer
# pitch is cat_head, which the category page uses.
cat_pitch () {
  case "$1" in
    Business)   printf 'The repetitive middle of office work: getting a schedule out of the tool that authored it, deciding what needs expensive processing, and reading long technical documents without surprises.' ;;
    "Web &amp; Mobile") printf 'Hardware a desktop tool never reaches: a phone on a metro platform, and an Android head unit in a car that has no Play Store. Neither asks who you are.' ;;
    Lightroom)  printf 'The unglamorous work of a large photo library: the photographs you already have twice, the files the catalog has lost, and the place a picture was actually taken.' ;;
    Geoscience) printf 'Exploration data handled by tools that share one habit — they say what they know, mark what they inferred, and refuse to turn a guess into a fact.' ;;
  esac
}

# The tool names in a category. Spans, not links: the whole panel is already a
# link, and an anchor inside an anchor is invalid. Names only — versions and
# status belong in the roster on the category page, not in a panel to be scanned.
cat_tool_names () {  # category
  printf '%s\n' "$TOOLS" | while IFS=$'\t' read -r name slug cat _rest; do
    [ "$cat" = "$1" ] || continue
    printf '<span class="cat-tool">%s</span>' "$name"
  done
}

count_status () {  # status
  printf '%s\n' "$TOOLS" | awk -F'\t' -v s="$1" '$6==s' | wc -l | tr -d ' '
}

category_panels () {
  printf '      <div class="cat-grid">\n'
  printf '%s\n' "$CATEGORIES" | while IFS='|' read -r c page label; do
    local n; n="$(count_in "$c")"
    printf '        <a class="cat-panel" href="%s">\n' "$page"
    printf '          <span class="cat-panel-head"><span class="cat-panel-name">%s</span><span class="cat-panel-n">%s</span></span>\n' "$label" "$n"
    printf '          <span class="cat-panel-pitch">%s</span>\n' "$(cat_pitch "$c")"
    printf '          <span class="cat-panel-tools">%s</span>\n' "$(cat_tool_names "$c" | tr -d '\n')"
    printf '          <span class="cat-panel-go">View %s<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="M3 8h9M8.5 4.5L12 8l-3.5 3.5" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg></span>\n' "$label"
    printf '        </a>\n'
  done
  printf '      </div>\n'
}

index_page () {
  page_open "Bluebonnet Studios — Software Catalog" \
    "Tools for document workflows, OCR routing, Lightroom catalogs, subsurface data and Android devices without Google — each listed with its version, platform and availability." \
    "catalog"
cat <<HTML
  <div class="page-head">
$(art index crown)
    <div class="page-head-inner">
      <div>
        <p class="eyebrow">Software catalog</p>
        <h1>One job each, <span class="hl">wherever the work happens.</span></h1>
        <p>$(total_tools) applications across Windows, macOS, Lightroom, the browser and Android
           — document workflows, OCR routing, photo catalogs and subsurface data. Each is listed
           with its version, platform and availability, so you can see what exists, what is
           finished, and what you can actually get hold of.</p>
      </div>
      <div class="stats">
        <div><b>$(total_tools)</b><span>Tools</span></div>
        <div><b>$(printf '%s\n' "$CATEGORIES" | wc -l | tr -d ' ')</b><span>Categories</span></div>
        <div><b>$(count_status private)</b><span>Private releases</span></div>
      </div>
    </div>
  </div>

  <div class="layout">
HTML
  rail "index.html"
cat <<HTML
    <main class="content" id="main">
      <section>
        <h2 class="section-label">Four kinds of tool</h2>
        <p class="section-intro">Each category has its own page, with the full roster and every
           version, platform and status. Start wherever your problem lives.</p>
HTML
  category_panels
cat <<HTML
      </section>
HTML
  access_section
cat <<HTML
    </main>
  </div>
HTML
  page_close
}


# --- consistency check -------------------------------------------------------
# A tool can be added to CATALOG.txt before its page copy is written. That
# builds, but the page would be nearly empty, so say so rather than ship it
# quietly.
check_copy () {
  local missing=""
  # Category copy is keyed by the category name, which is HTML-escaped along
  # with everything else in CATEGORIES. A case pattern that still spells the
  # unescaped name matches nothing and yields an empty heading, so check it.
  printf '%s\n' "$CATEGORIES" | while IFS='|' read -r c page label; do
    [ -n "$c" ] || continue
    [ -n "$(cat_pitch "$c")" ] || echo "build: warning: category [$c] has no cat_pitch — its home-page panel will be blank" >&2
    [ -n "$(cat_head "$c")" ] || echo "build: warning: category [$c] has no cat_head — its page will have an empty heading" >&2
  done
  printf '%s\n' "$TOOLS" | while IFS=$'\t' read -r name slug rest; do
    [ -n "$slug" ] || continue
    if [ -z "$(tool_lede "$slug")" ]; then
      echo "build: warning: [$slug] has no tool_lede in build.sh" >&2
    fi
    if [ -z "$(tool_prose "$slug")" ]; then
      echo "build: warning: [$slug] has no tool_prose in build.sh — its page will be thin" >&2
    fi
    if [ -z "$(tool_meta_desc "$slug")" ]; then
      echo "build: warning: [$slug] has no tool_meta_desc in build.sh" >&2
    fi
  done
}

# --- drive -------------------------------------------------------------------
check_copy

index_page > index.html
about_page > about.html
privacy_page > privacy.html
printf '%s\n' "$CATEGORIES" | while IFS='|' read -r c page label; do
  category_page "$c" > "$page"
done
printf '%s\n' "$TOOLS" | while IFS=$'\t' read -r name slug rest; do
  [ -n "$slug" ] || continue
  tool_page "$slug" > "$slug.html"
done
echo "built: index, about, privacy, $(printf '%s\n' "$CATEGORIES" | wc -l | tr -d ' ') categories, $(total_tools) tool pages — $(ls -1 *.html | wc -l | tr -d ' ') files"
