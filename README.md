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
| `index.html` | Category panels and the access and status legend — the full roster lives on the category pages |
| `about.html` | How the tools are built, releases, licensing |
| `privacy.html` | Privacy policy, published for the Microsoft Store listing |
| `business-tools.html`, `web-apps.html`, `lightroom-plugins.html`, `geoscience-tools.html` | Category pages, each carrying its category's roster |
| `<slug>.html` | One page per app, eleven in total |
| `styles.css` | Single stylesheet shared by every page |
| `theme.js` | Theme toggle wiring |
| `CATALOG.txt` | The catalog: what is listed, and what the site says about it. Authored |
| `fetch-catalog.sh` | Refreshes versions and licences from GitHub |
| `catalog-cache.tsv` | Fetched versions and licences, generated |
| `build.sh` | Generates every page by joining the two |
| `CNAME` | Custom domain for GitHub Pages |
| `.github/ISSUE_TEMPLATE/` | Issue routing config and two issue forms |
| `.github/DISCUSSION_TEMPLATE/` | Q&A discussion form |
| `assets/` | Page ornaments, one per page |
| `make-demo.sh` | Packs the site into one navigable preview file |
| `docs/handoff/` | Work-state records: what is open, unverified, or waiting on a decision |

## The catalog: what gets listed

`CATALOG.txt` is the catalog. It decides what the site lists **and what the site says about
it** — one tab-separated line per app:

```
slug   repo   subpath   name   category   platform   status   summary
```

Everything in it is authored and reviewed. Only two facts about an app change upstream
without anyone editing this repository — its **latest release version** and its **declared
licence** — and those are the only two things `fetch-catalog.sh` pulls from GitHub, into
`catalog-cache.tsv`. `build.sh` joins the two on the slug.

```bash
bash fetch-catalog.sh    # refresh versions and licences from GitHub
bash build.sh            # regenerate the site
bash build.sh --refresh  # do both
```

### Where each field comes from

| Field | Source |
| --- | --- |
| Display name, subtitle, category, platform, status, summary | `CATALOG.txt` and `tool_subtitle` in `build.sh` |
| Lede, body copy, meta description, release box | `tool_lede`, `tool_prose`, `tool_meta_desc`, `tool_release_notes` in `build.sh`, keyed by slug |
| Version | latest GitHub release; failing that, the highest version-shaped git tag; failing that, the last cached value |
| Licence | `license.spdx_id` on GitHub; a repo with no LICENSE shows "Not stated" |

A tag pushed without a GitHub Release still identifies a version, and the releases API
returns 404 for it — so `fetch-catalog.sh` falls back to the repository's tags and takes the
highest bare `v1.2.3` tag, warning as it does so. Prefixed tags such as `twoplugins-v1.8.1`
are ignored: they version one app inside a shared repository, not the repository itself.

Status is set deliberately rather than inferred. GitHub has no way to express "built and
versioned, handed out on request", which is what most of this catalog is, so nothing can
derive it — and a status that silently flipped because a draft release was published would
be worse than one that is simply stated.

The **slug is pinned in `CATALOG.txt`** rather than derived, because it becomes `<slug>.html`
and every existing link depends on it. A reworded name must never rename a page. `build.sh`
refuses a slug containing anything but lowercase letters, digits and hyphens.

Catalog values are HTML-escaped once, as they enter the build, so an ampersand or an angle
bracket in a name or summary reaches the page as text rather than as markup.

### One repository holding several apps

The `subpath` column lists one app out of a repository that ships several — the Lightroom
plugin bundles:

```
similars-and-statistics   rcshou/LIghtroom_plugins   twoPlugins.lrplugin   …
restore-missing-photos    rcshou/LIghtroom_plugins   MissPhotos.lrplugin   …
```

A subpath entry takes its version from that folder's `Info.lua` (`major`, `minor`,
`revision`) rather than from a repository release tag, because one tag cannot version two
plugins separately. Everything else comes from `CATALOG.txt` like any other row.

`catalog-cache.tsv` is the fetched result — three columns, `slug`, `version`, `license` —
committed so the site can be rebuilt offline and so a diff shows exactly what moved upstream
when a release lands. Do not edit it by hand.

## Editing the site

**Do not hand-edit the generated HTML.** All eighteen pages are produced by `build.sh`, so
the roster, the rail counts, the category pages and the tool pages cannot drift apart.

To **add an app**: add one tab-separated line to `CATALOG.txt`, write its `tool_lede`,
`tool_meta_desc` and `tool_prose` in `build.sh`, then `bash build.sh --refresh`.

To **change a name, summary, platform, category or status**: edit that field in
`CATALOG.txt` and run `bash build.sh`. These are the site's own words about a tool, so they
are decided here and nowhere else.

To **pick up a new release**: `bash build.sh --refresh`. The version and licence come from
GitHub; nothing else in the row is touched. Check the `catalog-cache.tsv` diff before
committing — it is small by design, so a surprise in it is worth reading.

To **stop listing an app**: remove its line from `CATALOG.txt` and note why in the section
at the bottom of that file. Its `<slug>.html` is left behind; delete it deliberately, since
removing a published page breaks any link to it.

Counts, navigation and cross-links follow the catalog automatically.

## Design

The site uses the "Instrument Panel" direction: a technical shell, a persistent category
rail, and the catalog rendered as a dense roster table rather than a card grid, so the list
stays readable as it grows.

The **home page names the four categories rather than listing every tool.** Each panel
carries the category's pitch, its count and its tool names, and links to the category page
where that roster lives. Category copy is `cat_pitch` (the panel line) and `cat_head` (the
category page's heading, intro and meta description), both in `build.sh` and both keyed by
the category name **as it appears after HTML escaping** — so the key for `Web & Mobile` is
`Web &amp; Mobile`. A pattern that spells the unescaped name matches nothing and yields a
blank panel and an empty heading; `check_copy` warns when that happens.

Each tool page carries a **subtitle** (`tool_subtitle`) under its name, and where the
project keeps user-facing release notes, a **release box** (`tool_release_notes`) beside
the At a glance panel. Both are optional — a tool without them simply renders neither.

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
token blocks references a colour literal, so a palette change is a token edit.

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

Every foreground/background pair was measured against WCAG AA on 2026-08-31 and clears it
on both themes for normal text. The narrowest margin is `--dimmer`, which carries the small
metadata labels: 4.75:1 on the light ground, 5.14:1 on the dark panel. `--dimmer` previously
sat at 2.96:1 in the light theme, below even the large-text floor, and the claim that the
palette cleared AA was wrong until it was corrected.

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

One ornament per page, eighteen pages, four assets in `assets/`. Each is placed by its
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
- When a release ships, run `bash build.sh --refresh` and commit the `catalog-cache.tsv`
  diff alongside the regenerated pages.
- For public assets, link their URLs from the relevant tool page.

Automating the refresh in CI is possible but not free: most of the listed repositories are
private, so a workflow would need a token that can read them, stored as a secret in this
public repository. Running the fetch locally avoids that trade entirely, which is why it is
a command rather than an Action.
