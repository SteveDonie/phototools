#! /bin/bash
echo Making just Steve album and then syncing to S3

current_date_time=$(date +"%m/%d/%Y %H:%M")
echo -e "\nStarted at $current_date_time" > timing.txt

cp ~/personal/donie.us/album-index.html ~/albums/index.html

echo -e "\nTime to make Personal" >> timing.txt
{ time perl MakeAlbum.pl Personal.aws; } 2>> timing.txt

echo -e "\nTime to sync to S3" >> timing.txt
{ time ./syncSteve.sh; } 2>> timing.txt

current_date_time=$(date +"%m/%d/%Y %H:%M")
echo -e "\nfinished at $current_date_time" >> timing.txt

cat timing.txt
