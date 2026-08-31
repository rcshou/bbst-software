# Changelog

All notable changes to the public catalog site are recorded here.

## [Unreleased]

### Fixed
- **The site no longer describes itself as desktop-only.** The home page led with "Desktop
  tools that do one job properly", and the About page claimed "every application in this
  catalog is a native desktop program — ... two as Lightroom plugins". Neither was true: of
  eleven applications, six are desktop, three are Lightroom Classic plugins, one is a web app
  and one is an Android app. The headline is now "One job each, wherever the work happens",
  and About states the actual split — five PySide6 applications and one Tauri, plus three
  plugins, a web app and an Android app. The framework attributions were verified by code
  search rather than assumed.

### Added
- **APK Finder** joins the catalog — a Google-independent Android app for finding, checking
  and installing APKs on devices with no Play Services, built for Chinese-market car head
  units and equally at home on degoogled phones and custom ROMs. It has no published release
  yet, so it is listed as a private release and shows no version until one is tagged.
- **A subtitle on every tool page**, under the name, saying what the tool does for a reader
  who has only ever seen its name. Names and slugs stay pinned; the subtitle carries the
  explanation.
- **A latest-release box** beside the At a glance panel on the five tools whose projects keep
  user-facing release notes, written in the reader's terms rather than the maintainer's. The
  two boxes travel with the panel as one sticky unit.
- `check_copy` now warns when a category has no `cat_pitch` or `cat_head`. Category copy is
  keyed by the escaped category name, so renaming a category to one containing `&` silently
  produced a blank panel and an empty page heading until this check existed.

### Fixed
- **A version tagged without a GitHub Release is no longer invisible.** `fetch-catalog.sh`
  read only `releases/latest`, which returns 404 for a bare tag, so APK Finder — a production
  application tagged `v0.20.3` — was published with no version at all, and Markdown Renderer
  showed the right version only because the cache happened to hold it. The fetch now falls
  back to the highest version-shaped tag and says so. Prefixed tags such as
  `twoplugins-v1.8.1` are ignored, since they version one app inside a shared repository.

### Changed
- **The home page names the four categories instead of listing every tool.** The roster moved
  to the category pages; the home page carries a panel per category with its pitch, count and
  tool names. A flat roster of eleven was already long, and it does not get better.
- **Every tool page was rewritten as a full product page** — what it is for, what it actually
  does, and what it deliberately does not do — written from each project's own README, user
  guide and release notes rather than from its repository description.
- **`Web Apps` is now `Web & Mobile`**, holding the Bakmil PWA and APK Finder. The page stays
  `web-apps.html`, so no published link breaks.
- The home page's tool, category and private-release counts are derived rather than hardcoded.

### Changed
- **The catalog is authored again, and only versions and licences are fetched.** An audit
  found the previous arrangement was circular: `setup-repo-metadata.sh` pushed each
  repository's description to GitHub, and `fetch-catalog.sh` read the same string back as
  though GitHub were upstream of it. Name, category, platform, status and summary now live
  in `CATALOG.txt`, which became tab-separated with eight columns. `fetch-catalog.sh` keeps
  only the two facts that genuinely change without anyone editing this repository — the
  latest release tag and the declared licence — and `catalog-cache.tsv` shrank to three
  columns. `build.sh` joins the two on the slug. The site rebuilt byte-identical across all
  seventeen pages, so this changed how the catalog is maintained and nothing it says.
- Retiring the round-trip also retires the contracts that only existed to serve it: the
  `"Name — summary"` em-dash description format, the `bbst-*` category, platform and status
  topics on ten remote repositories, and the derivation of status from release state.

### Removed
- `setup-repo-metadata.sh`. Its purpose was to write the descriptions and topics that
  `fetch-catalog.sh` read; nothing reads them now. Recoverable from git history if the
  topics turn out to be worth maintaining for GitHub discoverability.

### Fixed
- **Catalog values are HTML-escaped** as they enter the build. Previously every field was
  interpolated raw, so a description containing `&` or `<` produced invalid markup, and
  markup in a name or summary was emitted intact into `<title>`, `<h1>` and the roster —
  verified by rebuilding with a deliberately malformed catalog row.
- **A pipe character in a summary no longer truncates it.** The build re-packed the
  tab-separated cache into pipe-delimited records, so a summary reading "Import | export"
  published as "Import", silently. The build now reads tab-separated throughout.
- `build.sh` refuses a slug containing anything but lowercase letters, digits and hyphens,
  since a slug becomes both a filename and a URL.
- **`--dimmer` now clears WCAG AA in both themes.** It was `#868CA4` on the light ground —
  2.96:1, below even the large-text floor — and `#6D7699` on dark panels at 3.87:1, while
  carrying the 11–13px metadata labels: the rail counts, the mobile roster's column labels,
  and the aside's Version, Status, Platform, Category and License rows. Now `#646A82` and
  `#828BAD`, measuring 4.75:1 and 5.14:1. The README's claim that every pair cleared AA was
  wrong until this change.
- **`make-demo.sh` runs on macOS.** `base64 -w0 <file>` is GNU syntax that BSD base64
  rejects, so the script aborted at the first ornament, exited 64, and left a stylesheet-only
  file containing no pages at all.
- `make-demo.sh` derives its page list from `CATALOG.txt` instead of a hardcoded list that
  had fallen a page behind, and its badge counts the pages it packed rather than asserting
  a number. It packed 16 of 17 pages, omitted `privacy.html`, and claimed 18.
- The build's success line names `privacy.html` and reports the file count. Omitting it is
  how the README came to describe a sixteen-page site that has seventeen pages.

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
- **Page art**: one ornament on each of the seventeen pages, drawn from the four Arts and
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
- Every foreground/background pair in both themes was checked against WCAG AA contrast.
  The check missed `--dimmer`, which sat at 2.96:1 in the light theme; see the correction
  under Fixed above. With that token raised, the narrowest pair is 4.75:1.
- **Light theme**, and a theme toggle in the top bar. Both themes are defined at token level
  only, so no component carries a colour literal.
- Theme handling in `theme.js`, with a small inline snippet in each page head that applies
  the stored choice before first paint. No stored value means "follow the operating system",
  which is the default; a blocked `localStorage` degrades to per-view only.
- **Ten tool pages**, one per application, each with a long-form description, an
  "instead of" section explaining what the tool is an alternative to, and an at-a-glance
  panel carrying version, status, platform, licence, copyright holder and category.
- **`about.html`** — how the tools are built, the shared update mechanism, licensing, and
  where the studio name comes from.
- `build.sh`, which generates all seventeen pages from one shared shell and the catalog
  data, so the roster, rail counts and category pages cannot drift apart.
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
