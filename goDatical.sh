#! /bin/bash
cp ~/personal/websites/donie.us/index.html ~/albums/index.html
perl MakeAlbum.pl freakylove.datical
perl MakeAlbum.pl Incoming.datical
perl MakeAlbum.pl projects.datical
time ./synctos3.sh
