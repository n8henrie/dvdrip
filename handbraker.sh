#!/bin/bash

# Subtitles setup:
# https://willhaley.com/blog/default-foreign-soft-subtitle-support-in-plex-using-handbrake/

set -Eeuf -o pipefail
set -x

finish() {
  /bin/noti --pushover --file /home/"$SUDO_USER"/.config/noti/noti.yaml || :
}

trap finish INT TERM EXIT

USAGE='
Usage: sudo handbraker.sh MEDIATYPE [QUALITY]
MEDIATYPE: dvd, bluray
QUALITY (optional): high
'

if [[ "$1" =~ ^(-h|--help)$ ]]; then
  echo "$USAGE"
  exit 0
fi

if [ ! "$(whoami)" = root ]; then
  echo "Please run as root"
  echo "$USAGE"
  exit 1
fi

MEDIATYPE="$1"
QUALITY_FLAG="${2-default}"
DEST_ROOT=${MKV_DEST-"."}

warn() {
  wall -n "Automatically ripping DVD in 60 seconds.
           To stop, kill ${BASH_SOURCE[0]},
           or systemctl kill dvdrip."
  #sleep 60
}

all_subtitles() {
  HandBrakeCLI --scan --main-feature --input="$1" |&
    awk '
      # start looking for subtitles at Main Feature
      /^\s+\+ Main Feature/ { flag++ }

      # increment flag after "subtitle tracks"
      flag && /^\s+\+ subtitle tracks:/{ flag++; next }

      # if flag is 2 (Main Feature and subtitles seen)
      # and line not start with spaces, literal plus, then digits, exit
      flag >= 2 && !/^\s+\+ [[:digit:]]+/ { exit }

      # skip lines ending in `[PGS]` since Handbrake can only burn in PGS subs
      /\[PGS\]$/ { next }

      # if flag set, strip comma from subtitle number and print subtitle number
      flag == 2 { sub(/,$/, "", $2); print $2 }
    ' | # collect into comma separated list
    paste -s -d,
}

rip_dvd() {
  MOVIENAME=$(blkid -o value -s LABEL /dev/cdrom).mp4
  outfile="$DEST_ROOT/$MOVIENAME"
  /bin/HandBrakeCLI \
    --native-language=eng \
    --subtitle=scan,"$(all_subtitles /dev/cdrom)" \
    --subtitle-default=1 \
    --subtitle-forced=1 \
    --preset="$PRESET" \
    --main-feature \
    --optimize \
    --input=/dev/cdrom \
    --output="$outfile"
}

rip_bluray() {
  # https://shkspr.mobi/blog/2012/02/command-line-backup-for-dvds/
  long_title=$(
    makemkvcon -r info disc:0 | # extract title lengths
      awk -F, '
      BEGIN { max=-1 }
      /^TINFO/ && /[[:digit:]]{1,2}:[[:digit:]]{2}:[[:digit:]]{2}/ {
        print $0 > "/dev/stderr" # debug print the track durations
        gsub(/"/, "") # get rid of double quotes
        split($NF,arr,":") # split on colons, gives a 1-indexed array
        val = 60 * 60 * arr[1] + 60 * arr[2] + arr[3] # duration in seconds
        if ( val > max ) {
          max = val
        }
      }
      END { print max }
  '
  )

  MOVIENAME=$(blkid -o value -s LABEL /dev/cdrom)
  DEST="$DEST_ROOT/$MOVIENAME"

  mkdir -p "$DEST"

  # Rip DVD
  makemkvcon --minlength="$long_title" --robot --decrypt --directio=true mkv disc:0 all "$DEST"

  if [ "$(find "$DEST" -name '*.mkv' -printf '.' | wc -c)" -eq 1 ]; then
    outfile="$(dirname "$DEST")/$MOVIENAME".mkv
    mv "$DEST/"*.mkv "$outfile"
  else
    echo "ERR: Too many MKV files found in $DEST" >&2
    exit 1
  fi
}

convert_mkv() {
  outfile="${1%.mkv}.mp4"
  /bin/HandBrakeCLI \
    --native-language=eng \
    --subtitle=scan,"$(all_subtitles "$1")" \
    --subtitle-default=1 \
    --audio-lang-list=eng,spa \
    --all-audio \
    --preset="$PRESET" \
    --input="$1" \
    --output="$outfile"
}

main() {
  warn >&2

  QUALITY="Devices/Apple"
  RESOLUTION="720p30"

  case "${QUALITY_FLAG,,}" in
    "high")
      QUALITY="General/Super HQ"
      ;;
  esac

  case "$MEDIATYPE" in
    dvd)
      PRESET=$(printf "%s %s Surround" "$QUALITY" "$RESOLUTION")
      rip_dvd >&2
      ;;
    bluray)
      PRESET=$(printf "%s %s Surround" "$QUALITY" "$RESOLUTION")
      RESOLUTION="1080p30"
      rip_bluray
      convert_mkv "$outfile"
      ;;

    # File passed in directly as $1, assume bluray that was ripped and now just
    # needs encoding
    *.mkv)
      outfile="$MEDIATYPE"
      PRESET="$(printf "%s %s Surround" "$QUALITY" "$RESOLUTION")"
      RESOLUTION="1080p30"
      convert_mkv "$outfile"
      ;;
  esac

  /bin/chmod 0644 "$outfile"
  /bin/chown "$SUDO_USER:$SUDO_USER" "$outfile"

  /bin/eject || true

  # Pass filename on to next script
  echo "$outfile"
}

main
