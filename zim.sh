#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: zim <URL>"
    exit 1
fi

URL="$1"

NAME=$(python3 -c '
import sys
from urllib.parse import urlparse
u=urlparse(sys.argv[1])
s=(u.netloc+u.path).strip("/").replace("/","-")
print("".join(c if c.isalnum() or c in "-_" else "-" for c in s).strip("-").lower())
' "$URL")

echo "Creating: ${NAME}.zim"
echo "Source:   $URL"
echo "Output:   /storage/kiwix"
echo

sudo docker run --rm \
    -v /storage/kiwix:/output \
    ghcr.io/openzim/zimit:3.1.3 \
    zimit \
    --seeds "$URL" \
    --name "$NAME"
    --workers 4

echo
echo "Finished: /storage/kiwix/${NAME}.zim"

echo "Restarting Kiwix..."
sudo docker restart kiwix-serve

echo "Kiwix restarted."
