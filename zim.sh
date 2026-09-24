#!/usr/bin/env bash
set -Eeuo pipefail

BUILD_ROOT="${ZIM_BUILD_ROOT:-$HOME/.cache/ez-zimit}"
WORKERS=1

KIWIX_CONTAINER="${KIWIX_CONTAINER:-kiwix-serve}"
KIWIX_FOUND=no
ZIMIT_IMAGE="${ZIMIT_IMAGE:-ghcr.io/openzim/zimit:3.1.3}"

usage() {
    cat <<'USAGE'
Usage:
  zim <URL>        Crawl with 1 worker
  zim -N <URL>     Crawl with N workers
  zim -h|--help    Show this help

Examples:
  zim https://example.com/
  zim -2 https://example.com/
  zim -4 https://example.com/
USAGE
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

# Parse command line
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;

    -*)
        if [[ "$1" =~ ^-([1-9][0-9]*)$ ]]; then
            WORKERS="${BASH_REMATCH[1]}"
            shift
        else
            fail "Invalid option '$1'. Use -N for workers, for example -4."
        fi
        ;;
esac

if (( $# != 1 )); then
    usage >&2
    exit 1
fi

URL="$1"

# Dependencies
for cmd in python3 jq docker; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        fail "Required command not found: $cmd"
    fi
done

# Docker access
DOCKER=(docker)

if ! docker info >/dev/null 2>&1; then
    if command -v sudo >/dev/null 2>&1 &&
       sudo docker info >/dev/null 2>&1; then
        DOCKER=(sudo docker)
    else
        fail "Docker is installed but is not accessible."
    fi
fi

# Output location
if [[ -n "${ZIM_OUTPUT_DIR:-}" ]]; then
    OUTPUT_DIR="$ZIM_OUTPUT_DIR"
elif "${DOCKER[@]}" inspect "$KIWIX_CONTAINER" >/dev/null 2>&1 &&
     [[ -d /storage/kiwix ]]; then
    KIWIX_FOUND=yes
    OUTPUT_DIR="/storage/kiwix"
else
    OUTPUT_DIR="$HOME/Downloads"
fi

# Validate URL and generate archive name
if ! NAME=$(python3 - "$URL" <<'PY'
import hashlib
import re
import sys
from urllib.parse import urlsplit

url = sys.argv[1]
u = urlsplit(url)

if u.scheme not in {"http", "https"} or not u.netloc:
    raise SystemExit(2)

base = (u.netloc + u.path).strip("/").replace("/", "-")
base = re.sub(r"[^A-Za-z0-9_-]+", "-", base)
base = base.strip("-").lower()

if u.query:
    base += "-" + hashlib.sha256(
        u.query.encode()
    ).hexdigest()[:8]

if not base:
    raise SystemExit(2)

print(base)
PY
); then
    fail "Invalid URL '$URL'. Use a full http:// or https:// URL."
fi

BUILD_DIR="$BUILD_ROOT/$NAME"
LOG_FILE="$BUILD_ROOT/${NAME}.log"
ZIM_FILE="$OUTPUT_DIR/${NAME}.zim"

if ! mkdir -p "$OUTPUT_DIR" "$BUILD_ROOT"; then
    fail "Could not create output/build directories."
fi

# Overwrite protection
if [[ -e "$ZIM_FILE" ]]; then
    fail "'$ZIM_FILE' already exists. Move or remove it before creating a new archive."
fi

# Detect resume state
RESUMING=no

if [[ -d "$BUILD_DIR" ]] &&
   [[ -n "$(find "$BUILD_DIR" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
    RESUMING=yes
fi

mkdir -p "$BUILD_DIR"

{
    printf '\n=== %s ===\n' "$(date -Is)"
    printf 'URL=%s\n' "$URL"
    printf 'NAME=%s\n' "$NAME"
    printf 'WORKERS=%s\n' "$WORKERS"
} >> "$LOG_FILE"

printf 'Creating: %s\n' "${NAME}.zim"
printf 'Source:   %s\n' "$URL"
printf 'Workers:  %s\n' "$WORKERS"
printf 'Output:   %s\n' "$OUTPUT_DIR"

if [[ "$RESUMING" == yes ]]; then
    printf 'Resume:   existing crawl data in %s\n' "$BUILD_DIR"
else
    printf 'Build:    %s\n' "$BUILD_DIR"
fi

printf '\n'

# Progress display
TTY_OUTPUT=0
[[ -t 1 ]] && TTY_OUTPUT=1

LAST_BUCKET=-1

render_progress() {
    local crawled="$1"
    local total="$2"
    local failed="$3"

    local width=30
    local percent=0
    local filled
    local empty
    local done_part
    local todo_part
    local bucket

    if (( total > 0 )); then
        percent=$(( crawled * 100 / total ))
        (( percent > 100 )) && percent=100
    fi

    filled=$(( percent * width / 100 ))
    empty=$(( width - filled ))

    printf -v done_part '%*s' "$filled" ''
    done_part=${done_part// /#}

    printf -v todo_part '%*s' "$empty" ''
    todo_part=${todo_part// /-}

    if (( TTY_OUTPUT )); then
        printf '\r\033[K[%s%s] %d/%d  %3d%%  failed:%d' \
            "$done_part" \
            "$todo_part" \
            "$crawled" \
            "$total" \
            "$percent" \
            "$failed"
    else
        bucket=$(( percent / 10 ))

        if (( bucket > LAST_BUCKET )); then
            printf 'Progress: %d/%d  %d%%  failed:%d\n' \
                "$crawled" \
                "$total" \
                "$percent" \
                "$failed"

            LAST_BUCKET="$bucket"
        fi
    fi
}

# Run Zimit
set +e

"${DOCKER[@]}" run --rm \
    -v "$OUTPUT_DIR:/output" \
    -v "$BUILD_DIR:/build" \
    "$ZIMIT_IMAGE" \
    zimit \
    --seeds "$URL" \
    --name "$NAME" \
    --build /build \
    --workers "$WORKERS" \
    2>&1 \
| tee -a "$LOG_FILE" \
| jq --unbuffered -Rr '
    . as $raw
    | (try fromjson catch null) as $j

    | if (
        $j != null
        and $j.context == "crawlStatus"
      )
      then
        [
          "PROGRESS",
          ($j.details.crawled // 0),
          ($j.details.total   // 0),
          ($j.details.failed  // 0)
        ]
        | @tsv

      elif (
        $raw
        | test("Processing WARC files|Calling warc2zim")
      )
      then
        "BUILD"

      else
        empty
      end
  ' \
| {
    build_announced=0

    while IFS=$'\t' read -r kind a b c; do
        case "$kind" in
            PROGRESS)
                render_progress "$a" "$b" "$c"
                ;;

            BUILD)
                if (( build_announced == 0 )); then
                    if (( TTY_OUTPUT )); then
                        printf '\r\033[K✓ Crawl complete. Building ZIM...\n'
                    else
                        printf 'Crawl complete. Building ZIM...\n'
                    fi

                    build_announced=1
                fi
                ;;
        esac
    done
}

PIPE_STATUSES=("${PIPESTATUS[@]}")

set -e

DOCKER_STATUS="${PIPE_STATUSES[0]:-1}"
TEE_STATUS="${PIPE_STATUSES[1]:-1}"
JQ_STATUS="${PIPE_STATUSES[2]:-1}"
DISPLAY_STATUS="${PIPE_STATUSES[3]:-1}"

if (( TTY_OUTPUT )); then
    printf '\r\033[K'
fi

if (( DOCKER_STATUS != 0 )); then
    printf 'Crawl stopped or failed (exit %d).\n' "$DOCKER_STATUS" >&2
    printf 'Resume data preserved at: %s\n' "$BUILD_DIR" >&2
    printf 'Run the same command again to resume.\n' >&2
    printf 'Log: %s\n' "$LOG_FILE" >&2
    exit "$DOCKER_STATUS"
fi

if (( TEE_STATUS != 0 ||
      JQ_STATUS != 0 ||
      DISPLAY_STATUS != 0 )); then
    fail "The crawl completed, but the progress/logging pipeline failed. Check '$LOG_FILE'."
fi

# Success
[[ -f "$ZIM_FILE" ]] ||
    fail "Zimit exited successfully but '$ZIM_FILE' was not created. Check '$LOG_FILE'."

printf 'Finished: %s\n' "$ZIM_FILE"

printf 'Cleaning completed crawl state...\n'
rm -rf -- "$BUILD_DIR"

if [[ "$KIWIX_FOUND" == yes ]]; then
    printf 'Restarting Kiwix container %q...\n' "$KIWIX_CONTAINER"

    if "${DOCKER[@]}" restart "$KIWIX_CONTAINER" >/dev/null; then
        printf 'Kiwix restarted.\n'
    else
        printf 'WARNING: ZIM created, but Kiwix failed to restart.\n' >&2
    fi
fi

printf 'Done.\n'