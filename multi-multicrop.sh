#!/bin/sh

if [ $# -eq 0 ]
  then
  echo "Please supply a directory to work in."
  exit 0
fi

[ -d $1/crops ] || mkdir $1/crops

for file in "$1"/* ;do
  [ -f "$file" ] && echo "Processing '$file' and saving crops to $1crops"
  base=$(basename -- "$file")
  ./multicrop.sh -b \#CFD0CA -f 20 -d 500 $file $1/crops/$base 

done