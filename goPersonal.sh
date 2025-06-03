#! /bin/bash
echo Making personal albums and then syncing to S3

current_date_time=$(date +"%m/%d/%Y %H:%M")
echo -e "\nStarted at $current_date_time" > timing.txt

cp ~/personal/donie.us/album-index.html ~/albums/index.html

echo skipping family for now. Replacing all html files with \"Album Offline\"
cp ~/personal/donie.us/offline/index.html ~/albums/family/
# echo -e "\nTime to make Family" >> timing.txt
# { time perl MakeAlbum.pl Family.aws; } 2>> timing.txt

echo -e "\nTime to make Personal" >> timing.txt
{ time perl MakeAlbum.pl Personal.aws; } 2>> timing.txt

echo -e "\nTime to make Eastdale" >> timing.txt
{ time perl MakeAlbum.pl Eastdale.aws; } 2>> timing.txt

echo -e "\nTime to make East Third" >> timing.txt
{ time perl MakeAlbum.pl EastThird.aws; } 2>> timing.txt

echo -e "\nTime to make Projects" >> timing.txt
{ time perl MakeAlbum.pl projects.aws; } 2>> timing.txt

echo -e "\nTime to make ancestry album" >> timing.txt
{ time perl MakeAlbum.pl ancestry.aws; } 2>> timing.txt

echo -e "\nTime to sync to S3" >> timing.txt
{ time ./syncPersonal.sh; } 2>> timing.txt

current_date_time=$(date +"%m/%d/%Y %H:%M")
echo -e "\nfinished at $current_date_time" >> timing.txt

cat timing.txt
