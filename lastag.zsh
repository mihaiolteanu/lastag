#!/usr/bin/env zsh

SELF=$(basename "$0")
db_location() {
    echo "$HOME/.lastag/"
}

help_str="$SELF - tag mp3 files with music genres from last.fm

Usage: $SELF [-lcph]
       $SELF -d folder
       $SELF [file folder]
             file   - tag this media file
             folder - tag all the media files in the folder

Options:
        -l Print an error log with file names for which genre tags could not be
           found, usually because the artist name is missing or wrong.
        -c Clear the error log and exit.
        -p Print all genres in the local database and exit
        -d <folder> Run in daemon mode. Add genre tags to all new media files
           in the watched folder.
        -h Print this help and exit.

$SELF creates a local database in $(db_location) to store the tags for each
artist. The database is updated from last.fm each time you tag a file, a folder
or a new file is added to a watched folder (daemon mode), if that artist is not
already present in the database. If no artist name can be extracted from the
given mp3 files, the file name is added to the error log. Fix the id3 tag of
the mp3 file and try again.
"

rm_extra_spaces() {
    echo $1 | sed 's/^[[:space:]]*//; s/[[:space:]] *$//;
                   s/[[:space:]][[:space:]]*/ /g'
}

db_artist_location() {
    local artist=${1// /-}
    echo $(db_location)$artist
}

db_log_location() {
    echo $(db_location)/.log
}

save_to_log() {
    echo $1 >> $(db_log_location)
}

dump_log() {
    local file=$(db_log_location)
    if [[ -a $file ]]; then
        cat $file
    fi
}

clear_log() {
    local file=$(db_log_location)
    if [[ -a $file ]]; then
        rm $file
    fi
}

save_genres_to_db() {
    local artist genres location
    artist=$1
    genres=$2
    location=$(db_artist_location $artist)
    if [[ ! -a $location ]]; then
        echo $genres > $location
    fi
}

genres_from_db() {
    local artist genres location
    artist=$1
    location=$(db_artist_location $artist)
    genres=""
    if [[ -f $location ]]; then
        genres=$(cat $location)
    fi
    echo -n $genres
}

genres_from_lastfm() {
    local artist template url genres
    artist=$1
    template="www.last.fm/music/%s"
    url=$(printf $template $artist)
    genres=$(curl -sL $url | hxnormalize -x | \
                 hxselect -c -s '/' 'li.tag a')
    genres=${(z)genres}
    genres=${genres//;/}
    echo -n $(rm_extra_spaces $genres)
}

cmus_artist() {
    cmus-remote -Q | awk -F"tag artist " '/tag artist/{print $2}'
}

get_file_tag() {
    local file=$1
    local tag=$2
    local id3tags=$(id3v2 -l $file)
    # Make sure the file has id3v2 tags.
    if [[ $id3tags =~ "No ID3v2 tag" ]]; then
        id3v2 --convert $file > /dev/null
    fi
    local pattern=$(printf '/%s/{print $2}' $tag)
    id3v2 -l $file | awk -F": " $pattern
}

artist_from_file() {
    get_file_tag $1 "(TPE1|TP1)"
}

update_file_genres() {
    local file genres
    genres=$1
    file=$2
    id3v2 --TCON $genres $file
}

monitor_folder() {
    local folder=$1
    inotifywait -m -r -e create -e moved_to --format '%w%f' "${folder}" 2>/dev/null | \
        while read newfile
        do
            if [[ -d $newfile ]]; then   # folder
                for file in $newfile/**/*.(mp3|MP3|flac|FLAC); do
                    add_genres_to_file $file
                done
            else                         # file
                add_genres_to_file $newfile
            fi
        done
}

add_genres_to_file() {
    local folder
    local file=$1
    if [[ ${file:l:e} = "mp3" ]]; then
        $SELF $file
    elif [[ ${file:l:e} = "flac" ]]; then
        flac_to_mp3 $file
        # Add genres after the artist tag is in place.
        folder=$(dirname $file)
        for file in $folder/**/*.mp3; do
            $SELF $file
        done
    fi                          # No other tagging taking place.
}

flac_to_mp3() {
    local artist track trackno year album inflac incue outmp3 folder
    inflac=$1
    folder=$(dirname $inflac)
    incue=${inflac:r}.cue
    outmp3=$(mktemp --suffix=.mp3)
    # Convert to mp3 file.
    ffmpeg -i $inflac -ab 192k -map_metadata 0 -y -id3v2_version 3 $outmp3 2>/dev/null
    mp3splt -c $incue -d $folder $outmp3 2>/dev/null      # Split the temp mp3 file.
    rm $outmp3
    # Add id3 tags to the resulting mp3 files. Can't seem to convince mp3splt
    # above to add them instead.
    artist=$(cat $incue | awk -F"PERFORMER " '/PERFORMER/{print $2; exit}' | \
             # Extra chars present in the cue string; play safe and remove them all.
             awk -F"\"" '{print $2}')
    album=$(cat $incue | awk -F"TITLE " '/TITLE/{print $2; exit}' | \
            awk -F"\"" '{print $2}')
    year=$(cat $incue | awk -F"REM DATE " '/REM DATE/{print $2}')
    for file in $folder/**/*.mp3; do
        track=$(basename $file | awk -F"- " '{print $3}')
        track=${track:r}        # remove extension
        trackno=$(basename $file | awk -F" - " '{print $2}')
        id3v2 -a $artist -t $track -y $year -A $album -T $trackno $file
    done
}

print_all_genres() {
    local db_path genres replaced
    db_path=$(db_location)
    for entry in $db_path/*; do
        # Replace spaces and split the genres at / and then append to array.
        : ${(A)genres::=$genres ${(@s:/:)$(cat $entry | sed 's/ /-/g')}}
    done
    : ${(A)genres::=${(u)genres[@]}} # unique genres only
    for genre in $genres; do
        echo $genre
    done
}

main() {
    local artist genres file
    file=""                     # only updated if parameter is a media file

    while getopts ":d:lpch" opt; do
        case $opt in
            d)                  # daemon mode
                monitor_folder $OPTARG
                ;;
            l)
                dump_log
                exit 0
                ;;
            p)
                print_all_genres
                exit 0
                ;;
            c)
                clear_log
                exit 0
                ;;
            h)
                echo $help_str
                exit 0
                ;;
        esac
    done
    shift $((OPTIND-1))
        
    # Figure out the artist name.
    if [[ $# -eq 0 ]]; then     # from cmus
        artist=$(cmus_artist)
    elif [[ $# -eq 1 ]]; then
        if [[ -d $1 ]]; then    # from folder
            for file in $1/**/*.mp3; do
                $SELF $file
            done
        elif [[ -a $1 ]]; then  # from file
            file=$1
            artist=$(artist_from_file $1)
            if [[ -z "${artist// /}" ]]; then
                save_to_log $1  # no artist info
                exit 1
            fi
        else                    # free-form string
            artist=$1
        fi
    fi

    genres=$(genres_from_db $artist)

    if [[ -z $genres ]]; then
        genres=$(genres_from_lastfm $artist)
        save_genres_to_db $artist $genres
    fi

    if [[ ! -z $file ]]; then
        update_file_genres $genres $file
    fi

    if [[ $# -eq 0 ]]; then
        echo $genres
    fi
}

main $@

