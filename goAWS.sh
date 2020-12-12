#! /bin/bash
cp ~/personal/donie.us/album-index.html ~/albums/index.html
perl MakeAlbum.pl Incoming.aws
perl MakeAlbum.pl projects.aws
time ./synctos3.sh
