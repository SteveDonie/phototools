#! /bin/bash
aws s3 cp ~/albums/index.html s3://album.donie.us/
aws s3 sync ~/albums/incoming/ s3://album.donie.us/incoming --delete
aws s3 sync ~/albums/doniehome/ s3://album.donie.us/doniehome --delete
aws s3 sync ~/albums/projects/ s3://album.donie.us/projects --delete
