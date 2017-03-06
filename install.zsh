#!/usr/bin/env zsh

exit_msg() {
    echo $1
    exit 1
}

# Check the dependencies.
type "id3v2" > /dev/null || exit_msg "id2v2 required"
type "inotifywait" > /dev/null || exit_msg "inotify-tools required"
type "mp3splt" > /dev/null || exit_msg "mp3splt required"

# Copy the executable to path.
cp lastag.zsh /usr/local/bin/lastag || exit 1
chmod +x /usr/local/bin/lastag

# Setup the database.
mkdir -p "$HOME/.lastag/"
