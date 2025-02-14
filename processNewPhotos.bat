:: process new photos
@echo off
echo Move photos from Dropbox\Camera Uploads to personal\tempPhotoProcessing
echo Then FixPhotoNames in tempPhotoProcessing 
echo Then FixMovies in tempPhotoProcessing
pause
move "C:\Users\Steve\Dropbox\Camera Uploads\*.*" c:\Users\Steve\personal\tempPhotoProcessing
cd c:\Users\Steve\personal\tempPhotoProcessing
call FixPhotoNames .
call FixMovies .
