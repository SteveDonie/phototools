# FixOldPhotoNames.pl
#
# Iterates through a directory with sub-directories named by YYYY-MM,
# looks at each of the JPG files there, and if they fit the pattern 
# NNNN - xxxxxxx.jpg, then 
#  1. Extract the YYYY-MM from the directory name
#  2. Extract the NNNN from the filename
#  3. Extract the caption part - the xxxxxx part of the filename. 
#  4. Change the date/time stamp on the file to be
#     YYYY-MM-NN:NN, and rename the JPG file to match that date/time stamp.
#  5. At the same time, take the caption part (xxxxxxx) and write that to a 
#     new .txt file that has the same name as the JPG, but contains the caption
#     info for the photo.
#
#     <!-- THUMBSPART:caption --> 
#      
#     <!-- THUMBSPART:comment --> 
#      
#     <!-- THUMBSPART:name --> 

use strict;
use File::Copy;
use File::stat;
use File::Basename;
use File::Spec;
use lib '.';
use v5.10;                     # minimal Perl version for \R support
use utf8; 

## Globals

## this is the main hash used for configuration options
my $config;


###############################################################################
## main execution starts here

my $starttime = time;

# Check the argument passed in. It should be a valid directory name. If there are
# any .jpg or .JPEG files in it, then treat it as a photos dir and just fix the files
# there. Otherwise, treat the directory as a top-level photos dir and recurse through
# all the subdirectories of the top-level dir and process each directory.
&get_config ();
if (! $config->{IsTopLevelDir}) {
  &processTopLevelDir($config->{directorySpecified})
} else {
  &processPhotosDir($config->{directorySpecified})
}


###############################################################################
## Everything below is subroutine definitions.

#-----------------------------------------------------------------------------
# There should be a single argument on the command line specifying a directory
# to process. Look at that directory to see if it has photos in it or not. Sets 
# a config setting IsTopLevelDir for the caller to use.
sub get_config ()
{
  my $specifiedDirectory = $ARGV[0];
  if ($specifiedDirectory) {
    if ($specifiedDirectory ne "") {
    }
  } else {
    die "You must specify a directory to work in. ".$specifiedDirectory." not found.\nExiting";
  }
}