# dvdrip

Collection of shell scripts to almost fully automate the process of ripping my
DVD collection.

## Overview

1. Rip DVD
1. Eject DVD and send notification that it's done
1. Encode metadata and rename file to DVD title
1. Transfer to media server with rsync

## Dependencies

- [handbrake-cli](https://handbrake.fr) (for ripping)
- [noti](https://github.com/variadico/noti) (for notifying that the DVD rip is
  done)
- [atomicparsley](https://bitbucket.org/wez/atomicparsley) (for encoding
  metadata into the file)
- API key for [themoviedb.org](https://themoviedb.org/)
- rsync (for transferring to my media server)

## Quickstart

- I use this on Arch, I don't expect it to be immediately usable for others,
  mostly pushing to GitHub for my purposes but also may be useful as a
  template.
- Copy `config-sample.env` to `config.env` and add your data
- `sudo make`
- `sudo visudo` and add the hash to allow password-less execution of
  `/usr/local/bin/handbraker.sh`, example below.

```plaintext
username ALL=(ALL) NOPASSWD: sha256:HASHGOESHERE /usr/local/bin/handbraker.sh
```

The udev rule will automatically invoke `dvdrip@bluray.service` (or
`dvdrip@dvd.service`) when a DVD is inserted into the drive. This will send a
warning to the prompt that a DVD rip will begin in 60 seconds if the process
isn't stopped (e.g. `sudo systemctl kill dvdrip@bluray.service`). At that
point, the DVD is ripped, renamed, and transfered per the settings above.

`videomd.sh` can be used as a script independently to set metadata. If you run
`./videomd.sh myfile.mp4`, it will use the filename and set metadata based on
the most popular search result. If you instead run `./videomd.sh -s
myfile.mp4` or `./videomd.sh -s "my query here"`, it will instead display the
top page of results for you, from which you can manually choose an `id` and
then run with `./videomd.sh -i THE_ID myfile.mp4`.


### Notes

My shell scripting is not very good, I'm open to feedback. Especially on the
best way to pass the new video name from `videomd.sh` back to `autorip.sh` (in
order to be transfered back); my current strategy of "`echo` at the end and
pipe to `tail -n 1`" seems super hacky.

`handbraker.sh` is not set to have execute permissions because `HandbrakeCLI`
requires root permissions, so the Makefile puts it at a static location,
changes it to `0700 root:root`, then outputs the sha256 for a little extra
security when setting it as a `NOPASSWD` executable.

## License

The portions of this project that I have written are available under the MIT
license.
