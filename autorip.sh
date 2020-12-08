#!/bin/bash

set -Eeuf -o pipefail
set -x

fallback() {
  if [ "${MEDIATYPE,,}" = "bluray" ]; then
    TMPDIR=$(mktemp -d)
    echo "Attempt failed, trying to back up entire disk to $TMPDIR"
    makemkvcon backup --decrypt disc:0 "$TMPDIR"
    msg="Fallback backup completed to $TMPDIR"
    noti -m "$msg"
    echo "$msg"
  fi
}

trap fallback ERR

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$DIR"/config.env

MEDIATYPE="$1"
QUALITY=${2-default}

cd "$(mktemp -d)"
case "${MEDIATYPE,,}" in
  dvd | bluray | *.mkv)
    outfile=$(sudo \
      --non-interactive \
      /usr/local/bin/handbraker.sh "$MEDIATYPE" "$QUALITY" |
      tail -n 1)
    new_file=$("$DIR"/videomd.sh "$outfile" | tail -n 1)
    ;;
  *.mp4 | *.m4v)
    outfile=$MEDIATYPE
    new_file=$(sudo --non-interactive "$DIR"/videomd.sh "$outfile" | tail -n 1)
    ;;
esac

# No longer try to fallback rip the whole dvd, since it seems that part worked
trap "" ERR

chmod 0644 -- "$new_file"
if [ -n "${DVDRIP_CHOWN-}" ]; then
  chown "$DVDRIP_CHOWN:$DVDRIP_CHOWN" -- "$new_file"
fi

rsync --archive "${RSYNC_SSH_OPTS[@]}" "$new_file" "$RSYNC_DEST"
