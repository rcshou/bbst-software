# Downloads, the Lightroom split, and six new catalog entries

**Date:** 2026-09-16
**Scope:** `bbst-software`. Supersedes the task status of
`2026-08-31_catalog_content_and_release_metadata.md` only where stated below; its open items
A, C, D, E, G, H and I are untouched by this pass and still stand.

## Purpose

Records a pass that did three things on top of the 2026-08-31 catalog redesign: brought over
the downloads feature built on a separate local line of work, replaced the archived
`LIghtroom_plugins` entries with the repositories it was split into, and listed six more apps.

## Current state, and how it was verified

- `CATALOG.txt` lists 16 apps in four categories. `bash build.sh --refresh` ran against the
  live GitHub API and the public `rcshou/bbst-downloads` repository; the build writes 25 pages.
- All 25 pages parse with balanced tags (Python `html.parser`), and every internal `href`,
  `src` and fragment resolves to an existing file and id.
- Two consecutive builds are byte-identical (compared by SHA-256).
- `tests/fetch-catalog.test.sh` (6 checks) and `tests/fetch-downloads.test.sh` pass. The
  catalog test fails against the previous `fetch-catalog.sh`, on the prefixed-tag case.
- Rendering was checked in headless Edge on Windows 11 at 1440px: home, Lightroom category,
  Find Similar Photos, PDF Processor, downloads and privacy.

## What changed in this pass

- Downloads: `fetch-downloads.sh` (now reads slugs and status from `CATALOG.txt` and versions
  from the three-column cache), `downloads.html`, `download-<slug>.html`, the Downloads nav
  link, Download buttons, `downloads-cache.tsv`, `downloads-docs/`, the lettered home crown.
- Catalog: the four split Lightroom repositories, Face Assistant, PDF Processor for
  Embeddings and vCard Cleaner, with page copy, licensing sections and privacy entries.
  APK Finder is `released`. `similars-and-statistics.html` is deleted, by decision.
- Fixes: prefixed release tags in `fetch-catalog.sh`; the silent `set -e` exit in `build.sh`.

## Later the same day

A second pass, on the owner's decisions, closed several items here and in item G of the
2026-08-31 handoff:

- **Narrow screens — resolved** (open item 1 below, and item G's 320px reflow). At 640px and
  below the navigation takes its own row. Measured in Edge over HTTP on 16 pages at 320px,
  390px and 1280px: no horizontal overflow, and the theme toggle keeps 30×30px. The 390px
  clipping noted under Unverified was a capture artifact; the same measurement at 390px
  showed no overflow before the change either.
- **Versions — resolved** (open item 3) with an optional ninth `CATALOG.txt` column, used
  only when nothing can be fetched and marked "no published release" on the tool page.
  vCard Cleaner has no version anywhere and still shows "—".
- **Item G, CSP — done**: a `<meta>` policy on every page, no inline script or style.
- **Item G, Google Fonts — done**: fonts self-hosted in `assets/fonts/`.
- **Item G, section labels — done**: they are `<h2>` headings.
- **Item G, still open**: `assets/bluebonnet_art.png` (kept, by decision), the tailpiece
  question, and the home-page crown's size.
- The local branches `backup/2026-09-16-local-catalog`, `catalog-split`, `site-rebuild` and
  `pre-rewrite-backup-20260830` were deleted at the owner's request; their commits remain
  only in the local reflog until it expires.
- Tests: `tests/build.test.sh` added. All three suites pass.

## Open items

1. ~~**Narrow screens.**~~ Resolved later the same day; see above.
2. **Status of the new entries is an editorial call** made in this pass: the three split
   plugins are `private`, Face Assistant `beta` (it has a published GitHub prerelease),
   PDF Processor and vCard Cleaner `dev`. Change them in `CATALOG.txt` if they are wrong.
3. ~~**Versions for PDF Processor, vCard Cleaner and Bakmil Metro show "—"**~~ Resolved
   later the same day for the first two; vCard Cleaner has no version to show.
4. **Check Capture Year vs Folder is written for Windows too**, but has only been tested on a
   Mac, so the catalog lists macOS only. Add Windows to its platform once it is tested there.

## Unverified

- Real phone rendering on a device. Layout was measured in Edge at phone widths, not on a
  phone.
- Dark theme appearance. The dark theme was applied in the later measurement, but no dark
  screenshot was reviewed.
- macOS rendering of the site.

## Decisions

- The downloads feature was ported onto the 2026-08-31 redesign rather than merged, because
  the two lines disagreed on how the catalog is stored. The superseded local commit was never
  pushed, and its backup branch was later deleted at the owner's request.
- APK Finder stays under Web & Mobile; the separate Android category of the local line was
  dropped.
- Licensing restrictions on bundled or separately downloaded components are published on the
  tool pages rather than holding the tools back.
- Single-plugin Lightroom repositories use the `subpath` column so their version comes from
  `Info.lua`; none publishes release tags.

## Next steps

1. Review the statuses in open item 2.
2. The remaining parts of item G of the 2026-08-31 handoff.
