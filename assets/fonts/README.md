# Fonts

Self-hosted so that loading a page contacts no third party. `styles.css` declares them
with `@font-face`, split by script with `unicode-range`, so a browser downloads only the
subsets a page actually uses.

| Family | Files | Licence |
| --- | --- | --- |
| Newsreader (roman and italic, variable weight and optical size) | `newsreader-*.woff2` | SIL Open Font License 1.1, `OFL-newsreader.txt` |
| Archivo (variable weight) | `archivo-*.woff2` | SIL Open Font License 1.1, `OFL-archivo.txt` |
| JetBrains Mono (variable weight) | `jetbrains-mono-*.woff2` | SIL Open Font License 1.1, `OFL-jetbrains-mono.txt` |

## Provenance

Downloaded unmodified on 2026-09-16 from Google Fonts (`fonts.gstatic.com`), as served to a
current Chromium for this request, which is the set the site used to load from Google:

```
https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,500;0,6..72,600;1,6..72,400&family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap
```

Google serves one variable file per script subset, shared by every weight requested, so
each file appears once in `styles.css` with a weight range. The `@font-face` rules keep the
`unicode-range` values from that response. The licence texts come from the
`google/fonts` repository (`ofl/<family>/OFL.txt`).

## Updating

Fetch the stylesheet above with a current browser user agent, download each `woff2` it
names, keep the file names in the pattern `<family>[-italic]-<subset>.woff2`, and update the
rules at the top of `styles.css`. Only the Vietnamese, Latin, Latin Extended, Cyrillic and
Greek subsets are served today; adding a family or subset means adding its licence here too.
