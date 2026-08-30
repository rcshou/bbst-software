# Changelog

All notable changes to the public catalog site are recorded here.

## [Unreleased]

### Added
- **`privacy.html`** — a privacy policy covering every listed application and this site,
  published because the Microsoft Store listing for Project2Excel needs one at a public URL.
  It carries a per-application table of network use rather than a blanket claim, since four
  of the ten applications do contact a network: PDF Classifier and Geocrawler check for
  updates, SEG-Y Coordinate Security can draw opt-in map tiles, and Location Caption
  Assistant sends photo coordinates to OpenStreetMap. The Project2Excel section is anchored
  at `#project2excel` and is adapted from that project's own `docs/PRIVACY.md`.
  Every claim was verified against the application sources on 2026-08-30.
- The site's own third-party requests are disclosed: Google Fonts, GitHub Pages hosting, and
  the `bbst-theme` value kept in the reader's browser storage.
- Privacy is linked from the footer of every page.
- **Page art**: one ornament on each of the sixteen pages, drawn from the four Arts and
  Crafts bluebonnet illustrations in `assets/`. Placed by shape — the wide arch crowns the
  home page head, the wide garland closes About and two category pages as a tailpiece, and
  the two tall stems run down the aside column of the ten tool pages.
- All ornaments are decorative: empty `alt`, `aria-hidden="true"`, lazy-loaded except the
  above-the-fold crown, and hidden below 1000px where the aside column disappears. All four
  assets are RGBA, so one file serves both themes.
- `make-demo.sh` now inlines the ornaments as data URIs on four CSS classes, so the packed
  single-file preview shows the art that relative paths cannot resolve at one URL.
- **Contact routes**: `dev@bbst.us` for release requests and anything private, GitHub
  Discussions Q&A for questions answered in the open, GitHub Issues for catalog corrections
  and defects. All three appear in the access section on the home page; email and Discussions
  also sit in the footer of every page.
- Each tool page carries an "Ask about <tool>" link that opens a discussion with the title
  prefilled, plus the email address, in its at-a-glance panel.
- `.github/ISSUE_TEMPLATE/config.yml` disables blank issues and routes questions to
  Discussions and release requests to email; `catalog-correction.yml` and `tool-defect.yml`
  are issue forms; `DISCUSSION_TEMPLATE/q-a.yml` is the question form. Tool dropdowns list
  the ten published tools and were cross-checked against the catalog data.
- **Repainted in the real bluebonnet palette**, taken from photographs of the flower rather
  than approximated: royal-cobalt petals as the accent, the pale banner spot and unopened
  buds as the light ground, the near-black blue of the deepest petals as ink, vivid grass
  green, yellow-green bud, and the magenta a banner spot turns after pollination.
- Status colours now follow the flower's life cycle: grass for available, bud yellow for
  not yet open, pollinated magenta for private release, no colour for not started. Private
  release previously shared the neutral grey of "In development" and was hard to tell apart.
- The brand mark gained its banner spot — a cobalt petal with a pale centre on a grass stem.
- Every foreground/background pair in both themes was checked against WCAG AA contrast and
  clears it; the lowest is 4.6:1.
- **Light theme**, and a theme toggle in the top bar. Both themes are defined at token level
  only, so no component carries a colour literal.
- Theme handling in `theme.js`, with a small inline snippet in each page head that applies
  the stored choice before first paint. No stored value means "follow the operating system",
  which is the default; a blocked `localStorage` degrades to per-view only.
- **Twelve tool pages**, one per application, each with a long-form description, an
  "instead of" section explaining what the tool is an alternative to, and an at-a-glance
  panel carrying version, status, platform, licence, copyright holder and category.
- **`about.html`** — how the tools are built, the shared update mechanism, licensing, and
  where the studio name comes from.
- `build.sh`, which generates all sixteen pages from one shared shell and one catalog data
  block, so the roster, rail counts and category pages cannot drift apart.
- `make-demo.sh`, which packs the whole site into one navigable HTML file for preview, with
  per-page id namespacing and a small in-page router so every link works.

### Changed
- **Page ornaments downsampled**, taking the asset set from 6.4 MB to 1.7 MB with no
  visible change: each is now stored at twice its displayed width rather than up to
  2152px. The home page's above-the-fold crown drops from 2.1 MB to 763 KB. The pixel
  dimensions each page reserves were updated to match, so nothing shifts as it loads.
  Originals remain in git history at commit `5162067`.
- **Catalog rebuilt to the owner's list of ten apps.** Added Bakmil Metro Schedule, Location
  Caption Assistant, and the two Lightroom plugins held inside `LIghtroom_plugins`. Entries
  that are not on the published list were removed.
- **The OCR category is retired and Web Apps replaces it.** Nothing on the list is an OCR
  tool; PDF Classifier stays in Business, where it already sat. `ocr-tools.html` is deleted
  and `web-apps.html` takes its place in the rail.
- Deleted the tool pages whose apps are not on the published list, along with their page
  copy in `build.sh`. Nothing in this repository names an unpublished application.
- `CATALOG.txt` gained a third field, a subpath, so one repository can supply several apps.
  For those entries name and version come from the plugin's `Info.lua` and the summary from
  its `README.md`.
- **The catalog is no longer hand-maintained metadata.** `CATALOG.txt` now holds one line
  per app — `owner/repo` plus a pinned URL slug — and nothing that goes stale. Display name,
  summary, category, platform, version, status and licence are read from the repository on
  GitHub by `fetch-catalog.sh` into `catalog-cache.tsv`, which `build.sh` reads. A version
  bump or a reworded summary now reaches the site by re-running the fetch.
- The slug stays pinned in `CATALOG.txt` rather than derived, because it becomes
  `<slug>.html` and a reworded description must never rename a published page.
- `tool_license` now reads the catalog rather than duplicating a case statement.
- Added `setup-repo-metadata.sh`, a one-time script that sets each repository's description
  and topics on GitHub, so the catalog can be populated from the repositories themselves.
- **Softened the visual treatment from technical to editorial, with the layout untouched.**
  Newsreader (serif) now carries headings, ledes, section labels and the studio name;
  Archivo runs the interface; JetBrains Mono is reserved for tabular data and appears in
  six rules rather than throughout. Letter-spaced uppercase mono labels — the main source of
  the instrument-panel rigidity — are gone in favour of serif italic in sentence case.
- Chips and buttons are now pills in sentence case; panels, cards and the aside carry a 7px
  radius; hairlines are a step lighter, shadows softer and wider, transitions slower.
- Grid, rail width, table columns, section spacing and every breakpoint are unchanged.
- Catalog expanded from 8 placeholder entries to **12 real tools** across the four
  categories, with descriptions, versions, platforms and licences taken from each
  application's own repository rather than invented.
- Category pages now link each tool to its own page and show licence in the fact strip.
- On a tool page the rail highlights its category with a class rather than
  `aria-current="page"` — the category page is related, not the page being viewed.

### Notes
- Catalog metadata is read from each application's own repository. Where a repository has not
  yet declared a description, topics or a release, the catalog shows the conservative value:
  no version, "Not stated" for an undeclared licence, and "In development" for an application
  with no published release.
- Statuses reflect what is actually available rather than how finished the work is. "Private
  release" means built, versioned and in use, distributed on request rather than published.
- Location Caption Assistant is listed as Beta because its own documentation states the
  Lightroom-facing code has not yet been exercised inside Lightroom. Its page says so plainly.

## [0.1.0]
- Scaffold initial GitHub Pages catalog site for Bluebonnet Studios software projects.
