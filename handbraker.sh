#!/bin/bash

set -euf -o pipefail

finish() {
  /bin/noti --pushover --file /home/"$SUDO_USER"/.config/noti/noti.yaml || :
  /bin/eject
}

trap finish INT TERM EXIT

if [ ! "$(whoami)" = root ]; then
  echo "Please run as root"
  exit 1
fi

warn() {
  wall -n "Automatically ripping DVD in 60 seconds. To stop, kill ${BASH_SOURCE[0]}."
  sleep 60
}

rip() {
  outfile="$(blkid -o value -s LABEL /dev/cdrom).mp4"
  /bin/HandBrakeCLI \
    --subtitle-lang-list=eng \
    --all-subtitles \
    --subtitle=scan \
    --subtitle-burned \
    --subtitle-default=none \
    --native-language=eng \
    --preset "Apple 720p30 Surround" \
    --main-feature \
    --optimize \
    --input /dev/cdrom \
    --output "$outfile"
  /bin/eject
  chmod 0644 "$outfile"
  chown "$SUDO_USER:$SUDO_USER" "$outfile"
}

warn >&2
rip >&2
# Pass filename on to next script
echo "$outfile"
