#!/usr/bin/env bash
# One-time setup: give each app repository the description and topics that
# fetch-catalog.sh reads. Run once, then re-run only when a category, platform
# or product name genuinely changes.
#
#   bash setup-repo-metadata.sh --dry-run    print what would be set
#   bash setup-repo-metadata.sh              apply it
#
# THIS WRITES TO GITHUB. It edits repository descriptions and replaces their
# topic lists. Review the values below before applying — the descriptions are
# the summaries currently shown on the site, and the part before the em dash
# becomes the display name.
set -uo pipefail

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

# repo | description | topics
ROWS='rcshou/Project2Excel|Project2Excel — Microsoft Project files into editable Excel workbooks|bbst-business platform-windows platform-macos bbst-private
rcshou/PDF_classifier|PDF Classifier — routes PDFs by text-layer quality before anyone pays for OCR|bbst-business platform-windows bbst-private
rcshou/md-reader_tauri|Markdown Renderer — Markdown preview, linting and export with real tables and math|bbst-business platform-windows platform-macos bbst-private
rcshou/Bakmill_PWA|Bakmil Metro Schedule — next-departure times for the Bakmil metro shuttle in Baku|bbst-webapps platform-web bbst-released
rcshou/LIghtroom_plugins|Lightroom Plugins — similar-photo detection, file statistics, capture-date repair and missing-file recovery|bbst-lightroom platform-plugin platform-macos bbst-private
rcshou/LR_location_caption|Location Caption Assistant — suggests the landmark a GPS-tagged photo was actually taken at|bbst-lightroom platform-plugin bbst-beta
rcshou/geocrawler_ps|Geocrawler — audits a subsurface data repository and tells you what is in it|bbst-geoscience platform-windows bbst-private
rcshou/seis_coord|SEG-Y Coordinate Security — share seismic data without giving away where it was shot|bbst-geoscience platform-windows bbst-private
rcshou/cassandraV2|Cassandra Risking — prospect risking with the evidence attached to the number|bbst-geoscience platform-windows bbst-private'

command -v gh >/dev/null 2>&1 || { echo "gh CLI not found" >&2; exit 1; }

printf '%s\n' "$ROWS" | while IFS='|' read -r repo desc topics; do
  [ -n "$repo" ] || continue
  echo "── $repo"
  echo "   description: $desc"
  echo "   topics:      $topics"
  if [ "$DRY" = "1" ]; then continue; fi
  # shellcheck disable=SC2086
  gh repo edit "$repo" --description "$desc" $(for t in $topics; do printf ' --add-topic %s' "$t"; done) \
    && echo "   set" || echo "   FAILED" >&2
done

if [ "$DRY" = "1" ]; then
  echo
  echo "Dry run only. Re-run without --dry-run to apply, then: bash fetch-catalog.sh"
fi
