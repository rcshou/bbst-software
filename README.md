# bbst-software

Bluebonnet Studios software development site — the public GitHub Pages catalog at
[dev.bbst.us](https://dev.bbst.us).

## What this repository is

A static catalog of Bluebonnet Studios software. It describes each tool and publishes its
release metadata; it does not host binaries. Actual builds stay in private repositories and
are distributed through their own channels.

## Structure

| File | Purpose |
| --- | --- |
| `index.html` | Full roster of every tool, plus the access and status legend |
| `about.html` | How the tools are built, releases, licensing |
| `privacy.html` | Privacy policy, published for the Microsoft Store listing |
| `business-tools.html`, `web-apps.html`, `lightroom-plugins.html`, `geoscience-tools.html` | Category pages |
| `<slug>.html` | One page per app, ten in total |
| `styles.css` | Single stylesheet shared by every page |
| `theme.js` | Theme toggle wiring |
| `CATALOG.txt` | The list of repositories to publish — hand-maintained |
| `fetch-catalog.sh` | Pulls their metadata from GitHub into the cache |
| `catalog-cache.tsv` | Fetched metadata, generated |
| `setup-repo-metadata.sh` | One-time: sets repo descriptions and topics on GitHub |
| `build.sh` | Generates every page from the cache |
| `CNAME` | Custom domain for GitHub Pages |
| `.github/ISSUE_TEMPLATE/` | Issue routing config and two issue forms |
| `.github/DISCUSSION_TEMPLATE/` | Q&A discussion form |
| `assets/` | Page ornaments, one per page |
| `make-demo.sh` | Packs the site into one navigable preview file |

## The catalog: what gets listed

`CATALOG.txt` decides what the site lists, and holds **nothing that goes stale** — one line
per app, `owner/repo` plus a pinned URL slug. Everything else is read from the repository on
GitHub, so a version bump or a reworded summary reaches the site without editing this repo.

```bash
bash setup-repo-metadata.sh --dry-run   # review the description/topics to be set
bash setup-repo-metadata.sh             # one-time: configure the repos on GitHub
bash fetch-catalog.sh                   # pull current metadata into catalog-cache.tsv
bash build.sh                           # regenerate the site from the cache
bash build.sh --refresh                 # fetch and build in one step
```

### Where each field comes from

| Field | Source on GitHub |
| --- | --- |
| Display name | repo description, the part before the em dash |
| Summary | repo description, the part after the em dash |
| Category | topic `bbst-business` / `bbst-webapps` / `bbst-lightroom` / `bbst-geoscience` |
| Platform | topics `platform-windows`, `platform-macos`, `platform-linux`, `platform-web`, `platform-gpu`, `platform-plugin`, `platform-library` |
| Version | latest release tag, leading `v` stripped |
| Status | topic `bbst-released` / `bbst-beta` / `bbst-private` / `bbst-dev`; with no topic, derived from releases — published release is *released*, prerelease is *beta*, no release is *dev* |
| Licence | detected by GitHub from the LICENSE file; a repo with none shows "Not stated" |

`bbst-private` has to be set explicitly. GitHub has no way to express "built and versioned,
handed out on request", so nothing can infer it.

The **slug is pinned in `CATALOG.txt`** rather than derived, because it becomes `<slug>.html`
and every existing link depends on it. A reworded description must never rename a page.


### One repository holding several apps

`CATALOG.txt` accepts a third field, a subpath, for a repository that ships more than one app —
the Lightroom plugin bundles:

```
rcshou/LIghtroom_plugins  similars-and-statistics  twoPlugins.lrplugin
rcshou/LIghtroom_plugins  restore-missing-photos   MissPhotos.lrplugin
```

For a subpath entry the display name and version come from that folder's `Info.lua`
(`LrPluginName` and `VERSION`) and the summary from the first sentence of its `README.md`,
because one repository description cannot describe two different plugins. Category, platform
and status still come from the repository's topics, which the plugins share.

`catalog-cache.tsv` is the fetched result, committed so the site can be rebuilt offline and
so a diff shows exactly what moved upstream when a release lands. Do not edit it by hand.

Long-form page copy — the lede and body sections — stays in `tool_lede` and `tool_prose` in
`build.sh`, keyed by slug. It is written for a public audience rather than for developers, so
it is not a README and does not come from the app repo. The build warns about any listed app
with no page copy yet.

## Editing the site

**Do not hand-edit the generated HTML.** All sixteen pages are produced by `build.sh`, so
the roster, the rail counts, the category pages and the tool pages cannot drift apart.

To **add an app**: create its repository, set its description and topics as above, add one
line to `CATALOG.txt`, write its `tool_lede`, `tool_meta_desc` and `tool_prose` in
`build.sh`, then `bash build.sh --refresh`.

To **change a version, summary, name, platform, category, status or licence**: change it on
GitHub — a release, the description, the topics, the LICENSE file — then `bash build.sh
--refresh`. Nothing in this repository needs touching.

To **stop listing an app**: remove its line from `CATALOG.txt` and note why in the section
at the bottom of that file. Its `<slug>.html` is left behind; delete it deliberately, since
removing a published page breaks any link to it.

Counts, navigation and cross-links follow the catalog automatically.

## Design

The site uses the "Instrument Panel" direction: a technical shell, a persistent category
rail, and the catalog rendered as a dense roster table rather than a card grid, so the list
stays readable as it grows.

The palette is taken from *Lupinus texensis* itself:

| Token | Colour | Taken from |
| --- | --- | --- |
| `--blue` | `#1E3FB8` / `#6E8CFF` | the royal-cobalt petal — the single accent |
| `--bg`, `--panel` | `#F3F2E7`, `#FCFBF4` | the pale banner spot and unopened buds |
| `--ink` | `#10163A` | the near-black blue in the deepest petals |
| `--grass` | `#2A6E22` / `#6FCC4E` | the grass it grows in — available, positive |
| `--bud` | `#7A5C00` / `#DFC24A` | the yellow-green raceme tip that has not opened |
| `--banner` | `#B0246E` / `#F06BA8` | the magenta a banner spot turns after pollination |

The status colours follow the flower's own life cycle: grass for what is available, bud
yellow for what has not opened, pollinated magenta for what is handed out on request, and
no colour at all for what has not started.

Both themes are defined purely as tokens at the top of `styles.css`; no component below the
token blocks references a colour literal, so a palette change is a token edit. Every
foreground/background pair was checked against WCAG AA and clears it on both themes.


| Face | Role |
| --- | --- |
| Newsreader (serif) | headings, ledes, section labels, the studio name — the voice |
| Archivo (sans) | interface text, navigation, table headers, chips, buttons |
| JetBrains Mono | data that lines up in a column: versions, platforms, counts |

Mono is notation, not decoration. It appears in exactly six rules, all of them
tabular values. Section labels and small headings are set in serif italic rather than
letter-spaced uppercase mono, which is what previously gave the site its instrument-panel
rigidity. Chips and buttons are pills in sentence case; panels, cards and the aside carry a
7px radius; hairlines are a step lighter and transitions a step slower.

The layout is unchanged: same grid, same rail width, same table columns, same spacing scale.

Both themes are defined purely as tokens at the top of `styles.css`; no component below the
token blocks references a colour literal, so a palette change is a token edit. Every
foreground/background pair was checked against WCAG AA and clears it on both themes.

The theme follows the operating system until the reader presses the toggle, after which the
choice is remembered in `localStorage` under `bbst-theme`.

## Status vocabulary

| Status | Meaning |
| --- | --- |
| Released | Generally available; version number and download published here |
| Beta | Feature-complete and usable, still collecting reports |
| Private release | Built, versioned and in use; distributed on request rather than published |
| In development | Being built; described so the catalog is honest, nothing to hand out yet |

## Licensing note

Tool pages state each application's licence, as declared by its repository. Copyright is
Bluebonnet Studios throughout. Tools whose repositories carry no LICENSE file currently show
"Not stated" rather than an assumed licence — update `tool_license` in `build.sh` once those
repositories declare one.

## Page art

One ornament per page, sixteen pages, four assets in `assets/`. Each is placed by its
shape rather than dropped in uniformly:

| Asset | Shape | Placement | Pages |
| --- | --- | --- | --- |
| `bluebonnet-header.png` | wide arch, opens downward | crowns the page head | home, Business, Lightroom |
| `bluebonnet-footer.png` | wide symmetric garland | tailpiece closing the page | About, OCR, Geoscience |
| `bluebonnet-side-left.png` | tall stem | runs down the aside column | six tool pages |
| `bluebonnet-side-right.png` | tall stem | runs down the aside column | six tool pages |

All four are RGBA, so they sit on either theme's ground with no per-theme variant. Every
ornament is decorative: empty `alt`, `aria-hidden="true"`, and carrying nothing the text
does not already say. All but the home-page crown are lazy-loaded, and the tall stems are
hidden below 1000px, where the aside stacks under the prose and the margin they live in
no longer exists.

Assignment lives in `art_file` in `build.sh`. To change which ornament a page gets, edit
that case statement and rerun the build.

### Page art assets

The four ornaments are stored at twice their displayed width — 1280px for the crown,
860px for the tailpiece, 380px for the column stems — which covers high-DPI displays
without carrying bytes nobody sees. They were downsampled from the originals on
2026-08-30, taking the set from 6.4 MB to 1.7 MB. The originals remain in git history
at commit `5162067`.

Regenerating requires Pillow in a local environment, which `.gitignore` excludes:

```bash
py -3 -m venv .venv
.venv/Scripts/python.exe -m pip install "Pillow==11.3.0"
```

If a stem or the crown is ever replaced, update the pixel dimensions in `art_file`
in `build.sh` to match, so the space each page reserves still matches the file and
nothing shifts as it loads.

## Contact and Q&A

Three routes, each for a different kind of message:

| Route | For | Where |
| --- | --- | --- |
| GitHub Discussions, Q&A | How a tool works, whether it fits, what it does not do | `/discussions/new?category=q-a` |
| GitHub Issues | Catalog corrections and defects in a build you have | `/issues/new/choose` |
| Email | Private release requests, anything that should not be public | dev@bbst.us |

Questions are answered in the open so the answer stays searchable. Each tool page carries an
"Ask about *tool*" link that opens a discussion with the title prefilled.

### Repository setup required

**Discussions must be enabled** for the Q&A links to resolve: repository *Settings →
General → Features → Discussions*. The links target the `q-a` category slug, which GitHub
creates by default; if the category is renamed, update `REPO` usage in `build.sh`.

Templates in `.github/` shape what arrives:

| File | Effect |
| --- | --- |
| `ISSUE_TEMPLATE/config.yml` | Disables blank issues; points questions at Discussions and release requests at email |
| `ISSUE_TEMPLATE/catalog-correction.yml` | Form for wrong metadata, broken links, rendering and accessibility problems |
| `ISSUE_TEMPLATE/tool-defect.yml` | Form for a defect in a build, with tool, version, OS, expected/actual and diagnostics |
| `DISCUSSION_TEMPLATE/q-a.yml` | Question form with a tool dropdown and a "what are you trying to do" field |

`DISCUSSION_TEMPLATE/q-a.yml` takes effect only once Discussions is enabled and only for the
category whose slug matches the filename. The tool dropdowns list the ten published tools —
keep them in step with `CATALOG.txt` when the catalog changes, and never add an application
that is not published: this repository is public and the application repositories are not.

## Release workflow

- Create releases in private repos for the binaries themselves.
- Publish release metadata here: version, platform, status, and release notes.
- Use GitHub Actions or a sync workflow to update the `TOOLS` block and rerun `build.sh`
  when a private release ships.
- For public assets, link their URLs from the relevant tool page.
