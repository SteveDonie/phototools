#! /bin/bash
echo Making albums and then syncing to S3

current_date_time=$(date +"%m/%d/%Y %H:%M")
echo "started at $current_date_time" > timing.txt

cp ~/personal/donie.us/album-index.html ~/albums/index.html

echo Time to make Incoming >> timing.txt
{ time perl MakeAlbum.pl Incoming.aws; } 2>> timing.txt

echo Time to make Eastdale >> timing.txt
{ time perl MakeAlbum.pl Eastdale.aws; } 2>> timing.txt

echo Time to make Projects >> timing.txt
{ time perl MakeAlbum.pl projects.aws; } 2>> timing.txt

echo Time to sync to S3 >> timing.txt
{ time ./synctos3.sh; } 2>> timing.txt

current_date_time=$(date +"%m/%d/%Y %H:%M")
echo "finished at $current_date_time" >> timing.txt

cat timing.txt
