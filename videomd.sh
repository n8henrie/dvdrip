#!/usr/bin/env bash
# videomd.sh :: Set video metadata with AtomicParsley
# Dependencies: AtomicParsley, jq, curl
# Export your themoviedb api key to TMDB_API_KEY

set -Eeuf -o pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$DIR"/config.env

API_KEY="${TMDB_API_KEY}"
DEST=${DEST-$MKV_DEST}

usage() {
  echo -n "USAGE:
  Find metadata:
    $(basename "$0") -s \"a title\"
    $(basename "$0") -s myfile.mp4

  Find and write metadata based on most popular result:
    $(basename "$0") myfile.mp4

  Find and write metadata based on ID:
    $(basename "$0") -i TMDB_ID myfile.mp4
"
}

clean_title() {
  : "${1##*/}"            # Basename
  : "${_%.*}"             # Strip extension
  : "${_%_t[[:digit:]]*}" # Strip title suffix e.g. moviename_t100
  echo "${_//_/ }"        # Replace underscores with spaces
}

get_artwork() {
  local filename tmpdir base_url
  filename="${1//\//}" # Remove any slashes
  tmpdir="$(mktemp -d)"
  base_url="$(curl --silent --get --data "api_key=$API_KEY" 'https://api.themoviedb.org/3/configuration' | jq --raw-output '.images.secure_base_url')"
  curl -s "${base_url}/original/${filename}" --output "${tmpdir}/${filename}"
  echo "${tmpdir}/${filename}"
}

clean_metadata() {
  AtomicParsley "$filename" --metaEnema --overWrite
  AtomicParsley "$filename" --artwork REMOVE_ALL --overWrite
}

get_movie_ids() {
  local title
  title="$(clean_title "${search_string-"$filename"}")"
  curl --silent --get --data api_key="$API_KEY" --data-urlencode "query=$title" 'https://api.themoviedb.org/3/search/movie' | jq '.results | sort_by(-.popularity)'
}

set_metadata() {
  local json description title year longdesc genre stik Rating artist artwork
  json="$(curl --silent --get --data api_key="$API_KEY" -d 'append_to_response=credits,images,releases' 'https://api.themoviedb.org/3/movie/'"$id")"

  description="$(jq --raw-output '.overview' <<< "$json")"
  title="$(jq --raw-output '.title' <<< "$json")"
  year="$(jq --raw-output '.release_date' <<< "$json")"
  longdesc="$description"
  genre="$(jq --raw-output '.genres[0].name' <<< "$json")"
  stik=Movie
  Rating="$(jq --raw-output '[.releases.countries[] | select(.iso_3166_1 == "US")][0].certification' <<< "$json")"
  artist="$(jq --raw-output '[.credits.cast[].name] | join(", ")' <<< "$json")"
  artwork="$(get_artwork "$(jq --raw-output '.poster_path' <<< "$json")")"

  AtomicParsley "$filename" \
    --description "$description" \
    --title "$title" \
    --year "$year" \
    --genre "$genre" \
    --longdesc="$longdesc" \
    --stik="$stik" \
    --Rating="$Rating" \
    --artist="$artist" \
    --artwork="$artwork" \
    --overWrite
  echo "title: $title"
  ext="${filename##*.}"
  new_filename="${title}.$ext"
}

main() {
  local filename id
  while getopts 's:i:' OPTION; do
    case "$OPTION" in
      s)
        search_string="$OPTARG"
        get_movie_ids
        exit
        ;;
      i) id="$OPTARG" ;;
      *)
        usage
        exit 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  if [ -z "${1-}" ]; then
    usage
  fi

  filename=$1
  id=${id-"$(get_movie_ids | jq --raw-output '.[0].id')"}
  if [ "$id" = "null" ]; then
    echo >&2 "No movie found"

    # Pass filename on for the rest of the script
    echo "$filename"
    exit 1
  fi
  clean_metadata >&2
  set_metadata >&2

  # mv gives an error if the new and old file are the same
  mv --no-clobber "$filename" "$DEST/$new_filename"

  # Pass filename onto next script
  echo "$DEST/$new_filename"
}
main "$@"
