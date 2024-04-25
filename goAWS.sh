#! /bin/bash
echo Making albums and then syncing to S3

current_date_time=$(date +"%m/%d/%Y %H:%M")
echo -e "\nStarted at $current_date_time" > timing.txt

cp ~/personal/donie.us/album-index.html ~/albums/index.html

echo -e "\nTime to make Incoming" >> timing.txt
{ time perl MakeAlbum.pl Incoming.aws; } 2>> timing.txt

echo -e "\nTime to make Eastdale" >> timing.txt
{ time perl MakeAlbum.pl Eastdale.aws; } 2>> timing.txt

echo -e "\nTime to make East Third" >> timing.txt
{ time perl MakeAlbum.pl EastThird.aws; } 2>> timing.txt

echo -e "\nTime to make Projects" >> timing.txt
{ time perl MakeAlbum.pl projects.aws; } 2>> timing.txt

echo -e "\nTime to make ancestry album" >> timing.txt
{ time perl MakeAlbum.pl ancestry.aws; } 2>> timing.txt

echo -e "\nTime to make Handyman album" >> timing.txt
{ time perl MakeAlbum.pl handyman.aws; } 2>> timing.txt

echo -e "\nTime to sync to S3" >> timing.txt
{ time ./synctos3.sh; } 2>> timing.txt

current_date_time=$(date +"%m/%d/%Y %H:%M")
echo -e "\nfinished at $current_date_time" >> timing.txt

cat timing.txt
