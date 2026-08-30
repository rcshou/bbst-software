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

# --- catalog data ------------------------------------------------------------
# CATALOG.txt lists the repositories; fetch-catalog.sh reads their metadata from
# GitHub into catalog-cache.tsv; this reads that cache. Nothing about a tool is
# duplicated here, so a version bump or a reworded description on GitHub reaches
# the site by re-running the fetch, never by editing a file in this repo.
#
#   bash build.sh             build from the cache as it stands
#   bash build.sh --refresh   fetch from GitHub first, then build
CACHE_FILE="${CACHE_FILE:-catalog-cache.tsv}"

if [ "${1:-}" = "--refresh" ]; then
  bash fetch-catalog.sh || { echo "build: fetch failed; not building from a stale cache" >&2; exit 1; }
fi

if [ ! -f "$CACHE_FILE" ]; then
  echo "build: $CACHE_FILE not found — run 'bash fetch-catalog.sh' first" >&2
  exit 1
fi

# tab-separated cache -> the pipe-delimited internal form
TOOLS="$(awk -F'\t' '!/^#/ && NF>=8 { printf("%s|%s|%s|%s|%s|%s|%s|%s\n", $1,$2,$3,$4,$5,$6,$7,$8) }' "$CACHE_FILE")"
[ -n "$TOOLS" ] || { echo "build: $CACHE_FILE has no usable rows" >&2; exit 1; }

CATEGORIES='Business|business-tools.html|Business Tools
Web Apps|web-apps.html|Web Apps
Lightroom|lightroom-plugins.html|Lightroom Plugins
Geoscience|geoscience-tools.html|Geoscience Tools'
tool_field () {  # slug field-index
  printf '%s\n' "$TOOLS" | awk -F'|' -v s="$1" -v n="$2" '$2==s{print $n; exit}'
}
count_in () {  # category
  printf '%s\n' "$TOOLS" | awk -F'|' -v c="$1" '$3==c' | wc -l | tr -d ' '
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
  printf '%s\n' "$TOOLS" | while IFS='|' read -r name slug cat ver plat stat desc lic; do
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
tool_meta_desc () {
  case "$1" in
    bakmil-metro) printf 'Next-departure times for the Bakmil to Nərimanov metro shuttle in Baku, in a web app that opens instantly and needs no account.' ;;
    similars-and-statistics) printf 'A Lightroom Classic plugin that groups visually similar photographs, reports file-type statistics, flags corrupt HEIC files and fixes wrong capture dates.' ;;
    restore-missing-photos) printf 'A Lightroom Classic plugin that finds files matching photos the catalog reports as missing and puts them back where the catalog expects them.' ;;
    location-caption) printf 'A Lightroom Classic plugin that suggests the actual landmark a GPS-tagged photo was taken at, from OpenStreetMap data, and writes nothing until you approve it.' ;;
    project2excel) printf 'Convert Microsoft Project .mpp files into editable Excel workbooks — Gantt view, task data, resources, assignments and relations — without a Project licence.' ;;
    pdf-classifier) printf 'Classify PDFs by the real quality of their text layer and get a per-page OCR routing decision, before spending anything on OCR.' ;;
    markdown-renderer) printf 'A desktop Markdown viewer with accurate tables, KaTeX maths, Mermaid diagrams, linting, cleanup and self-contained HTML export.' ;;
    geocrawler) printf 'Audit a subsurface data repository: catalog SEG-Y and LAS files, read their headers, detect coordinate systems, and find duplicates.' ;;
    segy-coordinate-security) printf 'Audit, sanitize and independently verify SEG-Y files before sharing them, replacing map coordinates with one consistent local grid.' ;;
    cassandra-risking) printf 'Prospect risking with the evidence attached: chance-of-success calculations that keep a snapshot of what they were based on.' ;;
  esac
}

tool_lede () {
  case "$1" in
    bakmil-metro) printf 'Tells you when the next shuttle leaves, and nothing else. No account, no install, no tracking — open it at the platform and the answer is already on screen.' ;;
    similars-and-statistics) printf 'Four jobs a large Lightroom catalog eventually needs doing, in one plugin: find the photographs you already have twice, count what file types you are actually holding, catch HEIC files that have gone bad, and fix capture dates that disagree with the folder they sit in.' ;;
    restore-missing-photos) printf 'Lightroom marks a photo as missing when the file moves out from under it. This searches the folders you point it at for files matching those photos and puts them back at the paths the catalog still expects.' ;;
    location-caption) printf 'City names are rarely the answer. This reads a photograph&rsquo;s GPS position, asks OpenStreetMap what is actually there, and proposes the specific landmark — the temple, not the province — for you to approve before anything is written.' ;;
    project2excel) printf 'Opens a Microsoft Project <code>.mpp</code> file and writes a real Excel workbook — a drawn Gantt chart, the task data behind it, resources, assignments and relationships — on a machine that has never had Project installed.' ;;
    pdf-classifier) printf 'Looks at what is actually in a PDF&rsquo;s text layer, page by page, and tells you which pages need OCR and which do not. It performs no OCR itself, and it has no opinion about which OCR engine you use next.' ;;
    markdown-renderer) printf 'A Markdown viewer that renders what you will actually publish — real tables, KaTeX maths, Mermaid diagrams, GFM alerts — and will tell you which parts of your document are likely to break somewhere else.' ;;
    geocrawler) printf 'Crawls a folder tree of subsurface data and tells you what is in it: which files are seismic, which are well logs, what their headers claim, which are duplicates, and which claims should not be trusted.' ;;
    segy-coordinate-security) printf 'Prepares SEG-Y data for a vendor or a data room by removing direct georeferencing while preserving line geometry, then verifies the result independently — and is careful about what it does and does not promise.' ;;
    cassandra-risking) printf 'Calculates prospect chance of success and keeps a snapshot of the evidence each number was based on, so a risking decision can still be explained months later.' ;;
  esac
}

tool_prose () {
case "$1" in
location-caption) cat <<'HTML'
<h2>The problem with reverse geocoding</h2>
<p>Ask most tools where a photograph was taken and they answer with a city. But you did not
   photograph Siem Reap, you photographed the Bayon. The name worth keeping is the specific one —
   the temple, the monument, the museum, the archaeological site — and it is the one general
   reverse geocoding is least likely to give you.</p>

<h2>What it does</h2>
<p>Select GPS-tagged photographs and run <strong>Library &gt; Plug-in Extras &gt; Suggest Location
   Metadata</strong>. Nearby photographs are grouped into coordinate clusters and each cluster is
   looked up once — a reverse geocode plus a search for named landmarks nearby, through the public
   Nominatim and Overpass services. Results are then ranked so a specific landmark outranks the
   complex containing it, which outranks the surrounding city, when the evidence supports it.</p>

<h2>Nothing is written until you say so</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Writing captions straight into the catalog and letting you audit them later.</strong>
     Automated place names are wrong often enough that a silent bulk write is a bad trade. Every
     suggestion goes through a review dialog first — accept it, choose a different candidate, or
     skip it — and only approved captions reach the catalog metadata.</p>
</div>

<h2>Status, stated plainly</h2>
<p>Every module that does not touch the Lightroom SDK — candidate ranking, caption formatting,
   caching, the provider clients, coordinate grouping, results summarisation — is implemented and
   unit tested, including tests run against real captured Nominatim and Overpass responses rather
   than hand-written guesses. The SDK-facing parts — catalog access, metadata writes, the review
   dialog, menu registration — are written against the documented Lightroom Classic SDK but have
   <strong>not yet been run inside Lightroom</strong>.</p>
<p>So: point it at a disposable test catalog first, not a production one. The Plug-in Manager lets
   you add it without touching your real catalog, and the plugin itself never reads or changes
   anything beyond your current selection either way.</p>
HTML
;;
similars-and-statistics) cat <<'HTML'
<h2>Four jobs, one plugin</h2>
<ul>
  <li><strong>Find similar photos</strong> — groups visually similar images using HSV colour-histogram comparison plus a coarse structural-correlation check, so near-duplicates from a burst or a re-import surface together.</li>
  <li><strong>File type statistics</strong> — reports what file types the selection actually contains, which is usually not what you assumed.</li>
  <li><strong>HEIC corruption check</strong> — flags HEIC files that have gone bad, before you find out at export time.</li>
  <li><strong>Fix invalid capture date</strong> — finds photographs whose capture year disagrees with the folder they are filed under, and organises them.</li>
</ul>

<h2>Similar, not identical</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Matching checksums and calling it duplicate detection.</strong> A checksum finds byte-identical files, which is the easy half of the problem and rarely the half you have. Two exports at different sizes, a re-edit, the same frame from a burst — none of those match on bytes, and all of them are what you actually want grouped. Comparing colour histograms and coarse structure finds them.</p>
</div>

<h2>How it is built</h2>
<p>The comparison work runs in native helper executables bundled inside the plugin rather than in
   Lightroom&rsquo;s Lua runtime, because pixel comparison across a large selection is not something to
   ask a scripting host to do. The helpers are built from C++ sources kept in the same repository,
   against OpenCV, libheif and libraw.</p>
<p>Built against Lightroom SDK 12 with a declared minimum of SDK 10, so it runs on current
   Lightroom Classic and on installations several versions behind. Every command appears under
   <strong>Library &gt; Plug-in Extras</strong>, and a Plugin Descriptions item explains what each
   one does without leaving the application.</p>
HTML
;;

restore-missing-photos) cat <<'HTML'
<h2>The situation</h2>
<p>Lightroom records where every photograph lives. Move the files with anything other than
   Lightroom — a backup restore, a drive swap, a tidy-up in Finder or Explorer — and the catalog
   still holds all your edits, collections and ratings, pointing at paths that no longer exist.
   The thumbnails stay; the photographs are gone.</p>

<h2>What it does</h2>
<p>Searches one or more source folders for files whose names match the photographs the catalog
   currently reports as missing, then optionally copies the matches back to the exact paths the
   catalog still expects. The catalog is never rewritten to chase the files; the files are
   returned to where the catalog already believes they are, so every edit and collection stays
   attached.</p>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Reconnecting folders by hand, one at a time.</strong> Lightroom&rsquo;s own reconnect
     works, and works well, when the missing photographs sit together in one moved folder. It is
     painful when a few thousand files scattered across a restored backup need matching
     individually — which is exactly the case this exists for.</p>
</div>

<h2>Controls</h2>
<ul>
  <li><strong>List missed photo locations</strong> — starts the recovery workflow from the current selection.</li>
  <li><strong>Duplicate handling</strong> — settable from the plugin&rsquo;s own menu without opening the Plug-in Manager, because it is the setting you actually change mid-run.</li>
  <li><strong>In-app help</strong> — available both from the menu and from the Plug-in Manager entry.</li>
</ul>
<p>Built against Lightroom SDK 12 with a declared minimum of SDK 10.</p>
HTML
;;
bakmil-metro) cat <<'HTML'
<h2>What it does</h2>
<p>The Bakmil to Nərimanov shuttle runs on a published timetable. Finding the next departure
   normally means loading a site built for a desktop, hunting for the right line, and reading a
   table. This shows the next departures for that line and stops there.</p>
<p>It installs as a progressive web app, so it can sit on a home screen and open like anything
   else on the phone. There is no account, no install prompt on first visit, and nothing that
   follows you.</p>

<h2>Where the times come from</h2>
<p>The schedule is refreshed once a day by a scheduled job that reads the metro operator&rsquo;s own
   published schedule service. Any external source can change or go quiet, and that is handled
   rather than ignored.</p>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Publishing whatever the source returned today.</strong> If it stops returning valid
     data, the job leaves the last known-good schedule in place and records the failure
     separately. A stale timetable that was correct last week beats a broken one generated this
     morning, and either way the failure is visible rather than silent.</p>
</div>

<h2>How it is built</h2>
<p>No build step and no dependencies: the app is plain files, and the update scripts run directly
   on Node&rsquo;s built-ins. The scraper&rsquo;s logic — station matching, time normalisation and sorting,
   validation, change detection — is unit tested with the built-in test runner, and those tests run
   in CI before every scheduled update. The live network fetch is exercised for real each time the
   scheduled job runs.</p>
<p>The version lives in exactly one file and is shown on the About screen.</p>
HTML
;;

project2excel) cat <<'HTML'
<h2>What it produces</h2>
<p>One workbook, with the schedule split across the sheets you would otherwise build by hand:</p>
<ul>
  <li><strong>Gantt View</strong> — task hierarchy, durations, dates, progress and resources, with calendar-aware shading for nonworking days, milestone markers, critical-task highlighting, and thin FS/SS/FF/SF dependency connectors drawn behind the bars.</li>
  <li><strong>Task Data</strong> — the filterable source data, with real task IDs, readable dependency notation, and baseline, actual, constraint and calendar fields.</li>
  <li><strong>Resources</strong> — the project&rsquo;s resource catalog with rate, calendar and contact fields.</li>
  <li><strong>Assignments</strong> — task-to-resource assignments with resolved names, units, work and cost.</li>
  <li><strong>Relations</strong> — one row per relationship, with endpoint IDs and names, type, lag and lag units.</li>
</ul>

<h2>Why it exists</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Buying a Project licence for someone who only needs to read the schedule.</strong> Most people who receive an .mpp file need to look at it, filter it, and paste part of it into a report. That is a spreadsheet job, and it should not require the authoring tool.</p>
  <p><strong>Uploading the schedule to a web converter.</strong> Project plans carry budgets, staffing and delivery dates. This runs entirely on your machine, with a bundled MPXJ reader and its own Java runtime, so nothing leaves the desktop.</p>
</div>

<h2>How it runs</h2>
<p>There is a desktop application for Windows and macOS, and a command-line interface that performs the same conversion, so a batch of plans can be converted on a schedule rather than by hand. Gantt output scale is configurable, and packaging is standalone: an installer on Windows, an app bundle on macOS, reader and runtime included.</p>
<p>The version in the project manifest is the single source of truth. The About dialog and the CLI&rsquo;s version flag both read it back, so the number the application reports is the number that was built.</p>
HTML
;;

pdf-classifier) cat <<'HTML'
<h2>What it looks at</h2>
<p>&ldquo;Does this PDF have a text layer?&rdquo; is the wrong question — plenty of PDFs have one that is unusable. Each page is judged on the things that actually predict whether extraction will work:</p>
<ul>
  <li><strong>Text density</strong>, measured against the space the page actually occupies.</li>
  <li><strong>Artifacts</strong> — (cid:123) sequences, replacement characters, mojibake from a bad encoding.</li>
  <li><strong>Script consistency</strong>, so a page that drifts between alphabets is caught.</li>
  <li><strong>Bounding-box coverage</strong> and <strong>reading order</strong>, which is where a technically-present text layer usually fails.</li>
</ul>
<p>The result is a per-page and per-document verdict, and a recommended processing mode that downstream OCR tooling can route on directly, rather than a coarse yes-or-no flag.</p>

<h2>Where the verdict lives</h2>
<p>By default the summary is written back into the PDF itself as namespaced XMP metadata, with a compact DocInfo fallback and roundtrip verification. That makes the file self-describing: whatever moves it next can read the decision without a companion file to lose. Sidecar JSON is available but off by default, and run-level JSONL and CSV reports plus a SQLite scan history are written per scan regardless. CSV exports carry a UTF-8 byte-order mark so Excel renders Cyrillic and Azerbaijani text instead of guessing the system codepage.</p>
<p>Embedded metadata is checked against a content fingerprint before it is trusted, so a PDF that was re-saved after classification is never silently treated as already classified.</p>

<h2>What it deliberately does not do</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Bundling an OCR engine and an opinion.</strong> It performs no OCR and depends on no OCR engine — not Tesseract, PaddleOCR, MinerU or anything else. It produces a routing decision; you keep the choice of what acts on it.</p>
  <p><strong>Rewriting your source files without being asked.</strong> Metadata embedding is on by default in the desktop app&rsquo;s settings and off by default on the CLI&rsquo;s scan command unless you explicitly ask for it.</p>
</div>

<h2>How it runs</h2>
<p>A CLI, a compact PySide6 desktop application, and a small Python API for downstream tools. The desktop app opens with a choice between the full application — dashboard, scan, results, per-PDF detail, metadata, settings and logs — and a <strong>Quick One-File Classification</strong> mode that classifies a single PDF without touching the database at all: no connection, no migration, no run recorded, no effect on the dashboard or history. Single-file actions run on a background thread, so the interface never freezes mid-scan.</p>
<p>Language reporting is deliberately narrow. English, Russian and Azerbaijani are reported as document languages, mixed documents among them are expected rather than penalised, and formula symbols are treated as scientific notation rather than as language text. Other scripts are used as diagnostics, not claimed as supported OCR routes.</p>
HTML
;;

markdown-renderer) cat <<'HTML'
<h2>What it renders</h2>
<ul>
  <li><strong>Tables</strong> with Auto, Markdown and HTML render modes, and per-table diagnostics explaining which mode was chosen and why.</li>
  <li><strong>Maths</strong> via KaTeX for inline and display expressions — while leaving currency amounts in prose alone, which is the failure everyone has met.</li>
  <li><strong>Mermaid diagrams</strong>, drawn in the preview and in HTML exports; a diagram that cannot be drawn keeps its source visible rather than vanishing.</li>
  <li><strong>Callouts</strong> — GFM alerts, admonitions and container blocks, with their severity label and styling.</li>
  <li><strong>Syntax highlighting</strong> for the common language families and diffs, with unknown languages shown as plain text instead of guessed at.</li>
  <li><strong>Abbreviations</strong>, expanding defined terms into tooltips throughout the document.</li>
</ul>

<h2>Beyond preview</h2>
<p>The document can be linted for renderer-specific syntax, malformed Markdown, portability risks and likely fixes. A separate non-destructive cleanup pass applies safe corrections and optional issue-driven fixes, with a summary in the lower pane and a saveable cleanup log. Parser profiles — Strict, GFM and Document — change actual backend parsing and diagnostics, not merely the preview.</p>

<h2>Why it exists</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>An editor preview that quietly disagrees with your publishing target.</strong> A pane that renders your tables one way and your pipeline another is worse than no preview at all. This one reports what it did to each table and why, and can lint the document for the constructs that travel badly.</p>
  <p><strong>A browser tab and a copy-paste workflow.</strong> Export produces a single self-contained HTML file with maths already rendered, and printing goes through the system dialog, so Print to PDF behaves the way it does everywhere else.</p>
</div>

<h2>Built for long documents</h2>
<p>Large files raise a warning, expensive automatic resource checks are skipped, and files above the safe open limit are blocked rather than allowed to hang the window. Unsaved cleanup or repair changes prompt before you open another document or quit. Raw HTML in the source is sanitized before preview and export, so a document from elsewhere cannot execute anything.</p>
<p>Built with Tauri&nbsp;v2 and TypeScript over a Python rendering backend. Zoom, theme and recent files persist across sessions, and there is a built-in user guide plus a rotated diagnostic log you can open from the Help menu.</p>
HTML
;;

geocrawler) cat <<'HTML'
<h2>What it does</h2>
<p>Exploration data repositories grow by accretion. Geocrawler walks a folder tree and turns it into a catalog you can reason about:</p>
<ul>
  <li><strong>Catalogs</strong> seismic, well-log and related subsurface files by type.</li>
  <li><strong>Reads headers</strong> — SEG-Y binary and textual headers, LAS well logs, and survey metadata.</li>
  <li><strong>Detects coordinate reference systems</strong>, EPSG codes and project context from what the headers actually say.</li>
  <li><strong>Finds duplicates</strong>, both individual files and folder-level duplicate content.</li>
  <li><strong>Reports</strong> to Excel for stakeholder review and Markdown for quick documentation, from a PySide6 interface where results can be reviewed before export.</li>
</ul>

<h2>Honest about what it cannot know</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Reporting a confident guess as a fact.</strong> Header-derived coordinate systems are labelled &ldquo;CRS from headers&rdquo; and flagged as unverified, because zone numbers are especially unreliable on older surveys. A CRS inferred from trace coordinates is tagged as inferred, so it is never mistaken for a header declaration. Where a zone label is genuinely ambiguous — the classic case where a legacy Gauss-Kr&uuml;ger zone survives a conversion and looks like a UTM zone — it is surfaced as an ambiguity rather than resolved by coin flip.</p>
</div>
<p>The same care applies to 2D/3D classification. A quick scan of the first traces can call a real 3D volume &ldquo;2D&rdquo; when a single inline runs longer than the sample, so a full-scan action validates candidate axis bytes against a whole-file geometry builder before committing to an answer.</p>

<h2>Why it matters day to day</h2>
<p>It replaces manual folder inspection with automated discovery, speeds up quality checks with metadata validation and duplicate detection, keeps catalogs consistent across projects, and makes a handoff reviewable — because the report goes with the data.</p>

HTML
;;

segy-coordinate-security) cat <<'HTML'
<h2>The situation</h2>
<p>You need to send seismic data to a vendor, or open a data room. The data has to remain loadable and interpretable as seismic. What it must not do is hand over exactly where the survey was shot.</p>

<h2>What it does</h2>
<p>Audit, sanitize and independently verify — as three separate steps, in that order. Direct map coordinates in the standard CDP, source and receiver header locations are replaced with one consistent local-grid transformation applied across the whole delivery set, so line geometry and relative positions survive intact. Textual headers are replaced with a controlled functional header that declares the preserved inline and crossline bytes, the transformed X/Y bytes, the scalar, units and sample layout — and states plainly that the local grid has no external reference.</p>
<p>Binary headers, seismic samples, trace order, inline and crossline words and bin topology are left unchanged. The output loads as seismic data because it still is seismic data.</p>

<h2>What it refuses to claim</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>Promising anonymity it cannot deliver.</strong> Preserved geometry remains a recognisable fingerprint and can be matched against another copy of the same survey. The tool therefore reports &ldquo;no direct georeferencing detected&rdquo; — never that re-identification is impossible. Coordinates duplicated into nonstandard vendor header bytes are flagged for review rather than rewritten silently; transforming one requires an explicitly reviewed and declared mapping, restricted to a fixed set of safe offsets.</p>
</div>

<h2>The application</h2>
<p>A PySide6 desktop workflow with Audit, Transformation Plan, Sanitize, Verify, Verify Existing, Geometry QA, 3D Survey QA and Settings screens. Verify Existing sits outside the pipeline, so a file someone else produced can be checked on its own terms. Geometry QA can display one line or every verified line and fits the map to the loaded geometry; a bundled offline Azerbaijan and Caspian Sea basemap outline is available as a background that needs no network at all, and public map tiles stay disabled until explicitly allowed. A saved plan can be reloaded to reuse its rotation, scale and scalar when adding more lines or a 3D volume to an existing batch.</p>
HTML
;;

cassandra-risking) cat <<'HTML'
<h2>What it does</h2>
<p>Calculates prospect chance of success, and keeps the evidence. Each calculation stores a snapshot of the inputs and the supporting material it was based on, linked to the scenarios and hypotheses it came from, in a local database with an audited schema.</p>

<h2>Why the evidence matters</h2>
<div class="compare">
  <p class="compare-label">Instead of</p>
  <p><strong>A spreadsheet that produces a number and forgets why.</strong> Risking numbers get quoted in decisions months after they are calculated, by people who were not in the room. A figure whose basis cannot be reconstructed cannot be defended, revised or audited — so the evidence snapshot travels with the result rather than living in someone&rsquo;s memory.</p>
</div>

<h2>Shape of the tool</h2>
<ul>
  <li>Scenario and hypothesis structure, with evidence attached at the point it is used.</li>
  <li>Calculation results stored with their evidence snapshots rather than recomputed on demand.</li>
  <li>A local database that migrates its own schema forward, including index backfill for existing databases.</li>
  <li>A generated HTML guide built from the same source as the application.</li>
  <li>Packaged as a standalone Windows build.</li>
</ul>

<h2>Status</h2>
<p>Versioned and in active development, currently on the 0.5 series. It is listed as a private release: built and usable, distributed on request rather than published.</p>
HTML
;;

esac
}

# --- category page copy ------------------------------------------------------
cat_head () {  # category -> "h1|intro|meta"
case "$1" in
  Business) printf '%s' 'Reporting and document work, <span class="hl">without the busywork.</span>|Three applications for the repetitive middle of office work: getting a schedule out of the tool that authored it, deciding which documents need expensive processing, and reading long technical Markdown without surprises.|Project2Excel, PDF Classifier and Markdown Renderer: schedule conversion, PDF routing and Markdown tooling from Bluebonnet Studios.' ;;
  "Web Apps") printf '%s' 'Built for a city, <span class="hl">not for a login.</span>|Public web applications that answer one question fast, work on a phone, and ask nothing of you — no account, no install, no tracking.|Bakmil Metro Schedule: a progressive web app for the Bakmil to Nərimanov metro shuttle in Baku.' ;;
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
  printf '%s\n' "$TOOLS" | while IFS='|' read -r name slug tcat ver plat stat desc lic; do
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
    "Bluebonnet Studios builds small, precise desktop tools for document workflows, photo catalogs and subsurface data." \
    "about"
cat <<'HTML'
  <div class="page-head">
    <div class="page-head-inner">
      <div>
        <p class="eyebrow">About</p>
        <h1>A small studio that builds <span class="hl">specific tools.</span></h1>
        <p>Bluebonnet Studios builds desktop software for people whose work is stuck between
           applications: a schedule trapped in the tool that authored it, a folder of PDFs that
           may or may not be readable, a photo catalog with twenty years of accumulated mess, a
           seismic dataset that has to leave the building without giving away where it came from.</p>
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
        <p>Every application in this catalog is a native desktop program — mostly PySide6 on
           Windows and macOS, one built on Tauri, two as Lightroom plugins. They open fast, they
           work offline, and they keep their data on your machine.</p>
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
index_page () {
  page_open "Bluebonnet Studios — Software Catalog" \
    "Desktop tools for document workflows, OCR routing, Lightroom catalogs and subsurface data, each listed with its version, platform and availability." \
    "catalog"
cat <<HTML
  <div class="page-head">
$(art index crown)
    <div class="page-head-inner">
      <div>
        <p class="eyebrow">Software catalog</p>
        <h1>Desktop tools that do <span class="hl">one job</span> properly.</h1>
        <p>$(total_tools) applications for document workflows, OCR routing, Lightroom catalogs and
           subsurface data. Each one is listed with its version, platform and availability, so you
           can see what exists, what is finished, and what you can actually get hold of.</p>
      </div>
      <div class="stats">
        <div><b>$(total_tools)</b><span>Tools</span></div>
        <div><b>4</b><span>Categories</span></div>
        <div><b>8</b><span>Private releases</span></div>
      </div>
    </div>
  </div>

  <div class="layout">
HTML
  rail "index.html"
cat <<HTML
    <main class="content" id="main">
      <section>
        <p class="section-label">All tools</p>
HTML
  roster "#access" ""
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
  printf '%s\n' "$TOOLS" | while IFS='|' read -r name slug rest; do
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
printf '%s\n' "$TOOLS" | while IFS='|' read -r name slug rest; do
  [ -n "$slug" ] || continue
  tool_page "$slug" > "$slug.html"
done
echo "built: index, about, $(printf '%s\n' "$CATEGORIES" | wc -l | tr -d ' ') categories, $(total_tools) tool pages"
