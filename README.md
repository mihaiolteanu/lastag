# lastag - tag mp3 files with music genres from last.fm

Cmus is great. One of the many nice features is the filter. Live filtering, saving filters,
combining filters, filter by genre, year, duration. All that. Depending on the mood, I
like to only listen to certain genres, but the mp3 files are not always helping. Genre tags
are either missing or they use the id3v1 tags, with only 255 genres available. Well, metal
has hundreds of variations, so that is close to useless.

Luckly, last.fm has all that I need in the genres arena. Every artist page has up to five
genre tags. So I'm grabing those and sticking them onto the mp3 files using id3v2. Job done.
Now I can filter away. Sweet.

## features
- tag a single mp3 file
- tag all the mp3 files in the given folder
- daemon mode; tag all new mp3 files added to that folder, recursively. If a flac file is
added instead, create nice little mp3 files out of that, and tag those. That is, until
cmus can [filter flac](https://github.com/cmus/cmus/issues/654) files. Of course, you might
want to either remove the flac file afterwards or only add the mp3 file to the cmus library.
Or even better, filter only the mp3 files
- with no parameters, echo the genre of the current playing song in cmus and exit
- Read -h for all the stuff

## install
``` shell
    sudo pacman -S id3v2 inotify-tools mp3splt
    git clone https://github.com/mihaiolteanu/lastag
    cd lastag
    sudo ./install.zsh
```

## usage
If you don't want the flac splitting, remove the mp3splt references from above and the install
file. Also remove the `elif` body from the `add_genres_to_file` function in the main application.

## bugs and stuff
File a complaint, I'll have a look.
