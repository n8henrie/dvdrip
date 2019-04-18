#!/bin/bash

set -euf -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR"/config.env

cd "$(mktemp -d)"
filename="$(sudo --non-interactive /usr/local/bin/handbraker.sh | tail -n 1)"
new_filename="$("$DIR"/videomd.sh "$filename" | tail -n 1)"

rsync -avz --progress --remove-source-files "${RSYNC_SSH_OPTS[@]}" "$new_filename" "$RSYNC_DEST"
