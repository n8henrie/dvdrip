#!/usr/bin/env bash
# videomd.sh :: Set video metadata with AtomicParsley
# Dependencies: AtomicParsley, jq, curl
# Export your themoviedb api key to TMDB_API_KEY

set -Eeuf -o pipefail
set -x

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$DIR"/config.env

API_KEY="${TMDB_API_KEY}"
DEST=${DEST-$MKV_DEST}

clean_title() {
    : "${1##*/}"            # Basename
    : "${_%.*}"             # Strip extension
    : "${_%_t[[:digit:]]*}" # Strip title suffix e.g. moviename_t100
    echo "${_//_/ }"        # Replace underscores with spaces
}

get_artwork() {
    local filename="${1//\//}" # Remove any slashes
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
    title="$(clean_title "${search_string-"$filename"}")"
    ids="$(curl --silent --get --data api_key="$API_KEY" --data-urlencode "query=$title" 'https://api.themoviedb.org/3/search/movie' | jq '.results | sort_by(-.popularity)')"
    echo "$ids"
}

set_metadata() {
    json="$(curl --silent --get --data api_key="$API_KEY" -d 'append_to_response=credits,images,releases' 'https://api.themoviedb.org/3/movie/'"$id")"

    description="$(jq --raw-output '.overview' <<<"$json")"
    title="$(jq --raw-output '.title' <<<"$json")"
    year="$(jq --raw-output '.release_date' <<<"$json")"
    longdesc="$description"
    genre="$(jq --raw-output '.genres[0].name' <<<"$json")"
    stik=Movie
    Rating="$(jq --raw-output '[.releases.countries[] | select(.iso_3166_1 == "US")][0].certification' <<<"$json")"
    artist="$(jq --raw-output '[.credits.cast[].name] | join(", ")' <<<"$json")"
    artwork="$(get_artwork "$(jq --raw-output '.poster_path' <<<"$json")")"

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

while getopts 's:i:' OPTION; do
    case "$OPTION" in
    s)
        search_string="$OPTARG"
        get_movie_ids | jq --color-output
        exit
        ;;
    i) id="$OPTARG" ;;
    *)
        echo "USAGE: $(basename "$0") [-s ["a title"]] [-i TMDB_ID]" >&2
        exit 1
        ;;
    esac
done
shift $((OPTIND - 1))

filename=$1
id=${id-"$(get_movie_ids | jq --raw-output '.[0].id')"}
if [ "$id" = "null" ]; then
    echo "No movie found"

    # Pass on to next script
    echo "$filename"
    exit 0
fi
clean_metadata >&2
set_metadata >&2

mv "$filename" "$DEST/$new_filename" || true

# Pass filename onto next script
echo "$DEST/$new_filename"
