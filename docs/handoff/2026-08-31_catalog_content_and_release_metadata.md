# Catalog content rewrite, and the release metadata it depends on

**Date:** 2026-08-31
**Scope:** `bbst-software` (this repository) and the eleven application repositories it lists.
**Status:** the site work is complete and committed to the branch
`catalog-content-rewrite`, which has not been pushed or merged — `main` is protected. The
open items are almost all in the *application* repositories, not here.

---

## Purpose

This pass rewrote the site's content — a category-led home page and a full product page per
application — and, in doing so, exposed how much the catalog depends on release metadata that
several application repositories do not publish. That dependency is the substance of this
handoff. The site is finished; what it can *say* about six of the eleven applications is
limited by what those repositories expose.

Read this before changing `CATALOG.txt`, `fetch-catalog.sh`, or any per-tool copy in
`build.sh`.

---

## Current state

### What works, and how it was verified

- **The site builds reproducibly.** `bash build.sh` produces all 18 pages; two consecutive
  runs are byte-identical (compared by checksum).
- **All 18 pages are well-formed HTML.** Verified with a real parser (Python `html.parser`),
  checking tag balance and nesting — not by counting tags.
- **Every internal link and fragment resolves.** Verified by crawling every `href` and `src`
  on every page against a local server and checking for HTTP 200.
- **`fetch-catalog.sh` works against the live GitHub API.** Run authenticated as `rcshou`;
  exit 0; the only change was correcting PDF Classifier `1.0.2` → `1.0.6`.
- **All eleven repositories are reachable** with the current `gh` login (scopes include
  `repo`).
- **WCAG AA contrast** was measured from the stylesheet tokens; the narrowest normal-text
  pair is 4.75:1.

### What the catalog publishes right now

| Slug | Version shown | Licence shown | Status |
| --- | --- | --- | --- |
| `project2excel` | 1.0.2 | Apache-2.0 | private |
| `pdf-classifier` | 1.0.6 | Apache-2.0 | private |
| `markdown-renderer` | 1.9.6 | Apache-2.0 | private |
| `bakmil-metro` | — | Apache-2.0 | released |
| `similars-and-statistics` | 1.8.1 | Not stated | private |
| `restore-missing-photos` | 1.22.0 | Not stated | private |
| `location-caption` | 0.1.10 | Not stated | beta |
| `geocrawler` | 2.19.1 | Apache-2.0 | private |
| `segy-coordinate-security` | 0.16.1 | Apache-2.0 | private |
| `apk-finder` | 0.20.3 | Apache-2.0 | private |
| `cassandra-risking` | 0.4.3 | Not stated | private |

---

## What changed in this pass

1. **Architecture.** The catalog is authored again. `CATALOG.txt` became tab-separated with
   eight columns and now holds name, category, platform, status and summary.
   `fetch-catalog.sh` was cut down to the only two genuinely upstream facts — latest release
   version and declared licence — and `catalog-cache.tsv` shrank to three columns.
   `setup-repo-metadata.sh` was deleted (authorised): it pushed descriptions and topics that
   nothing reads any more.
2. **Home page** now presents four category panels; the roster moved to the category pages.
3. **All eleven tool pages rewritten** as full product pages, from each project's own README,
   user guide and release notes.
4. **Subtitles** on every tool page; **release boxes** on the five whose projects keep
   user-facing release notes.
5. **APK Finder added**; `Web Apps` renamed to `Web & Mobile` (page filename unchanged, so no
   published link breaks).
6. **Defects fixed:** HTML escaping of catalog values; pipe-delimiter truncation; slug
   validation; `--dimmer` contrast in both themes; `make-demo.sh` on macOS; stale page counts.

---

## Open items

### A. Four repositories have no release *and* no tag

`Project2Excel`, `Bakmill_PWA`, `LR_location_caption`, `seis_coord` have zero GitHub releases
and zero git tags. Their version on the site therefore comes from whatever
`catalog-cache.tsv` last held, with no upstream source of truth, and it will not change no
matter what ships.

The clearest symptom: **`project2excel` publishes version 1.0.2, which exists nowhere
upstream.** The repository's own `CHANGELOG.md` tops out at 0.8.2, and there is no tag or
release to corroborate 1.0.2. It is a cached value whose origin can no longer be traced.

*Action:* tag and publish releases in these four repositories, or accept an authored fallback
(see item C).

### B. Two repositories have a tag but no GitHub Release — RESOLVED 2026-08-31

`fetch-catalog.sh` reads `releases/latest`, which 404s when a tag was pushed without a Release
being created.

| Repository | Tag present | Release | Site shows |
| --- | --- | --- | --- |
| `md-reader_tauri` | `v1.9.6` | none | 1.9.6 — correct only because the cache happened to hold it |
| `apk_finder` | `v0.20.3` | none | **—** (no version at all) |

APK Finder is a production application in daily use whose page shows no version, purely
because its tag was never turned into a Release.

**Resolved.** `fetch-catalog.sh` now falls back to the highest version-shaped tag when
`releases/latest` returns 404, and warns which repository it did that for. Prefixed tags such
as `twoplugins-v1.8.1` are ignored, since they version one app inside a shared repository
rather than the repository itself; those entries take their version from `Info.lua` anyway.

Verified against the live API: APK Finder went from no version to **0.20.3**, and Markdown
Renderer's 1.9.6 is now read from tag `v1.9.6` rather than inherited from the cache. The table
above records the state before the fix.

This does **not** help the four repositories in item A, which have no tag either.

### C. Version drift between the catalog and the repositories

Measured 2026-08-31, comparing `catalog-cache.tsv` against each repository's own
`CHANGELOG.md` on its default branch:

| Slug | Catalog | Repository changelog | Note |
| --- | --- | --- | --- |
| `project2excel` | 1.0.2 | 0.8.2 | catalog is *ahead* of anything upstream (item A) |
| `bakmil-metro` | — | 0.6.1 | no tag, no release; site shows no version |
| `apk-finder` | 0.20.3 | 0.20.3 | resolved by the tag fallback (item B) |
| `cassandra-risking` | 0.4.3 | 0.5.27 | released tag is 23 patch versions behind the changelog |
| `markdown-renderer` | 1.9.6 | 1.9.6 | agrees |
| `location-caption` | 0.1.10 | 0.1.10 | agrees on the **remote**; see below |
| `segy-coordinate-security` | 0.16.1 | 0.16.1 | agrees |

*If releases will not be published for every application*, the alternative is an optional
`version` column in `CATALOG.txt` used as an authored fallback when no release or tag exists.
This has **not** been implemented; it needs a decision, because it reintroduces a hand-
maintained value that can go stale — the exact thing the architecture change removed.

### D. Two repositories have no README

`geocrawler_ps` and `cassandraV2` have no `README.md`. Their pages were written from other
material that happens to exist — `APP_OVERVIEW.md` for Geocrawler, `docs/GEOLOGIST_USER_GUIDE.md`
for Cassandra. Both were good sources, but neither is a README, and a future pass will not
know to look for them.

*Action:* add a `README.md` to both, even a short one. Also consider adopting the
`RELEASE_NOTES.md` convention that `PDF_classifier` and `geocrawler_ps` already use — a
user-facing file, explicitly written for the person running the app. Those two files are why
those tools have release boxes on the site and the others do not.

### E. Licence reporting is unreliable for three repositories

GitHub reports `NOASSERTION` for `md-reader_tauri`, `LR_location_caption` and `geocrawler_ps`
— a `LICENSE` file is present, but GitHub cannot map it to an SPDX identifier, usually because
the text was modified.

Because `fetch-catalog.sh` falls back to the cached value when the licence is `NOASSERTION`,
**the site currently publishes "Apache-2.0" for Markdown Renderer and Geocrawler on a licence
GitHub cannot corroborate.** That is a licensing claim resting on a stale cache entry.

*Action:* restore the unmodified Apache-2.0 text in those three repositories so GitHub
identifies it, or confirm the licence is genuinely something else and correct the catalog.
Until then, treat those two "Apache-2.0" cells as unverified.

`LIghtroom_plugins` and `cassandraV2` have no LICENSE file at all and correctly show "Not
stated".

### F. Repository descriptions are absent on nine of eleven

Only `PDF_classifier` and `cassandraV2` carry a description; only `PDF_classifier` has topics.
This **no longer affects the site** — descriptions and topics stopped being load-bearing when
`setup-repo-metadata.sh` was retired — but it affects how the repositories read on GitHub
itself.

*Action:* optional, and purely for GitHub-side legibility.

### G. Deferred site work, previously reported

- **320px horizontal overflow.** `.topbar-inner` is a non-wrapping flex row and `.brand` is
  `white-space:nowrap` at 167px, so at a 320px viewport the nav wraps to three rows, the theme
  toggle is squeezed from 30px to 17px, and the row overflows by 6px. Fails WCAG 2.1 SC 1.4.10
  (Reflow), which is also what 400% browser zoom on a 1280px display produces; the squeezed
  toggle additionally drops below the 24×24px floor in SC 2.5.8. `flex:none` on
  `.theme-toggle` is the obvious half; how the header should behave at that width is a design
  decision. **Deferred at the user's request.**
- **No Content-Security-Policy or Referrer-Policy.** GitHub Pages cannot set response headers,
  so a `<meta http-equiv>` CSP in `page_open` is the only lever. The site has one inline
  script (the theme pre-paint) and no third-party JavaScript, so a strict policy is cheap.
- **Google Fonts** puts a third party in every page load. Disclosed accurately in
  `privacy.html`; self-hosting would remove the dependency, the disclosure and two preconnects.
- **`assets/bluebonnet_art.png` is 3.1 MB, tracked, and referenced by nothing.** Not deleted —
  removing tracked files needs explicit authorisation.
- **The home-page crown is 782 KB and eagerly loaded**, being above the fold. WebP/AVIF with a
  PNG fallback would help most here.
- **The wide arch is used as a tailpiece** on the three category pages, contradicting the
  README's description of it as a page crown. A design call, not a defect.
- **Section labels are `<p>`, not headings**, so they are missing from the document outline.

### H. `cassandraV2` contains client branding

`assets/` in that repository holds SOCAR Exploration logos. **No client is named anywhere on
the public site**, and the Cassandra page was written without reference to them. Flagging it
so a future pass does not import that artwork or those names into public copy without
checking.

### I. A local clone has unpushed work

`LR_Location_caption` (working copy, outside this repository) is **6 commits ahead of
`origin/main`**. Its local `CHANGELOG.md` reports 0.3.0 while the remote reports 0.1.10 — so
the Location Caption page and its version reflect the *pushed* state, which is correct for a
public catalog, but the newer work is not published. Worth confirming that is intentional.

---

## Unverified

- **Sticky-panel scroll behaviour.** The At a glance panel and the release box were changed to
  travel as one unit inside `.aside-stack`. Correctness rests on the containment change — the
  release box is now a *child* of the sticky element rather than a sibling, so overlap is
  structurally impossible — and on the rendered layout. It could **not** be demonstrated by
  scrolling: headless Chrome's `--dump-dom` does not scroll, and `window.scrollY` stayed 0
  through every attempt. Worth one manual scroll in a browser.
- **Licence identity** for the three `NOASSERTION` repositories (item E).
- **The origin of `project2excel` version 1.0.2** (item A). It is in the cache; it is in no
  tag, release or changelog.
- **Windows rendering.** All visual checks were done on macOS 25.6 in headless Chrome.
- **Live site deployment.** Everything was verified against a local server, never against
  `dev.bbst.us`.

---

## Decisions made, and why

- **Keep the generator, retire the automated metadata round-trip.** `setup-repo-metadata.sh`
  pushed descriptions to GitHub and `fetch-catalog.sh` read the same strings back, so GitHub
  was never upstream of the site's own words. The generator was kept because one version
  number appears on five pages and 15 of 18 pages carry a roster — that consistency is what
  `build.sh` exists to guarantee.
- **Fetch versions and licences only.** Chosen over full manual maintenance so release
  versions stay current without editing this repository.
- **Escape at the source, once.** Catalog values are escaped where they enter `TOOLS`, so
  every consumer is safe without remembering to be. Editorial HTML in `tool_prose` is
  deliberately not routed through it.
- **Names and slugs stay pinned; subtitles carry the explanation.** No published URL changes.
- **`Web & Mobile` keeps the filename `web-apps.html`** for the same reason.
- **APK Finder listed as a private release.** It is in production use but has no published
  GitHub Release, and "built, versioned and in use, distributed on request" is exactly what
  that status means in this catalog's vocabulary.
- **No release box invented.** Only the five applications with genuinely user-facing release
  notes have one. Synthesising a box from an engineering changelog would put maintainer
  language in front of readers.

---

## Next steps, in priority order

1. ~~Add a tag fallback to `fetch-catalog.sh`~~ — **done 2026-08-31** (item B).
2. **Decide how versions work for repositories that will never publish releases** (items A
   and C) — publish releases, or add an authored `version` column to `CATALOG.txt`. *This
   needs a decision before it can be implemented.*
3. **Resolve the `project2excel` 1.0.2 mystery** (item A). The site is publishing a version
   number with no upstream evidence.
4. **Fix the three `NOASSERTION` licences** (item E), or correct what the site claims. This is
   a licensing statement, so it should not stay unverified.
5. **Add READMEs to `geocrawler_ps` and `cassandraV2`** (item D), and consider adopting
   `RELEASE_NOTES.md` more widely — it is the difference between a page having a release box
   and not.
6. **Take the 320px header fix off deferral** (item G) when convenient; it is an accessibility
   conformance failure, not only a cosmetic one.
7. **Review and merge `catalog-content-rewrite`.** The work is committed on that branch and
   has not been pushed. `main` is protected, so merging it is a decision for the repository
   owner — nothing here presumes how that should happen.

## Decisions required from the user

- Versions for release-less repositories: publish releases, or authored fallback column?
- Delete `assets/bluebonnet_art.png` (3.1 MB, unreferenced)?
- The tailpiece question: is the wide arch intended as a page crown, or as a tailpiece on the
  three category pages?
