#! /bin/bash
echo Making handyman album and then syncing to S3

current_date_time=$(date +"%m/%d/%Y %H:%M")
echo -e "\nStarted at $current_date_time" > timing.txt

echo -e "\nTime to make Handyman album" >> timing.txt
{ time perl MakeAlbum.pl handyman.aws; } 2>> timing.txt

echo ------------
echo -e "\nTime to sync to S3" >> timing.txt
{ time ./syncHandyman.sh; } 2>> timing.txt

current_date_time=$(date +"%m/%d/%Y %H:%M")
echo -e "\nfinished at $current_date_time" >> timing.txt

cat timing.txt
