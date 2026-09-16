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

## Open items

1. **Narrow screens.** The top navigation now has four links, so at phone widths it wraps to
   two rows. This compounds item G of the 2026-08-31 handoff (320px reflow). `build.sh`,
   `page_open`; `.topbar-inner` in `styles.css`.
2. **Status of the new entries is an editorial call** made in this pass: the three split
   plugins are `private`, Face Assistant `beta` (it has a published GitHub prerelease),
   PDF Processor and vCard Cleaner `dev`. Change them in `CATALOG.txt` if they are wrong.
3. **Versions for PDF Processor, vCard Cleaner and Bakmil Metro show "—"**: none has a
   release or a bare version tag (item A/C of the earlier handoff).
4. **Check Capture Year vs Folder is written for Windows too**, but has only been tested on a
   Mac, so the catalog lists macOS only. Add Windows to its platform once it is tested there.

## Unverified

- Real phone rendering. Headless Edge clipped the right edge at a 390px window on both this
  build and the previous one, which suggests a capture artifact rather than a layout fault,
  but that was not confirmed on a device.
- Dark theme rendering of the new pages; only the light theme was captured.
- macOS rendering of the site.

## Decisions

- The downloads feature was ported onto the 2026-08-31 redesign rather than merged, because
  the two lines disagreed on how the catalog is stored. The superseded local commit is kept on
  the local branch `backup/2026-09-16-local-catalog`, never pushed.
- APK Finder stays under Web & Mobile; the separate Android category of the local line was
  dropped.
- Licensing restrictions on bundled or separately downloaded components are published on the
  tool pages rather than holding the tools back.
- Single-plugin Lightroom repositories use the `subpath` column so their version comes from
  `Info.lua`; none publishes release tags.

## Next steps

1. Decide open item 1 together with item G of the 2026-08-31 handoff.
2. Review the statuses in open item 2.
