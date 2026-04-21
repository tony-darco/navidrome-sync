#!/bin/bash
# Capture real Subsonic API responses from a running Navidrome + sync service
# for use as test fixtures.
#
# Usage:
#   NAVIDROME_URL=http://localhost:4533 \
#   NAVIDROME_USER=admin \
#   NAVIDROME_PASS=admin \
#   ./scripts/capture_fixtures.sh
#
# Requires: curl, jq

set -euo pipefail

: "${NAVIDROME_URL:?Set NAVIDROME_URL (e.g. http://localhost:4533)}"
: "${NAVIDROME_USER:?Set NAVIDROME_USER}"
: "${NAVIDROME_PASS:?Set NAVIDROME_PASS}"

BASE="$NAVIDROME_URL/rest"
AUTH="u=$NAVIDROME_USER&p=$NAVIDROME_PASS&v=1.16.1&c=navidrome-ios&f=json"
FIXTURES_DIR="$(cd "$(dirname "$0")/../navidrome-ios/navidrome-iosTests/TestFixtures" && pwd)"

echo "Capturing fixtures to $FIXTURES_DIR"
echo "Server: $NAVIDROME_URL  User: $NAVIDROME_USER"
echo "---"

# Album list (newest, 3 items)
echo "→ getAlbumList2 (newest)..."
curl -sf "$BASE/getAlbumList2?$AUTH&type=newest&size=3" \
    | jq . > "$FIXTURES_DIR/subsonic_get_album_list.json"
echo "  ✓ subsonic_get_album_list.json"

# Single album detail (first album from the list)
ALBUM_ID=$(jq -r '.["subsonic-response"].albumList2.album[0].id' "$FIXTURES_DIR/subsonic_get_album_list.json")
if [ "$ALBUM_ID" != "null" ] && [ -n "$ALBUM_ID" ]; then
    echo "→ getAlbum (id=$ALBUM_ID)..."
    curl -sf "$BASE/getAlbum?$AUTH&id=$ALBUM_ID" \
        | jq . > "$FIXTURES_DIR/subsonic_get_album.json"
    echo "  ✓ subsonic_get_album.json"
else
    echo "  ⚠ Skipping getAlbum — no albums found in list"
fi

# Error response (deliberately bad password)
echo "→ Capturing error response (bad credentials)..."
curl -sf "$BASE/getAlbumList2?u=baduser&p=badpass&v=1.16.1&c=navidrome-ios&f=json&type=newest&size=1" \
    | jq . > "$FIXTURES_DIR/subsonic_error_response.json" 2>/dev/null || \
    echo '{"subsonic-response":{"status":"failed","version":"1.16.1","error":{"code":40,"message":"Wrong username or password"}}}' \
    | jq . > "$FIXTURES_DIR/subsonic_error_response.json"
echo "  ✓ subsonic_error_response.json"

echo ""
echo "Done. Fixture files:"
ls -la "$FIXTURES_DIR"/*.json
