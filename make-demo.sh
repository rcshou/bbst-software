#!/usr/bin/env bash
# Packs the whole static site into one navigable HTML file for preview.
# Each page becomes a <div class="demo-page">; ids are namespaced per page so
# nothing collides, and links are rewritten to a tiny in-page router.
# This is a preview artifact only — the real site is the separate files.
set -euo pipefail
OUT="$1"

{
  echo '<title>Bluebonnet Catalog</title>'
  grep '<link' index.html | grep -E 'fonts\.(googleapis|gstatic)'
  echo '<style>'
  cat styles.css
  cat <<'CSS'

/* ---- preview shell (not part of the real site) ---- */
.demo-page[hidden]{ display:none !important; }
.demo-badge{
  position:fixed; left:12px; bottom:12px; z-index:50;
  display:flex; align-items:center; gap:8px;
  background:var(--panel); border:1px solid var(--line-strong); border-radius:3px;
  padding:7px 11px; box-shadow:0 2px 10px rgba(0,0,0,.16);
  font-family:var(--mono); font-size:10px; letter-spacing:.1em;
  text-transform:uppercase; color:var(--dim);
}
.demo-badge b{ color:var(--violet); font-weight:700; }
CSS
  echo '</style>'
} > "$OUT"


# The preview is one file served from a single URL, so relative asset paths do
# not resolve. Each ornament is inlined once as a data URI on a CSS class, and
# the img elements are pointed at a transparent pixel that the class paints.
# The real site keeps ordinary <img src="assets/..."> and never does this.
PIXEL="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
{
  echo '<style>'
  for a in assets/bluebonnet-*.png; do
    stem="$(basename "$a" .png)"
    printf '.a-%s{ background-image:url(data:image/png;base64,' "$stem"
    # Read from stdin and strip newlines rather than using GNU's -w0, which BSD
    # base64 (macOS) rejects along with a positional filename.
    base64 < "$a" | tr -d '\n'
    printf '); }\n'
  done
  cat <<'CSS'
.art img{ background-size:contain; background-repeat:no-repeat; background-position:center; }
CSS
  echo '</style>'
} >> "$OUT"

# The tool pages follow the catalog, so a newly listed app appears in the preview
# without anyone remembering to edit a list here. The fixed pages lead, in reading
# order; the tool pages follow in catalog order.
PAGES="index.html about.html privacy.html business-tools.html web-apps.html lightroom-plugins.html geoscience-tools.html"
while IFS=$'\t\r' read -r slug _rest; do
  case "$slug" in ''|\#*) continue ;; esac
  PAGES="$PAGES $slug.html"
done < CATALOG.txt

first=1
for f in $PAGES; do
  [ -f "$f" ] || { echo "make-demo: $f not built — run bash build.sh first" >&2; exit 1; }
  slug="${f%.html}"
  if [ "$first" = 1 ]; then hid=""; first=0; else hid=" hidden"; fi
  printf '<div class="demo-page" data-slug="%s"%s>\n' "$slug" "$hid" >> "$OUT"
  sed -n '/^<body>/,/^<\/body>/p' "$f" \
    | sed '1d;$d' \
    | sed '/<script src="theme.js">/d' \
    | sed \
        -e "s@href=\"#\([^\"]*\)\"@href=\"#go:$slug:${slug}__\1\"@g" \
        -e "s@href=\"\([A-Za-z0-9_-]*\)\.html#\([^\"]*\)\"@href=\"#go:\1:\1__\2\"@g" \
        -e "s@href=\"\([A-Za-z0-9_-]*\)\.html\"@href=\"#go:\1:\"@g" \
        -e "s@id=\"\([^\"]*\)\"@id=\"${slug}__\1\"@g" \
        -e "s@src=\"assets/\([a-z-]*\)\.png\"@src=\"$PIXEL\" class=\"a-\1\"@g" \
    >> "$OUT"
  printf '</div>\n' >> "$OUT"
done

cat >> "$OUT" <<'TAIL'
<div class="demo-badge"><b>Preview</b> <span>__PAGECOUNT__ pages, one file &middot; links work</span></div>
<script>
(function () {
  "use strict";
  var pages = Array.prototype.slice.call(document.querySelectorAll(".demo-page"));

  function show(slug, anchor) {
    var found = false;
    pages.forEach(function (p) {
      var match = p.dataset.slug === slug;
      p.hidden = !match;
      if (match) found = true;
    });
    if (!found) return;
    if (anchor) {
      var el = document.getElementById(anchor);
      if (el) { el.scrollIntoView({ block: "start" }); return; }
    }
    window.scrollTo(0, 0);
  }

  document.addEventListener("click", function (e) {
    var a = e.target.closest ? e.target.closest('a[href^="#go:"]') : null;
    if (!a) return;
    e.preventDefault();
    var parts = a.getAttribute("href").slice(4).split(":");
    show(parts[0], parts[1] || "");
  });

  /* Theme: every page carries its own toggle, so wire them all. */
  var KEY = "bbst-theme", root = document.documentElement;
  function current() {
    var set = root.getAttribute("data-theme");
    if (set === "light" || set === "dark") return set;
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }
  try {
    var stored = localStorage.getItem(KEY);
    if (stored === "light" || stored === "dark") root.setAttribute("data-theme", stored);
  } catch (err) { /* blocked site data: theme applies for this view only */ }

  Array.prototype.forEach.call(document.querySelectorAll(".theme-toggle"), function (b) {
    b.setAttribute("aria-label", current() === "dark" ? "Switch to the light theme" : "Switch to the dark theme");
    b.addEventListener("click", function () {
      var next = current() === "dark" ? "light" : "dark";
      root.setAttribute("data-theme", next);
      try { localStorage.setItem(KEY, next); } catch (err) { /* not remembered */ }
      Array.prototype.forEach.call(document.querySelectorAll(".theme-toggle"), function (o) {
        o.setAttribute("aria-label", next === "dark" ? "Switch to the light theme" : "Switch to the dark theme");
      });
    });
  });
})();
</script>
TAIL
# State the count the file actually holds, rather than asserting one in the markup.
packed="$(grep -c 'class="demo-page"' "$OUT")"
sed -i.bak "s/__PAGECOUNT__/$packed/" "$OUT" && rm -f "$OUT.bak"
echo "packed $packed pages into $OUT"
