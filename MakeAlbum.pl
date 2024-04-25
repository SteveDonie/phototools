# MakeAlbum.pl
#
# copyleft 1999-2017, Steve Donie <steve@donie.us>

use strict;
use File::Copy;
use File::stat;
use File::Basename;
use File::Spec;
use lib '.';


# see that file for more details. Gets EXIF data for pictures.
#require "getexif.pl";

# MakeAlbum.pl will take one argument, a la sitecopy:
# makealbum lonestar
# it will then read the file AlbumSettings.lonestar.txt file and extract the settings from there.
# if no argument is specified, it first looks for AlbumSettings.machinename.txt, then
# uses AlbumSettings.default.txt
#
# possible enhancements:
# better navigation on the left side. dynamic html?
# show size/number of pictures in each directory, graphically
# update the look
# add skinning
# searchability would be cool...embed Lucene?
# slideshow of ALL photos
# generate an RSS1/RSS2/Atom feed - done for RSS 2
#
# This goes through the directory specified in the setting PhotosDir
# and creates a matching directory structure at AlbumDir. It then uses a small
# Java program to create 2 jpg files from each jpg that exists in the orignal
# location - one at a "large" size, and one as a thumbnail. It also needs to
# create a web page for each directory, and a webpage that points to each
# subdirectory webpage.
#
###############################################################################
## Globals

## this is the main hash used for configuration options
my $config;

my $Verbose = 0;
my $Debug = 0;
my $JavaMemSize = 800;  # megabytes of memory Java might need to resize photos
                        # don't set this too high - if too high, it uses
                        # virtual memory, which thrashes the disk.
my $XMLLogName;

## convert numbers to names
my %monthname=('01','January',
               '02','February',
               '03','March',
               '04','April',
               '05','May',
               '06','June',
               '07','July',
               '08','August',
               '09','September',
               '10','October',
               '11','November',
               '12','December');

## convert numbers to names, single digits, for time
my %monthhash=('0','January',
               '1','February',
               '2','March',
               '3','April',
               '4','May',
               '5','June',
               '6','July',
               '7','August',
               '8','September',
               '9','October',
               '10','November',
               '11','December');

## convert numbers to names, single digits, for time
my %dayhash=('0','Sunday',
             '1','Monday',
             '2','Tuesday',
             '3','Wednesday',
             '4','Thursday',
             '5','Friday',
             '6','Saturday');

my @FinalInputDirs; # list of input directories to be used - includes IncludeDirs, skips SkipDirs. Sorted. Currently these are all relative to the config->photosdir
my %OutDirsHash;    # OutDirsHash is a hash that has the final outdir as the key and one or more of the final inputdirs as the values
my %OutDirsDisplayNames;
my @FinalOutputDirs;  # final list of output dirs to create (Unix valid names). Sorted.
my $AlbumSize = 0;
my $TotalPictures = 0;
my $SizeMessage;
my %tagshash;       # this is a hash. keys are tag names, values are arrays of paths.
my @stopwords;      # an array of stop words, not used for tags
my %is_stopword;    # hash made from that array since I'm a dummy and don't know how to do it directly,
                    # so I did what it said in perlfaq4 about finding an element in a list.


###############################################################################
## main execution starts here

my $starttime = time;

&get_config ();
open (XMLLOG,">".$XMLLogName);
&start_log ();
&log_config ();
&calc_final_dirs ();
&GetStopWords (); # have to do this here so stopwords aren't added during photo processing
&make_dirs ();
my $FinalOutputDirCount = @FinalOutputDirs;

# another check of SkipDirs to make iteration on front page changes faster
if (! $config->{SkipMakeDirs}) {
	&log ("\nChecking size of $config->{AlbumDir}\n\n","progress");
	$AlbumSize=&calc_size($config->{AlbumDir});
	$SizeMessage = "$config->{PhotosPageLink} has $TotalPictures pictures in $FinalOutputDirCount pages. (".&report_size ($AlbumSize). ")";
} else {
	$AlbumSize=100000;  # made up number
	$SizeMessage = "$config->{PhotosPageLink} is ".&report_size ($AlbumSize). " ($TotalPictures pictures)";
}	
&make_frontpage ($SizeMessage); 
&make_tagspages ();
&log ("$SizeMessage\n","info");
&report_time ($starttime);
&end_log ();
close XMLLOG;



###############################################################################
## Everything below is subroutine definitions.


#-----------------------------------------------------------------------------
## Read in options from AlbumSettings.albumname.txt which is a text file that
## looks like a Perl anonymous hash:
##
##  {
##    # set directory to find photos:
##    PhotosDir => 'c:\photos',
##
##    # set directory where web album is generated:
##    AlbumDir => 'c:\webalbum',
##
##    # set largest dimension of large photos, in pixels:
##    BigSize => 600,
##    }
##
## If no argument is specified, uses a default file AlbumSettings.machinename.txt
## (if that exists) or AlbumSettings.default.txt if not.
##
sub get_config ()
{
  if ($Debug) { print ("arguments are [@ARGV]\n"); }

  # if an argument was specified, then that file had better exist, or else
  # we should just quit. Don't use default or machinename if they gave a name!
  my $specifiedConfig = $ARGV[0];
  my $machineName = $ENV{"COMPUTERNAME"};
  my $WhichAlbum = "default";

  if ($specifiedConfig) {
    if ($specifiedConfig ne "") {
      if (-e "AlbumSettings.".$specifiedConfig.".txt") {
        $WhichAlbum = $specifiedConfig;
      } else {
        die "Configuration file AlbumSettings.".$specifiedConfig.".txt not found.\nExiting";
      }
    }
  } else {
    # no configuration specified. Check Machine Name
    if ($machineName) {
      if ($machineName ne "") {
        if (-e "AlbumSettings.".$machineName.".txt") {
          $WhichAlbum = $machineName;
        } else {
          print "Configuration file AlbumSettings.".$machineName.".txt not found, using default.\n";
        }
      }
    }
  }

  if (-e "AlbumSettings.".$WhichAlbum.".txt")
  {
    $XMLLogName = "MakeAlbumLog.".$WhichAlbum.".xml";

    $config = require "AlbumSettings.".$WhichAlbum.".txt";
    $config->{ConfigName} = $WhichAlbum;

    if (exists $config->{Debug} and $config->{Debug} == 1) {
    	$Debug = 1;
    }

  }
  else
  {
    print ("Could not find configuration file AlbumSettings.".$WhichAlbum.".txt");
    exit 1;
  }
}

#-----------------------------------------------------------------------------
# log the configuration settings
sub log_config
{
  &log ("----- Configuration in AlbumSettings.".$config->{ConfigName}.".txt -----\n","info");
  foreach my $opt (sort keys %$config)
  {
    &log ("$opt\t: $config->{$opt}\n","info");
  }
  &log ("\n","info");
  &log ("\nSorting Order\n","debug");

  my @sortorder = +(sort map { chr() } 32..255);
  my $sortorder = join ('',@sortorder);
  &log ($sortorder,"debug");

  # check that all required entries are there...
  my @requiredConfig = ("PhotosDir",
                        "AlbumDir",
                        "LargeSize",
                        "SmallSize",
                        "PhotoQuality",
                        "MainPageName",
                        "RSSFeedName",
                        "RSSFeedTitle",
                        "RSSCreator",
                        "RSSDescription",
                        "RSSImageURL",
                        "PageTitle",
                        "PhotosPageLink",
                        "email",
                        "BigPicLink",
                        "ThemeColor",
                        "ThemeText",
                        "HomePageName",
                        "HomePageURL",
                        "AlbumPageURL",
                        "SkipDirs",
                        "IncludeDirs",
                        "copyrightString");
  my $broken = 0;
  foreach my $opt (@requiredConfig) {
    if (!$config->{$opt}) {
      &log (" $opt is not set\n","info");
      $broken = 1;
    }
  }

  if ($config->{BigPicLink} eq "httpfullsize") {
    if (!$config->{FullSizeBaseURL}) {
       &log (" BigPicLink is set to httpfullsize, but FullSizeBaseURL is not set. Pictures will be copied! (can be slow)\n","info");
    }
  }

  if ($broken) {
    &log ("\nOne or more required options are not set in AlbumSettings.$config->{ConfigName}.txt.\n","info");
    die;
  }
}


#-----------------------------------------------------------------------------
# calc_final_dirs returns a list of short directory names that need to be
# processed. This list is used in the main processing loop and also when
# creating the navigation table.
sub calc_final_dirs ()
{
  my @jpgfiles;

  my @SkipDirs = split /,/, $config->{SkipDirs};
  my @IncludeDirs = split /,/, $config->{IncludeDirs};

  for my $skipdir (@SkipDirs) { &log ("Skip Pattern $skipdir\n","debug");  }
  for my $includedir (@IncludeDirs) { &log ("Include $includedir\n","debug"); }

  # create the array that contains directory names to process
  # need to make a master list of the dirs that will be created. This is used for two things:
  # processing directories of photos, and making the NavTable.
  # Skips any directories that start with a period, including '.', '..', and any other 'hidden' directories.
  opendir(DIR, $config->{PhotosDir}) || die "can't open directory '$config->{PhotosDir}': $!.\nYou may need to edit AlbumSettings.".$config->{ConfigName}.".txt to have the proper directory.\nStopped running";
  my @PhotoDirs = grep {-d "$config->{PhotosDir}/$_" and
                     substr($_, 0, 1) ne "."
                    } readdir(DIR);
  closedir DIR;

  my @SecondLevelDirs;
  for my $dir (@PhotoDirs) {
    my $fulldir = $config->{PhotosDir}."/".$dir;
    opendir(DIR, $fulldir) || die "can't open directory '$fulldir': $!";
    @jpgfiles = grep {-f "$fulldir/$_" and
                           /jpg$/i
                          } readdir(DIR);
    closedir DIR;

    if (@jpgfiles == 0) {
      &log ("Directory $fulldir has no jpg files!\n","info");
      opendir(DIR, $fulldir);
      my @SubDirs = grep {-d "$fulldir/$_" and
                        substr($_, 0, 1) ne "."
                        } readdir(DIR);
      closedir DIR;
      for my $subdir (@SubDirs) {
         push (@SecondLevelDirs, $dir."/".$subdir);
      }
    }
  }

  @PhotoDirs = (@PhotoDirs,@SecondLevelDirs);

  for my $dir (@PhotoDirs) {
    my $fulldir = $config->{PhotosDir}."/".$dir;

    whichdir: for my $includedir (@IncludeDirs) {
      &log ("checking if $fulldir matches include pattern $includedir ","debug");
      if ($fulldir =~ /($includedir)/i) {
        &log (" matched\n","debug");
        my $addable = 1;
        my $skipreason = "";
        for my $skipdir (@SkipDirs) {
          &log ("checking if $fulldir matches skip pattern $skipdir","debug");
          if ($fulldir =~ /($skipdir)/i) {
            &log (" matches - do not add!\n","debug");
            $addable = 0;
            $skipreason = $skipdir;
          }
          else
          {
            &log (" no match\n","debug");
          }
        }
        if ($addable)
        {
          # count how many JPG files there are in the original photos dir.
          opendir(DIR, $fulldir) || die "can't open directory '$fulldir': $!";
          @jpgfiles = grep {-f "$fulldir/$_" and
                                 /jpg$/i
                                } readdir(DIR);
          closedir DIR;

          # what if there are 0 files?
          if (@jpgfiles == 0) {
            &log ("Directory $fulldir has no jpg files!\n","info");
          } else {
            $TotalPictures += @jpgfiles;
            &log (" $dir didn't match any skip pattern - adding to final\n","debug");
            push (@FinalInputDirs, $dir);
          }
        }
        else
        {
          &log (" matched skip pattern $skipreason - not adding to final\n","debug");
        }
        next whichdir; # only add each directory once!!
      }
      else
      {
        &log (" no match - skipping\n","debug");
      }
    }
  }

  @FinalInputDirs = sort {$b cmp $a} (@FinalInputDirs);

  # now create the OutDirsHash, which is what we will really use - handle ZoomBrowser type directories and consolidate
  # those into months. Otherwise it gets even more ridiculous than by months!
  # Also keep track of the DisplayName for each OutputDir
  my $loglevel="debug";
  my @list = ();

  for my $dir (@FinalInputDirs) {
      my $OutDirName = &getUnixValidDirName($dir);
      push @{ $OutDirsHash{$OutDirName} }, $dir;

      my $OutDirDisplayName = &getDirDisplayName($dir);
      $OutDirsDisplayNames{$OutDirName} = $OutDirDisplayName;
  }
  @FinalOutputDirs = sort {$b cmp $a} keys %OutDirsHash;

  # this is an example of how to iterate over the hash

  foreach my $OutDir (@FinalOutputDirs)
  {
    if (@{ $OutDirsHash{$OutDir} })
    {
      my $OutDirDisplayName = $OutDirsDisplayNames{$OutDir};
      &log ("  OutDir $OutDir ($OutDirDisplayName) has input dirs...\n",$loglevel);
      @list = @{ $OutDirsHash{$OutDir} };
      foreach my $inputDir (@list) {
        &log ("    $inputDir\n",$loglevel);
      }
    }
  }

  &log ("Total number of pictures is $TotalPictures\n","info");
}

#-----------------------------------------------------------------------------
# make_dirs makes sure directory structure matches, and calls MakePage for each
# Output directory that is not supposed to be skipped.
sub make_dirs()
{
  # delete the LatestPics backup file if a backup exists AND the current one exists
  if (-e "LatestPics.$config->{ConfigName}.bak" and -e "LatestPics.$config->{ConfigName}.txt") {
    &log ("deleting LatestPics.$config->{ConfigName}.bak\n","info");
    unlink "LatestPics.$config->{ConfigName}.bak";
  }

  # make a backup copy of the LatestPics file
  if (-e "LatestPics.$config->{ConfigName}.txt") {
    &log ("renaming LatestPics.$config->{ConfigName}.txt to LatestPics.$config->{ConfigName}.bak\n","info");
    move "LatestPics.$config->{ConfigName}.txt", "LatestPics.$config->{ConfigName}.bak" or
      die "can't rename 'LatestPics.$config->{ConfigName}.txt' to 'LatestPics.$config->{ConfigName}.bak'\n$!";
  }

  if (!-e $config->{AlbumDir}) {
    mkdir $config->{AlbumDir},0777 or die "can't make directory '$config->{AlbumDir}' $!";
  }

  # Delete any directories in the AlbumDir that do not exist in the list of FinalOutputDirs.
  # Ignore any directories that start with a period, including '.', '..', and any other 'hidden' directories.
  # Also make sure we don't delete the 'tags' directory.
  opendir(DIR, $config->{AlbumDir}) || die "can't open directory '$config->{AlbumDir}': $!.\n";
  my @AlbumDirs = grep {-d "$config->{AlbumDir}/$_" and
                         substr($_, 0, 1) ne "." and
                         $_ ne "tags"
                        } readdir(DIR);
  closedir DIR;

  # compute the intersection and difference of AlbumDirs and FinalOutputDirs. The difference is the
  # list of directories to check for deletion from the AlbumDir. The intersection should always
  # be equal to the FinalOutputDirs list.
  my @union;
  my @intersection;
  my @difference;
  my %count;
  my $element;
  my $dir;

  # an interesting way to do set difference/union/intersection on arrays:
  # from http://www.perldoc.com/perl5.6.1/pod/perlfaq4.html#How-do-I-compute-the-difference-of-two-arrays---How-do-I-compute-the-intersection-of-two-arrays-
  @union = @intersection = @difference = ();
  %count = ();
  foreach $element (@AlbumDirs, @FinalOutputDirs) { $count{$element}++ }
  foreach $element (keys %count) {
      push @union, $element;
      push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
  }

  if (@difference > 0)
  {
    &log ("\nDirectories to delete:\n","info");
    for $dir (@difference) {
      my $goner = File::Spec->catdir($config->{AlbumDir},$dir);
      if (-e $goner) {
        my $globspec = File::Spec->catfile($goner,"*.*");
        my @goners = glob("'$globspec'");
        my $numGoners = @goners;
        &log ("  removing files in '$goner', which has $numGoners files\n","info");
#        if ($numGoners <= 0) {
#          &log ("bad globbing?")
#        }
        unlink @goners or warn "WARNING: can't delete files '@goners' $!";
        &log ("  deleting directory $goner\n","info");
        rmdir $goner or warn "WARNING: can't delete directory '$config->{AlbumDir}/$dir' $!";
      }
    }
    &log ("Done deleting directories.\n\n","info");
  }

  # DEBUGING MAKE FRONT PAGE - skip all the inner pages
  if (! $config->{SkipMakeDirs}) {
  # Now use FinalOutputDirs to make album pages.
	  for (my $index = 0; $index < @FinalOutputDirs; $index++) {
		my $outputDir = $FinalOutputDirs[$index];

		my $nextDir = $index == 0 ? "" : $FinalOutputDirs[$index-1];
		my $prevDir = $index == @FinalOutputDirs-1 ? "" : $FinalOutputDirs[$index+1];
		my $oneYearForwardDir = "";
		my $oneYearPrevDir = "";

		# I would like the prev year and next year to only be for directories (source and target) that are month-like,
		# and they should only count 'month-like' directories when counting. Just 12 ahead/behind is not great.
		if (DirIsMonthLike($outputDir)) {
			my $FinalOutputDirCount = @FinalOutputDirs;
			$oneYearForwardDir = GetSameMonthNextYear($outputDir);
			$oneYearPrevDir = GetSameMonthPrevYear($outputDir);
			if (! (grep(/^$oneYearForwardDir$/,@FinalOutputDirs))) {
				$oneYearForwardDir = "";
			}
			if (! (grep(/^$oneYearPrevDir$/,@FinalOutputDirs))) {
				$oneYearPrevDir = "";
			}
		}

		if (! -e $config->{AlbumDir}."/".$outputDir) {
		  &log ("making album directory $config->{AlbumDir}/$outputDir from pictures in @\n","verbose");
		  mkdir $config->{AlbumDir}."/".$outputDir,0777 or die "can't make directory '$config->{AlbumDir}/$outputDir' $!";
		}

		&log ("making page '$outputDir'. PrevDir is '$prevDir', NextDir is '$nextDir' PrevYear is '$oneYearPrevDir' NextYear is '$oneYearForwardDir'\n","verbose");
		&MakePage ($outputDir,$prevDir,$nextDir,$oneYearPrevDir,$oneYearForwardDir);
	  }
  } else {
	  &log ("\nSkipping making directory pages because SkipMakeDirs is true\n\n","info");
  }
  
  # if there is no LatestPics.configname.txt, then it must be because there were no new photos
  # added, so check if the .bak file is around and re-use that one.
  # BUGBUG - if no new photos were added, but captions were added, the front page won't
  # show the new captions. Argh! Regenerate?
  if (! -e "LatestPics.$config->{ConfigName}.txt" and -e "LatestPics.$config->{ConfigName}.bak") {
    &log ("No new photos added, renaming LatestPics.$config->{ConfigName}.bak to LatestPics.$config->{ConfigName}.txt\n","info");
    move "LatestPics.$config->{ConfigName}.bak", "LatestPics.$config->{ConfigName}.txt" or
      die "can't rename 'LatestPics.$config->{ConfigName}.bak' to 'LatestPics.$config->{ConfigName}.txt' $!";;
  }
}

# Given a directory, return true or false. If the directory is just a month and year, then
# return true, otherwise return false.
sub DirIsMonthLike ()
{
	my $DirToCheck = $_[0];  # will have unix valid dir name (just the last part of a path).
	my $retval = $DirToCheck =~ /^\d\d\d\d-\d\d$/;	
	return $retval;
}

# Given a directory, get the directory that represents the same month next year
sub GetSameMonthNextYear ()
{
	my $DirToCheck = $_[0];  # will have unix valid dir name (just the last part of a path).
	my $matches = $DirToCheck =~ /^(\d\d\d\d)-(\d\d$)/;
	my $currentYear = $1;
	my $currentMonth = $2;
	my $nextYear = $currentYear + 1;
	return $nextYear."-".$currentMonth;
}

# Given a directory, get the directory that represents the same month previous year
sub GetSameMonthPrevYear ()
{
	my $DirToCheck = $_[0];  # will have unix valid dir name (just the last part of a path).
	my $matches = $DirToCheck =~ /^(\d\d\d\d)-(\d\d$)/;
	my $currentYear = $1;
	my $currentMonth = $2;
	my $prevYear = $currentYear - 1;
	return $prevYear."-".$currentMonth;
}

#-----------------------------------------------------------------------------
# Make thumbnails, html files, and and index html file for a certain
# Output Directory, using all the photos in all its input directories.
#
# Takes 5 arguments
#   - the OutputDirectory, which is a UnixValidDirName, and is
#     used as a key into the OutDirsHash and OutDirsDisplayNames hash.
#   - the previousOutputDir, also a UnixValidDirName
#   - the nextOutputDir, also a UnixValidDirName
#   - the oneYearPreviousOutputDir (same)
#   - the oneYearForwardOutputDir (same)
# This function is FAR too large, but it would be a pain to refactor, because it
#
# uses a lot of arrays that are needed all the way through. Those arrays should be
# refactored to be one simpler data structure, but I am not sure what to make that
# look like.
#
# For each JPG file in the original directory, use the java Thumbnail program
# to make 2 new JPG files - one large, one small, whose names are valid Unix
# names. The large picture will have a name like the original name, but with any
# invalid characters removed. The small picture will have a name the same as the
# large picture, but with _sm tacked on the end.
#
# An HTML index file will be created at the same time, using the original filename as
# the caption. The layout of the HTML file is 3 columns of small photos with
# captions underneath, each linked to an HTML page for that picture that shows the
# large picture in the middle, plus thumbnails to the left and right - this allows
# the user to easily 'flip' through the photos.
#
# If there is a file named summary.txt in the directory, the contents of this file will 
# be added as a paragrpah at the top of that directory's page. 
#
#ComeBackHere
sub MakePage ()
{
  my $NeedNewHTML = 0; # if 1, means pictures were added, so need new index page and
                       #       new HTML for each picture.
  my $NeedSmall = 0; # if 1, means that we need to create 1 or more small images
  my $NeedLarge = 0; # if 1, means that we need to create 1 or more large images

  my $OutputDir = $_[0];  # will have unix valid dir name of output dir. Key to OutDirsHash, which has a list of input dirs.
  my $PrevOutDir = $_[1];
  my $NextOutDir = $_[2];
  my $OneYearPrevOutDir = $_[3];
  my $OneYearForwardOutDir = $_[4];

  my $BasePhotosDir = $config->{PhotosDir};

  my $NewFullDir;        # NewDir + UnixValidDirName
  my $PrevFullDir;       # NewDir + UnixValidPrevDirName
  my $NextFullDir;       # NewDir + UnixValidNextDirName
  my $index;
  my $picfilename;
  my @unsortedfiles;
  my @filenames;         # original file name & extension, with no path
  my @picnames;          # original long name with spaces, etc., but no extension or "."
  my @picexts;           # the extension (should always be .jpg!)
  my @NewFileNames;      # new file name (no invalid chars), no extension
  my @InputPicFileFullNames; # original filename with full path & extension
  my @NewLargeFullNames; # filename for the large picture with full path & extension
  my @NewSmallFullNames; # filename for the thumbnail with full path & extension
  my @HTMLFileNames;     # filename for the HTML page, full path and extension
  my @CaptionFileNames;  # filename to look for for captions - same name as original, .txt extension
  my @InfoFileNames;     # filename to look for for width,height - same name as original, .info extension
  my @InfoSmallFileNames;# filename to look for for width,height of thumbnail- original_sm.info

  my @picCaptions;       # caption for the picture - picname without 'dddd - ' at beginning,
                         # or this may be read from the matching .txt file
  my @picComments;       # if read from auxilliary file, some comments on the picture
  my @picAltNames;       # if read from auxilliary file, an alternate name
  my @picLinks;          # if BigPicLink is set, this has the link to use
  my @picHeights;        # picture heights
  my @picWidths;         # picture widths
  my @thumbHeights;      # thumbnail heights
  my @thumbWidths;       # thumbnail widths

  my $picName;
  my $picpath;
  my $picsuffix;
  my $NewFileName;
  my $picCaption;
  my $command;
  my $CurrentPageName;
  my $filename;
  my $dirname;
  my $LinkDisplayName;
  my $ColumnCount;
  my $summaryFileName;
  my $summaryInfo;


  $NewFullDir = $config->{AlbumDir}."/".$OutputDir;

  # to improve performance, we write out the names of the pictures that need to be resized,
  # so that the java re-sizer can just run once per directory per size instead of once per photo.
  # It would be nice to refactor this again so that it does all the photos in all the
  # directories in all the sizes in one swell foop.

  # the resize list is currently kept in two files, one per size. The file contains
  # first the size to resize, then the JPEG quality, then 0 or 1 for special panoramic
  # handling, then a list of lines
  # OriginalName::NewName
  # the small thumbnails get no special panoramic handling, but the large ones do.

  # initialize the resize lists
  open (RESIZELISTSM,">TempResizeList_sm.txt");
  print (RESIZELISTSM "$config->{SmallSize}\n");
  print (RESIZELISTSM "$config->{PhotoQuality}\n");
  print (RESIZELISTSM "0\n");
  close (RESIZELISTSM);

  open (RESIZELIST,">TempResizeList.txt");
  print (RESIZELIST "$config->{LargeSize}\n");
  print (RESIZELIST "$config->{PhotoQuality}\n");
  print (RESIZELIST "1\n");
  close (RESIZELIST);

  # Create arrays of:
  #   filenames             original file name & extension, with no path
  #   picnames              original long name with spaces, etc., but no path, extension or "."
  #   picexts               the extension (should always be .jpg!)
  #   NewFileNames          new file name (no invalid chars), no extension
  #   picCaptions           caption for the picture
  #   picComments           longer comments for each picture
  #   picAltNames           Alternate names for the pictures (not used!)
  #   picLinks              for certain settings, large photos have a link.
  #   InputPicFileFullNames original filename with full path & extension
  #   NewLargeFullNames     filename for the large picture with full path & extension
  #   NewSmallFullNames     filename for the thumbnail with full path & extension
  #   HTMLFileNames         filename for the HTML page, full path and extension

  my $DirDisplayName = $OutDirsDisplayNames{$OutputDir};
  &log ("Creating $OutputDir ($DirDisplayName)\n","progress");

  my @inputDirs = @{ $OutDirsHash{$OutputDir} };
  @filenames = ();
  foreach my $inputDir (@inputDirs)
  {
    &log ("    processing files in $inputDir\n","verbose");

    # first create the array of JPG files we need to process in the original
    # photos dir.
    my $fullInputDir = $BasePhotosDir."/".$inputDir;
    opendir(DIR, $fullInputDir) || die "can't open directory '$fullInputDir': $!";
    @unsortedfiles = grep {-f "$fullInputDir/$_" and
                           /jpg$/i
                          } readdir(DIR);
    closedir DIR;

    foreach my $file (@unsortedfiles) {
    		$file = $inputDir."/".$file;
    }

    @filenames = (@filenames, @unsortedfiles);

    # If there is a file named summary.txt in the directory, read that in and
    # use the content as a header on the page that shows all the thumbnails.
    $summaryFileName = $fullInputDir."/summary.txt";
    if (-e $summaryFileName) {
      &log(" Summary file $summaryFileName found\n", "info");
      open my $fh, '<', $summaryFileName or die "Can't open file $!";

      $summaryInfo = do { local $/; <$fh> };
      
      close (SUMMARYFILE);
      &log(" Summary Info: $summaryInfo\n", "debug");
    }
  }

  # need to sort filenames
  @filenames = sort (@filenames);

  # debugging output
  &log ("\nInput files for $DirDisplayName\n","debug");
  for $picfilename (@filenames) 
  {
      &log ("  $picfilename\n","debug");
  }

  # now actually iterate over the filenames, creating all the data for each.
  $index = 0;
  $NeedNewHTML = $config->{CleanHTML} or 0;
  for $picfilename (@filenames) {
    &log ("looking at file '$picfilename'\n","debug");
    ($picName,$picpath,$picsuffix) = fileparse ($picfilename);

    ($picnames[$index],
     $NewFileNames[$index],
     $picAltNames[$index],
     $picCaptions[$index],
     $picComments[$index],
     $picLinks[$index]) = &GetPictureInfo($picpath,$picName,$NewFullDir);

    $InputPicFileFullNames[$index] = $BasePhotosDir."/".$picpath."/".$picName;
    $NewLargeFullNames[$index] = $NewFullDir."/".$NewFileNames[$index].".jpg";
    $NewSmallFullNames[$index] = $NewFullDir."/".$NewFileNames[$index]."_sm.jpg";
    $HTMLFileNames[$index] = $NewFullDir."/".$NewFileNames[$index].".htm";
    $CaptionFileNames[$index] = $BasePhotosDir."/".$picnames[$index].".txt";
    $InfoFileNames[$index] = $NewFullDir."/".$NewFileNames[$index].".info";
    $InfoSmallFileNames[$index] = $NewFullDir."/".$NewFileNames[$index]."_sm.info";

    my $OriginalFileStat = stat($InputPicFileFullNames[$index]);

    # would be better to do these all at once for performance reasons, rather than exec jhead for every photo.
    if ($config->{AutoRotate})
    {
      &log ("Auto-Rotating $InputPicFileFullNames[$index]\n","verbose");;
      $command = "jhead -autorot \"".$InputPicFileFullNames[$index]."\"";
      &log ("$command\n","debug");
      my $RetVal = system $command;
      $RetVal /= 256;
      &log ("returned $RetVal\n","debug");
      if ($RetVal > 0)
      {
        &log ("jhead -autorot returned $RetVal, which is bad!\n","progress");
        die "jhead -autorot returned $RetVal, which is bad!\n";
      }
    }

    if (!-e $HTMLFileNames[$index] or
        &FileTimeIsNewer($CaptionFileNames[$index],$HTMLFileNames[$index]))
    {
      $NeedNewHTML = 1;
    }

    my $NeedThisSmall = 0; # if 1, means that we need to create 1 or more small images
    my $NeedThisLarge = 0; # if 1, means that we need to create 1 or more large images

    if (&FileIsZeroSize($NewSmallFullNames[$index]) or
        &FileTimeIsNewer($InputPicFileFullNames[$index],$NewSmallFullNames[$index]))
    {
      &log ("need small images\n","debug");
      $NeedThisSmall=1;
      $NeedSmall=1;
      $NeedNewHTML = 1;

      if (!$config->{"SkipThumbnails"})
      {
        &log ("adding file to resizelist_sm\n","debug");
        open (RESIZELISTSM,">>TempResizeList_sm.txt");
        print (RESIZELISTSM "$InputPicFileFullNames[$index]::$NewSmallFullNames[$index]\n");
        close (RESIZELISTSM);

        # do it this way so we don't create empty files...
        open (LATESTPICSFILE,">>LatestPics.$config->{ConfigName}.txt");
        print (LATESTPICSFILE "$DirDisplayName;$OutputDir;$picCaptions[$index];$NewFileNames[$index]\n");
        close (LATESTPICSFILE);
      }
    }

    if (&FileIsZeroSize($NewLargeFullNames[$index]) or
        &FileTimeIsNewer($InputPicFileFullNames[$index],$NewLargeFullNames[$index]) or
        (!-e $InfoFileNames[$index] and !$config->{"SkipHTML"}))
    {
      &log ("need large images\n","debug");
      $NeedThisLarge = 1;
      $NeedLarge=1;
      $NeedNewHTML = 1;
      &log ("adding file to resizelist\n","debug");
      open (RESIZELIST,">>TempResizeList.txt");
      print (RESIZELIST "$InputPicFileFullNames[$index]::$NewLargeFullNames[$index]\n");
      close (RESIZELIST);
    }

    $index++;
  }
  #die "end of test";
  &log ("finished going over filenames. NeedSmall=$NeedSmall NeedLarge=$NeedLarge NeedNewHTML=$NeedNewHTML\n","debug");


  if ($NeedSmall)
  {
    &log ("Processing photos listed in TempResizeList_sm.txt\n","verbose");;
    # now process the resize lists
    $command = "java -Djava.awt.headless=true -Xmx".$JavaMemSize."m -cp \".\" Thumbnail TempResizeList_sm.txt";
    &log ("$command\n","debug");
    my $RetVal = system $command;
    $RetVal /= 256;
    &log ("returned $RetVal\n","debug");
    &log ("\n","progress");
    if ($RetVal > 0)
    {
      &log ("java resize returned $RetVal, which is bad!\n","progress");
      die "java resize returned $RetVal, which is bad!\n";
    }
  }

  if ($NeedLarge)
  {
    &log ("Processing photos listed in TempResizeList.txt\n","verbose");;
    $command = "java -Djava.awt.headless=true -Xmx".$JavaMemSize."m -cp \".\" Thumbnail TempResizeList.txt";
    &log ("$command\n","debug");
    my $RetVal = system $command;
    $RetVal /= 256;
    &log ("returned $RetVal\n","debug");
    &log ("\n","progress");
  }

  #---- this is a hack! ----------
  # I made the java thumbnailer write out a .info file for each picture that has its
  # size. Need to read all those in and add that info to our master arrays. Need a better data structure...

  # parse this
  # <!-- INFO:width -->
  # 800
  # <!-- INFO:height -->
  # 600
  &log ("getting widths and heights\n","debug");

  for ($index = 0; $index < @filenames; $index++)
  {
    $picWidths[$index] = 800;
    $picHeights[$index] = 600;
    if (-e "$InfoFileNames[$index]")
    {
      &log ("opening $InfoFileNames[$index]\n","verbose");

      open (INFOFILE,"<$InfoFileNames[$index]") or die "could not open info file $InfoFileNames[$index] $!";

      my $state="none";
      my $found;

      while (<INFOFILE>)
      {
        chomp;
        if (($found) = ($_ =~ /^<!--/))
        {
          if ($_ eq "<!-- INFO:width -->")
          {
            $state="width";
          }
          elsif ($_ eq "<!-- INFO:height -->")
          {
            $state="height";
          }
        }
        else
        {
          if ($state eq "width")
          {
            $picWidths[$index] = $_;
          }
          elsif ($state eq "height")
          {
            $picHeights[$index] = $_;
          }
        }
      }
      close (INFOFILE);
    }
    else
    {
      &log ("warning - couldn't find $InfoFileNames[$index]\n","verbose");
    }
  }

  # read info files for thumbs also. This is so icky. Need a method that gets an InfoStruct for a picture,
  # or something like that. Perhaps exif stuff would be workable? ICKY ICKY ICKY.
  for ($index = 0; $index < @filenames; $index++)
  {
    $thumbWidths[$index] = 200;
    $thumbHeights[$index] = 200;
    if (-e "$InfoSmallFileNames[$index]")
    {
      &log ("opening $InfoSmallFileNames[$index]\n","verbose");

      open (INFOFILE,"<$InfoSmallFileNames[$index]") or die "could not open info file $InfoSmallFileNames[$index] $!";

      my $state="none";
      my $found;

      while (<INFOFILE>)
      {
        chomp;
        if (($found) = ($_ =~ /^<!--/))
        {
          if ($_ eq "<!-- INFO:width -->")
          {
            $state="width";
          }
          elsif ($_ eq "<!-- INFO:height -->")
          {
            $state="height";
          }
        }
        else
        {
          if ($state eq "width")
          {
            $thumbWidths[$index] = $_;
          }
          elsif ($state eq "height")
          {
            $thumbHeights[$index] = $_;
          }
        }
      }
      close (INFOFILE);
    }
    else
    {
      &log ("warning - couldn't find $InfoSmallFileNames[$index]\n","verbose");
    }
  }

  &log ("about to make HTML\n","debug");

  my $numPhotos = @filenames;
  $CurrentPageName = $OutputDir;
  if ($NeedNewHTML and !$config->{"SkipHTML"})
  {
    # Make the HTML for each picture. If we need 1 HTML page, might as well
    # make them all to make sure it's all correct!
    my $photoNum;
    for ($index = 0; $index < @filenames; $index++)
    {
        $photoNum = $index+1;
        if ($Verbose or $Debug)
        {
          &log ("Creating HTML Page ".$HTMLFileNames[$index]."\n","info");
        }
        else
        {
          &log ("#","progress");
        }
        # Make the HTML page for this photo.
        open (PICHTML,">".$HTMLFileNames[$index]) or die "Can't create HTML File '$HTMLFileNames[$index]' $!";
        my $LargePicInstructions = "";

        if (!$picLinks[$index] eq "") {
          if ($config->{BigPicLink} eq "request") {
            $LargePicInstructions = "Click the large photo to request a full size copy by email.";
          }
          if ($config->{BigPicLink} eq "localfullsize") {
            $LargePicInstructions = "Click the large photo to see the full size version. (local filesystem)";
          }
          if ($config->{BigPicLink} eq "httpfullsize") {
            $LargePicInstructions = "Click the large photo to see the full size version.";
          }
        }

        my $previousCell;
        my $previousLink = "";
        if ($index == 0)
        {
          # link to previous month
          if ($PrevOutDir eq "")
          {
            $previousCell = "&nbsp;\n";
          }
          else
          {
            my $PrevDirDisplayName = $OutDirsDisplayNames{$PrevOutDir};
            $previousLink = "../$PrevOutDir/$PrevOutDir.html";
            $previousCell = "Back to<br/><a href=\"$previousLink\">$PrevDirDisplayName</a>\n";
          }
        }
        else
        {
          $previousLink = "$NewFileNames[$index-1].htm";
          $previousCell = "<A href=\"$previousLink\">";
          $previousCell = $previousCell."<IMG SRC=\"$NewFileNames[$index-1]_sm.jpg\" BORDER=\"0\" ALT=\"$picCaptions[$index-1]\"></A><BR/>\n";
          $previousCell = $previousCell."$picCaptions[$index-1]<BR/>\n";
        }

        my $nextCell;
        my $nextLink = "";
        if ($index+1 == @filenames)
        {
          # link to next month
          if ($NextOutDir eq "")
          {
            $nextCell = "&nbsp;\n";
          }
          else
          {
            my $NextDirDisplayName = $OutDirsDisplayNames{$NextOutDir};
            $nextLink = "../$NextOutDir/$NextOutDir.html";
            $nextCell = "Continue on to<br/><a href=\"$nextLink\">$NextDirDisplayName</a>\n";
          }
        }
        else
        {
          $nextLink = "$NewFileNames[$index+1].htm";
          $nextCell = "<A href=\"$nextLink\">";
          $nextCell = $nextCell."<IMG SRC=\"$NewFileNames[$index+1]_sm.jpg\" BORDER=\"0\" ALT=\"$picCaptions[$index+1]\"></A><BR/>\n";
          $nextCell = $nextCell."$picCaptions[$index+1]<BR/>\n";
        }

my $HTML = <<HTML;
<!DOCTYPE html>
<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en\" xml:lang=\"en\">
  <head>
    <title>$DirDisplayName</title>
    <link href="../TwoColumn.css" rel="stylesheet" type="text/css">
    <link href="../basic.css" rel="stylesheet" type="text/css">
  </head>
HTML
  print (PICHTML $HTML);

  my $PageWidth = $config->{SmallSize} + $config->{SmallSize} + $picWidths[$index] + 24;
  $PageWidth = $PageWidth . "px";

$HTML = <<HTML;
  <body>
    <div id="header">
      <div class="toptitle">
        <a href="$config->{HomePageURL}">$config->{HomePageName}</a>
        <a href="../$config->{MainPageName}">$config->{PhotosPageLink}</a>
        <a href="$CurrentPageName.html">$DirDisplayName</a>
        <a href="javascript:void(window.open('slideshow.html?$index','slidecontrol','width=133,height=112,top=10,left=10,screenx=10,screeny=10'))">slideshow</a>
      </div>
HTML
  print (PICHTML $HTML);

$HTML = <<HTML;
      <div class="spacer"/>
      <!-- spiffy rounded corners, from http://www.spiffycorners.com/ -->
      <div>
        <b class="spiffy">
        <b class="spiffy1"><b></b></b>
        <b class="spiffy2"><b></b></b>
        <b class="spiffy3"></b>
        <b class="spiffy4"></b>
        <b class="spiffy5"></b></b>

        <div class="spiffyfg">
            <div class="instructionlineleft">Click on a the small photos or the '&lt;&lt;' or '&gt;&gt;' to 'flip' through them. $LargePicInstructions</div>
            <div class="instructionlineright">photo $photoNum of $numPhotos</div>
        </div>

        <b class="spiffy">
        <b class="spiffy5"></b>
        <b class="spiffy4"></b>
        <b class="spiffy3"></b>
        <b class="spiffy2"><b></b></b>
        <b class="spiffy1"><b></b></b></b>
      </div>
    </div>
    <div class="spacer"> </div>
HTML
  print (PICHTML $HTML);

$HTML = <<HTML;
    <div class="leftalign">
      <a href="$previousLink" title="previous">&lt;&lt;</a>
    </div>
    <div class="rightalign">
      <a href="$nextLink" title="next">&gt;&gt;</a>
    </div>
    <div class="spacer"></div>
    <div class="pics" style="width: $PageWidth">

<TABLE ALIGN="CENTER" CELLSPACING="0" CELLPADDING="4%">
<TR>
  <!-- stuff for the left (small) picture -->
  <TD VALIGN="CENTER" HALIGN="CENTER" WIDTH="$config->{SmallSize}">
    <CENTER>$previousCell</CENTER>
  </TD>
  <!-- stuff for the center (large) picture -->
  <TD VALIGN="CENTER" HALIGN="CENTER" WIDTH="$config->{LargeSize}">
    <CENTER>
HTML
        print (PICHTML $HTML);
        # put in the link
        if (!$picLinks[$index] eq "") {
           print (PICHTML $picLinks[$index]);
        }
        print (PICHTML "<img border=\"0\" src=\"$NewFileNames[$index].jpg\" alt=\"$picCaptions[$index]\"><BR/>\n");
        if (!$picLinks[$index] eq "") {
           print (PICHTML "</a>\n");
        }


$HTML = <<HTML;
    $picCaptions[$index]<BR/>
    <font size="2">$picComments[$index]</font><BR/>
    </CENTER>
  </TD>

  <!-- stuff for the right (small) picture -->
  <TD VALIGN="CENTER" HALIGN="CENTER" WIDTH="$config->{SmallSize}">
   <CENTER>$nextCell</CENTER>
  </TD>
</TR>
</TABLE>
</div>
HTML
        print (PICHTML $HTML);

        print (PICHTML &PageFooter());
        print (PICHTML "</body>\n</html>\n");

        close PICHTML;
    } # end of loop over items in array
  } # end if need new HTML
  &log ("\n","progress");

  if ($config->{BigPicLink} eq "httpfullsize") {
    if (!$config->{FullSizeBaseURL}) {
      for ($index = 0; $index < @filenames; $index++)
      {
        if (&copyifnewer ($InputPicFileFullNames[$index],$NewFullDir,$NewFileNames[$index]."_lg.jpg")) {
          &log ("*","progress");
		}
      }
      	&log ("\n","progress");
    }
  }


  #------------------------------------------------------------------------------------------------------
  # Make Index page
  #------------------------------------------------------------------------------------------------------

  if (!$config->{"SkipHTML"})
  {
      # calculate the size of this dir for the header line
      my $PageSize = &report_size (&calc_size($NewFullDir));

      $filename = $NewFullDir."/".$OutputDir.".html";

      # make the index page
      if ($Verbose or $Debug)
      {
        &log ("Creating Index Page ".$filename."\n","info");
      }
      else
      {
        &log ("!","progress");
      }

      # stuff to go forward and backwards through months and years
      my $previousLink;
      my $previousCell = "&nbsp;";
      my $oneYearPreviousLink;
      my $oneYearPreviousCell = "&nbsp;";
      my $nextLink;
      my $nextCell = "&nbsp;";
      my $oneYearForwardLink;
      my $oneYearForwardCell = "&nbsp;";

      my $PrevDirDisplayName = $OutDirsDisplayNames{$PrevOutDir};
      if (defined $PrevDirDisplayName && "" ne $PrevDirDisplayName) {
        $previousLink = "../$PrevOutDir/$PrevOutDir.html";
        $previousCell = "<a href=\"$previousLink\">&lt; $PrevDirDisplayName</a>";
      }

      my $NextDirDisplayName = $OutDirsDisplayNames{$NextOutDir};
      if (defined $NextDirDisplayName && "" ne $NextDirDisplayName) {
        $nextLink = "../$NextOutDir/$NextOutDir.html";
        $nextCell = "<a href=\"$nextLink\">$NextDirDisplayName &gt;</a>";
      }

      my $OneYearPrevDirDisplayName = $OutDirsDisplayNames{$OneYearPrevOutDir};
      if (defined $OneYearPrevDirDisplayName && "" ne $OneYearPrevDirDisplayName) {
        $oneYearPreviousLink = "../$OneYearPrevOutDir/$OneYearPrevOutDir.html";
        $oneYearPreviousCell = "<a href=\"$oneYearPreviousLink\">&lt; $OneYearPrevDirDisplayName</a>";
      }

      my $OneYearForwardDirDisplayName = $OutDirsDisplayNames{$OneYearForwardOutDir};
      if (defined $OneYearForwardDirDisplayName && "" ne $OneYearForwardDirDisplayName) {
        $oneYearForwardLink = "../$OneYearForwardOutDir/$OneYearForwardOutDir.html";
        $oneYearForwardCell = "<a href=\"$oneYearForwardLink\">$OneYearForwardDirDisplayName &gt;</a>"; 
      }

      open (OUTFILE,">".$filename);
      &log ("  $config->{PageTitle} - $DirDisplayName\n","debug");
      &log ("  $config->{HomePageURL}, $config->{HomePageName}\n","debug");
      &log ("  $index\n","debug");
      &log ("  $DirDisplayName has $numPhotos photos ($PageSize)\n","debug");

my $HTML = <<HTML;
<!DOCTYPE html>
<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en\" xml:lang=\"en\">
  <head>
    <title>$config->{PageTitle} - $DirDisplayName</title>
    <link href="../TwoColumn.css" rel="stylesheet" type="text/css">
    <link href="../basic.css" rel="stylesheet" type="text/css">
  </head>
HTML
      print (OUTFILE $HTML);

$HTML = <<HTML;
  <body>
    <div id="header">
      <div class="toptitle">
        <a href="$config->{HomePageURL}">$config->{HomePageName}</a>
        <a href="../$config->{MainPageName}">$config->{PhotosPageLink}</a>
        <a href="$CurrentPageName.html">$DirDisplayName</a>
        <a href="javascript:void(window.open('slideshow.html?$index','slidecontrol','width=133,height=112,top=10,left=10,screenx=10,screeny=10'))">slideshow</a>
      </div>
HTML
      print (OUTFILE $HTML);

$HTML = <<HTML;
      <div class="spacer"/>
      <!-- spiffy rounded corners, from http://www.spiffycorners.com/ -->
      <div>
        <b class="spiffy">
        <b class="spiffy1"><b></b></b>
        <b class="spiffy2"><b></b></b>
        <b class="spiffy3"></b>
        <b class="spiffy4"></b>
        <b class="spiffy5"></b></b>

        <div class="spiffyfg">
            <div class="instructionlineleft">Click on a photo for a larger version</div>
            <div class="instructionlineright">$DirDisplayName has $numPhotos photos ($PageSize)</div>
        </div>

        <b class="spiffy">
        <b class="spiffy5"></b>
        <b class="spiffy4"></b>
        <b class="spiffy3"></b>
        <b class="spiffy2"><b></b></b>
        <b class="spiffy1"><b></b></b></b>
      </div>
    </div>
    <div class="spacer"/>
    <div id="wrapper">
        <div class="rightalign">
          <a href="$NewFileNames[0].htm" title="first photo">&gt;&gt;</a>
        </div>
HTML
      print (OUTFILE $HTML);

      # create navigation table
      &PrintNavTable ($DirDisplayName);

      # now create the table of photos

$HTML = <<HTML;
    <div id="block_2">
         <div class="leftalign">
            $previousCell
			&nbsp;
            $oneYearPreviousCell
          </div>
          <div class="rightalign">
            $oneYearForwardCell
			&nbsp;
            $nextCell
          </div>
          <div class="spacer"/>
          
HTML
      print (OUTFILE $HTML);

      # if there is something in the summary.txt file...
      if ($summaryInfo ne "")
      {
$HTML = <<HTML;
          <p class="summary">
          $summaryInfo
          </p>
HTML
        print (OUTFILE $HTML);
      }
      
      for ($index = 0; $index < @filenames; $index++)
      {
        # add HTML for this picture to the index page for this directory
    $HTML = <<HTML;
          <div class="float">
            <p class="centeredImage">
              <a href="$NewFileNames[$index].htm">
                <img src="$NewFileNames[$index]_sm.jpg" border="0" alt="$picCaptions[$index]" />
              </a>
            </p>
            <p class="picCaption">$picCaptions[$index]</p>
          </div>
HTML
          print (OUTFILE $HTML);
      }

$HTML = <<HTML;
    <div class="spacer"/>
    <div class="leftalign">
      $previousCell
    </div>
    <div class="rightalign">
      $nextCell
    </div>
    <div class="spacer"/>
HTML
      print (OUTFILE $HTML);
      print (OUTFILE &PageFooter());
      print (OUTFILE "</body>\n");
      print (OUTFILE "</html>\n");
      close (OUTFILE);
  }

  #------------------------------------------------------------------------------------------------------
  # Make Slideshow page
  #------------------------------------------------------------------------------------------------------

  if (!$config->{"SkipHTML"}) {
    if (-e "slideshowtemplate.html")
    {
      if ($Verbose or $Debug)
      {
        &log ("Creating slidesshow Page\n","info");
      }
      else
      {
        &log ("!","progress");
      }
      &log ("opening slideshowtemplate.html\n","verbose");

      open (SLIDEFILE,"<slideshowtemplate.html") or die;
      open (OUTSLIDEFILE,">".$NewFullDir."/slideshow.html") or die;

      while (<SLIDEFILE>)
      {
        chomp;
		my $infoHereTag = "-- INFOHERE --";
		if (substr($_, 0, length($infoHereTag)) eq $infoHereTag)
        {
          &log ("Found INFOHERE tag, adding to OUTSLIDEFILE\n","debug");
          for ($index = 0; $index < @filenames; $index++)
          {
            #while processing captions, need to escape stuff to make valid urls
            my $CaptionURL;
            &log ("picCaption is $picCaptions[$index]\n","debug");
            ($CaptionURL = $picCaptions[$index]) =~ s/ /%20/g;
            ($CaptionURL = $CaptionURL) =~ s/\"/&quot;/g;
            ($CaptionURL = $CaptionURL) =~ s/\'/&rsquo;/g;
            ($CaptionURL = $CaptionURL) =~ s/\n//g;
            ($CaptionURL = $CaptionURL) =~ s/\r//g;
            &log ("CaptionURL is $CaptionURL\n","debug");
            print (OUTSLIDEFILE "new picInfo(\"$NewFileNames[$index].jpg\", \"$CaptionURL\", \"$NewFileNames[$index].htm\", $picWidths[$index], $picHeights[$index])");
            if ($index + 1 < @filenames)
            {
              print (OUTSLIDEFILE ",\n");
            }
          }
           print (OUTSLIDEFILE "\n");
        }
        else
        {
          &log ("Found regular line to add to OUTSLIDEFILE: '$_'\n","debug");
          print (OUTSLIDEFILE "$_\n");
        }
      }
	}
    close (SLIDEFILE);
    close (OUTSLIDEFILE);
  }
  if (!$config->{"SkipHTML"}) {
    &copyifnewer ("slidenext.gif",$NewFullDir);
    &copyifnewer ("slideprev.gif",$NewFullDir);
    &copyifnewer ("slideexit.gif",$NewFullDir);
    &copyifnewer ("slidehide.gif",$NewFullDir);
    &copyifnewer ("slideplay.gif",$NewFullDir);
    &copyifnewer ("slidecaption.gif",$NewFullDir);
    &copyifnewer ("showpic.html",$NewFullDir);
  }

  # Final check: Make sure that there are no files in the album dir that don't
  # belong there - if a file in the photos dir has been deleted or renamed since
  # the last time this ran, there will be extra files around.
  # first create the array of JPG files we need to process in the original
  # photos dir.

  my @ActualAlbumFiles;         # file name & extension, with no path
  opendir(DIR, $NewFullDir) || die "can't open directory '$NewFullDir': $!";
  @ActualAlbumFiles = grep {-f "$NewFullDir/$_"} readdir(DIR);
  closedir DIR;

  my @DesiredAlbumFiles;
  my $indexA = 0;
  my $indexB = 0;
  for $picfilename (@filenames) {
    $DesiredAlbumFiles[$indexB++]="$NewFileNames[$indexA].jpg";
    if (!$config->{"SkipThumbnails"}) {
      $DesiredAlbumFiles[$indexB++]="$NewFileNames[$indexA].info";
      $DesiredAlbumFiles[$indexB++]="$NewFileNames[$indexA]_sm.jpg";
      # Not using the _sm.info files yet, so we could remove them
      # here. But they dont' really hurt, and I may find a need for them later...
      $DesiredAlbumFiles[$indexB++]="$NewFileNames[$indexA]_sm.info";
    }
    if (!$config->{"SkipHTML"}) {
       $DesiredAlbumFiles[$indexB++]="$NewFileNames[$indexA].htm";
    }

    if ($config->{BigPicLink} eq "httpfullsize") {
      if (!$config->{FullSizeBaseURL}) {
        $DesiredAlbumFiles[$indexB++]="$NewFileNames[$indexA]_lg.jpg";
      }
    }
    $indexA++;
  }
  if (!$config->{"SkipHTML"}) {
    $DesiredAlbumFiles[$indexB++]=$OutputDir.".html";
    $DesiredAlbumFiles[$indexB++]="slideshow.html";
    $DesiredAlbumFiles[$indexB++]="showpic.html";
    $DesiredAlbumFiles[$indexB++]="slideplay.gif";
    $DesiredAlbumFiles[$indexB++]="slidehide.gif";
    $DesiredAlbumFiles[$indexB++]="slideexit.gif";
    $DesiredAlbumFiles[$indexB++]="slidecaption.gif";
    $DesiredAlbumFiles[$indexB++]="slideprev.gif";
    $DesiredAlbumFiles[$indexB++]="slidenext.gif";
  }

  my @union;
  my @intersection;
  my @difference;
  my %count;
  my $element;

  # an interesting way to do set difference/union/intersection on arrays:
  # from http://www.perldoc.com/perl5.6.1/pod/perlfaq4.html#How-do-I-compute-the-difference-of-two-arrays---How-do-I-compute-the-intersection-of-two-arrays-
  #
  # Note that this assumes that all the pictures that were supposed to be created actually WERE
  # created.  If they were not created, they will be in the difference set, and the program will
  # try to delete them. But since they weren't CREATED, they won't be there.
  # This happens only when there is a problem running the java thumbnailer on a set of files.
  @union = @intersection = @difference = ();
  %count = ();
  foreach $element (@ActualAlbumFiles, @DesiredAlbumFiles) { $count{$element}++ }
  foreach $element (keys %count) {
    push @union, $element;
    push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
  }

  &log ("List of Desired Album Files\n","debug");
  for $picfilename (@DesiredAlbumFiles) {
    &log ("$picfilename\n","debug");
  }

  &log ("\nList of Actual Album Files\n","debug");
  for $picfilename (@ActualAlbumFiles) {
    &log ("$picfilename\n","debug");
  }

  if (@difference>0)
  {
    &log ("\nDeleting files from $NewFullDir:\n","info");
    for $picfilename (@difference) {
      # don't spew a bunch of errors if the picture doesn't exist!
      if (-e $NewFullDir."/".$picfilename)
      {
        &log ("$picfilename\n","info");
        unlink $NewFullDir."/".$picfilename or &log ("ERROR: can't delete '$NewFullDir/$picfilename' $!\n","info");
      }
    }
  }


  # if we're writing verbose output, end the line
  &log ("\n","progress");
}

#-----------------------------------------------------------------------------
# print out the navigation table on the left of the page, which has links to
# the other index pages and shows the current page in bold text.
# Takes one parameter, DirDisplayName of this index page
# assumes that OUTFILE is open and will be closed by the caller afterwards
# assumes that @FinalOutputDirs is populated with directories

sub PrintNavTable ()
{
  my $DirDisplayName = $_[0];

  my $LinkDisplayName;
  my $UnixValidDirName;
  my $BaseURL;
  my $HTML;


  if ($DirDisplayName eq " ") {
    $BaseURL = "";
  } elsif ($DirDisplayName eq "Tags") {
    $BaseURL = "";
  } else {
    $BaseURL = "../";
  }

  print (OUTFILE "  <div id=\"block_1\">\n    <div class=\"NavTable\">\n");

$HTML = <<HTML;
      <script>
        window.onload = function(){
          document.getElementById(\"RandomPageLink\").onclick = function(){
                 if(showRandomPage()){
                     // most important step in this whole process
                     return false;
                 }
          }
          console.log('added function to RandomPageLink');
        }
      </script>
HTML
  print (OUTFILE $HTML);

  # Random Page is always first
$HTML = <<HTML;
  <a id=\"RandomPageLink\" href=\"#">Random Page</a><br/>

      <script>
        const pageUrls = [
HTML
  print (OUTFILE $HTML);
  
  for my $dir (@FinalOutputDirs) {
    $UnixValidDirName = $dir;
    print (OUTFILE "'$BaseURL$UnixValidDirName/$UnixValidDirName.html',\n");
  }
  
$HTML = <<HTML;
        ];
        function showRandomPage() {
          // Get a random index from the array
          const randomIndex = Math.floor(Math.random() * pageUrls.length);
          location.href = pageUrls[randomIndex];
        }
      
      </script>
HTML
  print (OUTFILE $HTML);
  
  
  # tags is always listed second
  if (!$config->{SkipTags})
  {
    if ($DirDisplayName eq "Tags")
    {
      print (OUTFILE "<strong>Tags</strong><br/>\n");
    }
    else
    {
      print (OUTFILE "<a href=\"".$BaseURL."tags.html\">Tags</a><br/><br/>\n");
    }
  }

  # After those two, just regular pages. 
  for my $dir (@FinalOutputDirs) {
    $UnixValidDirName = $dir;

    $LinkDisplayName = $OutDirsDisplayNames{$dir};;

    if ($LinkDisplayName eq $DirDisplayName)
    {
      print (OUTFILE "<strong>$LinkDisplayName</strong><br/>\n");
    }
    else
    {
      print (OUTFILE "<a href=\"$BaseURL$UnixValidDirName/$UnixValidDirName.html\">$LinkDisplayName</a><br/>\n");
    }
  }
  print (OUTFILE "    </div>\n  </div>\n");

}

#-----------------------------------------------------------------------------
# make the webpage specified by config->MainPageName, which is the main photo
# index that also has the latest additions.

sub make_frontpage ()
{
  my $AlbumSize = $_[0];

  my $filename;
  my $dirname;
  my $LinkDisplayName;
  my $UnixValidDirName;
  my $index;
  my @DirDisplayNames;
  my @DirNames;
  my @Captions;
  my @FileNames;
  my $ColumnCount;
  my $LastDirName;
  my $HTML;

  $filename=">".$config->{AlbumDir}."/".$config->{MainPageName};

  &log ("creating front page '".$config->{AlbumDir}."/".$config->{MainPageName}."'\n","info");
  open (OUTFILE,$filename);

$HTML = <<HTML;
<!DOCTYPE html>
<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en\" xml:lang=\"en\">
  <head>
    <html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en\" xml:lang=\"en\">
    <title>$config->{PageTitle}</title>
    <link href="TwoColumn.css" rel="stylesheet" type="text/css">
    <link href="basic.css" rel="stylesheet" type="text/css">
    <link rel="alternate" type="application/rss+xml" title="$config->{RSSDescription}" href="$config->{HomePageURL}$config->{AlbumPageURL}$config->{RSSFeedName}" />
    <script type="text/javascript" src="https://sdk.userbase.com/2/userbase.js"></script>
	<script type="text/javascript" src="usermanagement.js"></script>
	<script type="text/javascript">
		userbase.init({ appId: '$config->{UserBaseAppId}' })
		.then((session) => session.user ? showUserLoggedIn(session.user.username) : resetAuthFields())
	</script>


  </head>
  <body>
    <div id="header" class="fullwidthcontainer">
      <div class="toptitle"><a href="$config->{HomePageURL}"> $config->{HomePageName}</a> $config->{PageTitle}</div>
      <div class="rightalign">
		<input onclick="changeButton();showhide()" type="button" value="Show Login" id="LoginButton"></input>
		<div id="LoggedInUser">&nbsp;</div>
		&nbsp;&nbsp;
        <a href="$config->{HomePageURL}$config->{AlbumPageURL}$config->{RSSFeedName}"><img border="0" alt="RSS Feed of new images" src="rss.gif"></a>
      </div>
      <div class="spacer"/>

	  <div class="toggle-div hidden" id="authforms">
		Login
		<form id="login-form">
			<input id="login-username" type="text" required placeholder="Username">
			<input id="login-password" type="password" required placeholder="Password">
			<input type="submit" value="Sign in">
		</form>
		<div id="login-error"></div>

		Create an account
		<form id="signup-form">
			<input id="signup-username" type="text" required placeholder="Username">
			<input id="signup-email" type="text" required placeholder="email">
			<input id="signup-password" type="password" required placeholder="Password">
			<input type="submit" value="Create an account">
		</form>
		<div id="signup-error"></div>
	  </div>

	  <script>
		initListeners()
	  </script>
	  
      <!-- spiffy rounded corners, from http://www.spiffycorners.com/ -->
      <div>
        <b class="spiffy">
        <b class="spiffy1"><b></b></b>
        <b class="spiffy2"><b></b></b>
        <b class="spiffy3"></b>
        <b class="spiffy4"></b>
        <b class="spiffy5"></b></b>

        <div class="spiffyfg">
            <div class="instructionlineleft">Select a link below to see thumbnails, or click the photos for a larger version</div>
            <div class="instructionlineright">$AlbumSize&nbsp;</div>
        </div>

        <b class="spiffy">
        <b class="spiffy5"></b>
        <b class="spiffy4"></b>
        <b class="spiffy3"></b>
        <b class="spiffy2"><b></b></b>
        <b class="spiffy1"><b></b></b></b>
      </div>
    </div>
    <div class="spacer"/>


	<div id="wrapper">
HTML
  print (OUTFILE $HTML);

  #need to loop through all directories and create a link to the page for each one

  # create navigation table
  &PrintNavTable (" ");

  # new feature, 11-14-2000
  # Take up to 50 of the latest photos from
  # the file LatestPics.$config->{ConfigName}.txt and add them to the index page
  if (open (LATESTPICSFILE,"<LatestPics.$config->{ConfigName}.txt"))
  {
    &log ("Files to be added to Main Page:\n","debug");

    $index = 0;
    PICFILE: while (<LATESTPICSFILE>)
    {
      chomp;
      my ($DirDisplayName,
          $DirName,
          $Caption,
          $FileName) = split /;/;

      if ($DirDisplayName ne "" &&
          $DirName     ne "" &&
          $FileName    ne "")
      {
        $DirDisplayNames[$index] = $DirDisplayName;
        $DirNames[$index] = $DirName;
        $Captions[$index] = $Caption;
        $FileNames[$index] = $FileName;

        &log ("$index:","debug");
        &log ("\tDirDisplayName  $DirDisplayNames[$index]\n","debug");
        &log ("\tDirName      $DirNames[$index]\n","debug");
        &log ("\tCaption      $Captions[$index]\n","debug");
        &log ("\tFileName     $FileNames[$index]\n","debug");
        &log ("\n","debug");

        $index++;
        last PICFILE if ($index > 50);
      }
      else
      {
        &log ("Badly formatted line $index in LatestPics.$config->{ConfigName}.txt\n'$_'\n'$DirDisplayName'$DirName'$Caption'$FileName'\n","info");
      }
    }
    close (LATESTPICSFILE);

    # something for the front page of the site.
    if (!$config->{"SkipThumbnails"}) {
      copy "$config->{AlbumDir}/$DirNames[0]/$FileNames[0]_sm.jpg", "$config->{AlbumDir}/LatestPhoto.jpg" or
        warn "can't copy '$config->{AlbumDir}/$DirNames[0]/$FileNames[0]_sm.jpg' to '$config->{AlbumDir}/LatestPhoto.jpg'\n$!";

      copy "$config->{AlbumDir}/$DirNames[0]/$FileNames[0]_lg.jpg", "$config->{AlbumDir}/LatestPhoto_lg.jpg" or
        warn "can't copy '$config->{AlbumDir}/$DirNames[0]/$FileNames[0]_lg.jpg' to '$config->{AlbumDir}/LatestPhoto_lg.jpg'\n$!";

      if ($config->{WebRootDir})
      {
        copy "$config->{AlbumDir}/$DirNames[0]/$FileNames[0]_sm.jpg", "$config->{WebRootDir}/LatestPhoto.jpg" or
          warn "can't copy '$config->{AlbumDir}/$DirNames[0]/$FileNames[0]_sm.jpg' to '$config->{WebRootDir}/LatestPhoto.jpg'\n$!";

        copy "$config->{AlbumDir}/$DirNames[0]/$FileNames[0]_lg.jpg", "$config->{WebRootDir}/LatestPhoto_lg.jpg" or
                  warn "can't copy '$config->{AlbumDir}/$DirNames[0]/$FileNames[0]_lg.jpg' to '$config->{WebRootDir}/LatestPhoto_lg.jpg'\n$!";
      }
    }

    # now create the table of photos. Put the time it was updated here.
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    my $ampm = "AM";
    if ($hour > 12)
    {
      $hour -= 12;
      $ampm = "PM";
    }
    if ($min < 10)
    {
      $min = "0".$min;
    }
    my $now_string = "$dayhash{$wday} $monthhash{$mon} $mday $year $hour:$min $ampm";

    $HTML = <<HTML;
    <div id="block_2">
       <div class="Latest">Latest Additions!</div><div class="LatestTime">$now_string</div>
HTML
    print (OUTFILE $HTML);

    $LastDirName = "";

    for ($index = 0; $index < @FileNames; $index++)
    {
      &log ("adding latest pics #$index\n","debug");
      if ($DirNames[$index] ne $LastDirName)
      {
        $LastDirName = $DirNames[$index];
        $HTML = <<HTML;
        <div class="spacer">
        <div>
          <b class="spiffy">
          <b class="spiffy1"><b></b></b>
          <b class="spiffy2"><b></b></b>
          <b class="spiffy3"></b>
          <b class="spiffy4"></b>
          <b class="spiffy5"></b></b>

          <div class="spiffyfg">
            <div class="MonthHeader">$DirDisplayNames[$index]</div>
          </div>

          <b class="spiffy">
          <b class="spiffy5"></b>
          <b class="spiffy4"></b>
          <b class="spiffy3"></b>
          <b class="spiffy2"><b></b></b>
          <b class="spiffy1"><b></b></b></b>
        </div>
        <p></p>
HTML
        print (OUTFILE $HTML);
      }
      # add HTML for this picture to the index page for this directory
      $HTML = <<HTML;
      <div class="float">
        <p class="centeredImage">
        <a href="$DirNames[$index]/$FileNames[$index].htm">
        <img SRC="$DirNames[$index]/$FileNames[$index]_sm.jpg" BORDER="0" ALT="$Captions[$index] ($FileNames[$index].jpg)" /></a>
        </p>
        <p class="picCaption">$Captions[$index]</p>
      </div>
HTML
      print (OUTFILE $HTML);
    }
    my $footer = &PageFooter();

    $HTML = <<HTML;
    </div>
    </div><!-- close div#wrapper -->
    $footer
  </body>
</html>
HTML
    print (OUTFILE $HTML);
    close OUTFILE;

    #----- create an RSS feed to match
    my $rssfilename;

    $rssfilename=">".$config->{AlbumDir}."/".$config->{RSSFeedName};

    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
    $mon++;
    $year += 1900;
    if ($mon < 10) {$mon = "0".$mon;}
    if ($mday < 10) {$mday = "0".$mday;}
    if ($hour < 10) {$hour = "0".$hour;}
    if ($min < 10) {$min = "0".$min;}
    if ($sec < 10) {$sec = "0".$sec;}
    my $timeString = "$year-$mon-$mday"."T"."$hour:$min"."Z";
    my $humanTime = "$dayhash{$wday}, $mday $monthname{$mon} $year $hour:$min:$sec GMT";

    &log ("creating RSS feed '".$rssfilename."'\n","info");
    open (RSSFILE,$rssfilename);

    my $xml = <<XML;
<?xml version="1.0"?>
<?xml-stylesheet type="text/css" href="rss.css" ?>
<?xml-stylesheet type="text/xsl" href="rss2html.xsl"?>
<!--

  Hey!
  This web page is actually a data file that is meant to be read by RSS reader programs.
  See http://interglacial.com/rss/about.html to learn more about RSS.

-->
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>$config->{RSSFeedTitle}</title>
    <link>$config->{HomePageURL}$config->{AlbumPageURL}$config->{MainPageName}</link>
    <description>$config->{RSSDescription}</description>
    <language>en-us</language>
    <docs>This file is an RSS 2.0 file, please see: http://interglacial.com/rss/about.html for more info.</docs>
    <lastBuildDate>$humanTime</lastBuildDate>
    <self_url>$config->{HomePageURL}$config->{AlbumPageURL}$config->{RSSFeedName}</self_url>
    <image>
	<title>$config->{RSSFeedTitle}</title>
	<url>$config->{HomePageURL}$config->{RSSImageURL}</url>
	<link>$config->{HomePageURL}$config->{AlbumPageURL}$config->{MainPageName}</link>
    </image>

XML

    print (RSSFILE $xml);


    for ($index = 0; $index < @FileNames; $index++)
    {
      &log ("  adding item $config->{HomePageURL}$config->{AlbumPageURL}$DirNames[$index]/$FileNames[$index].htm ($Captions[$index])\n","debug");
      my $ITEM = <<ITEM;
      <item>
        <title>$Captions[$index]</title>
        <link>$config->{HomePageURL}$config->{AlbumPageURL}$DirNames[$index]/$FileNames[$index].htm</link>
        <description><![CDATA[<a href="$config->{HomePageURL}$config->{AlbumPageURL}$DirNames[$index]/$FileNames[$index].htm">
        <img alt="$Captions[$index]" src="$config->{HomePageURL}$config->{AlbumPageURL}$DirNames[$index]/$FileNames[$index]_sm.jpg"
        align="top" border="0" /></a><br/>
        $Captions[$index]
        ]]></description>
        <dc:creator>$config->{RSSCreator}</dc:creator>
        <dc:date>$timeString</dc:date>
      </item>
ITEM
      print (RSSFILE $ITEM);
    }

    $xml = <<XML;
  </channel>
</rss>
XML
    print (RSSFILE $xml);
    close RSSFILE;
    if (!$config->{"SkipHTML"}) {
      &copyifnewer ("rss.gif",$config->{AlbumDir});
      &copyifnewer ("AddToYahoo.gif",$config->{AlbumDir});
      &copyifnewer ("rss.css",$config->{AlbumDir});
      &copyifnewer ("rss2html.xsl",$config->{AlbumDir});
      &copyifnewer ("basic.css",$config->{AlbumDir});
      &copyifnewer ("TwoColumn.css",$config->{AlbumDir});
      &copyifnewer ("usermanagement.js",$config->{AlbumDir});
    }
  } # was able to open latestpics file
  else
  {
    &log ("Unable to open LatestPics.$config->{ConfigName}.txt\n","info");
  }

}

#-----------------------------------------------------------------------------
# Adds things to the master tags hash %tagshash. The tagshash is a hashtable
# where the keys are the tag words and the values for each key is a list of
# filenames. Currently it is a list of filenames of small photos.
sub AddTags ()
{
    if ($config->{SkipTags}) {return;}

    my $loglevel="debug";
    # first parameter is a space seperated list of tags.
    my $inputList = $_[0];
    # picture name is second parameter - full path to large resized photo
    my $name = $_[1];

    my @tags = split (' ',$inputList);
    # need to process these more  - remove punctuation,
    # remove numbers, remove markup
    # remove stopwords
    for (@tags)
    {
    	# this is not complete, but it reasonable for my needs - remove html tags
    	s/<(?:[^>'"]*|(['"]).*?\1)*>//gs;
    	# next remove non-alphanumeric
    	tr/a-zA-Z0-9//cd;
    }
    &log ("adding tags (@tags) for picture $name\n",$loglevel);
    foreach my $tag (@tags)
    {
      $tag = lc($tag);
      $tag = &makeSingular($tag);
      my $mostlyNumeric = &isMostlyNumeric($tag);
      if ((length $tag > 0) && (!$is_stopword{$tag}) && (!$mostlyNumeric))
      {
        my @list = ();

        if ( $tagshash{$tag} && @{ $tagshash{$tag} })
        {
          &log ("  tag $tag has a list...",$loglevel);
          @list = @{ $tagshash{$tag} };
          foreach my $elt (@list) {
            &log ("    $elt\n",$loglevel);
          }
          my $is_there = 0;
          foreach my $elt (@list) {
              if ($elt eq $name) {
                  $is_there = 1;
                  last;
              }
          }
          if ($is_there)
          {
            &log ("  didn't add $name - already in list\n",$loglevel);
          }
          else
          {
            &log ("  added $name to list\n",$loglevel);
            push @{ $tagshash{$tag} }, $name;
          }
        }
        else {
          push @{ $tagshash{$tag} }, $name;
        }

        @list = @{ $tagshash{$tag} };
        &log ("   '$tag' now has ".@list." elements\n",$loglevel);
      }
      else { &log ("   '$tag' is a stopword, or length 0, or mostly numeric. Not added\n",$loglevel); }

    }
    &log ("\n",$loglevel);
}

#-----------------------------------------------------------------------------
# make the hash %is_stopword. You can then check $is_stopword{$word}
sub GetStopWords ()
{
    my $loglevel = "debug";
    open (STOP,"stopwords.txt");
    @stopwords = readline (STOP);
    close (STOP);
    &log ("read in list of stopwords:\n",$loglevel);
    %is_stopword = ();
    for (@stopwords)
    {
      my $this_stopword = $_;
      $this_stopword =~ s/\r?\n$//;
      $is_stopword{$this_stopword} = 1;
      &log ("'$this_stopword'\n",$loglevel);
    }
    &log ("\n\n",$loglevel);
}

#-----------------------------------------------------------------------------
# return true if the sting passed in is 'mostly' numeric. i.e. if it is
# something like 2006040-12456, or IMG 001
sub isMostlyNumeric()
{
  my $tag = $_[0];
  my $retval = 0;
  if ($tag =~ /(\d+)-(\d+)(.*)/)
  {
    $retval = 1;
  }
  if ($tag =~ /img.*\d+/)
  {
    $retval = 1;
  }
  if ($tag =~ /(\d+)/)
  {
    $retval = 1;
  }
  if ($retval)
  {
    &log("tag '$tag' is mostly numeric\n","debug");
  }
  return $retval;
}

#-----------------------------------------------------------------------------
#
sub make_tagspages ()
{
  # make 1 html page showing all tags defined
  my $HTML;
  my $filename;
  my $tag;
  my @value;
  my $size;
  my $largestNumberOfValues;
  my $smallestNumberOfValues;
  my $largestTagKey;
  my $numValues;
  my @sizeBuckets;
  my $numtags = my $originalNumTags = keys %tagshash;
  my $tagsDir = $config->{AlbumDir}."/tags";


  if (! -e $tagsDir) {
    &log ("making directory $tagsDir\n","verbose");;
    mkdir $tagsDir,0777 or die "can't make directory '$tagsDir' $!";
  }

  my @tagsPages = glob("$tagsDir/*.*");
  &log ("removing files in '$tagsDir'\n","verbose");
  unlink @tagsPages;

  if ($config->{SkipTags}) {return;}

  # remove tags that are only used a few times, and find the tag that has
  # the largest number of values. This is used later to calculate what size
  # to show each tag.
  &log ("There are a total of $numtags tags found\n","verbose");
  $largestNumberOfValues = &OptimizeNumberOfTags();
  ($largestTagKey,$largestNumberOfValues,$smallestNumberOfValues) = &GetLargestTagKey();

  $numtags = keys %tagshash;
  &log ("There are a total of $numtags tags that will be used to make pages\n","info");
  &log ("The tag '$largestTagKey' has the largest number of values ($largestNumberOfValues)\n","verbose");

  $filename=">".$config->{AlbumDir}."/tags.html";

  &log ("creating tags page '$filename'\n","info");
  open (OUTFILE,$filename);

$HTML = <<HTML;
<!DOCTYPE html>
<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en\" xml:lang=\"en\">
  <head>
    <title>$config->{PageTitle} - Tags</title>
    <link href="TwoColumn.css" rel="stylesheet" type="text/css">
    <link href="basic.css" rel="stylesheet" type="text/css">
    <script type="text/javascript" src="https://sdk.userbase.com/2/userbase.js"></script>
	<script type="text/javascript" src="usermanagement.js"></script>
	<script type="text/javascript">
		userbase.init({ appId: '$config->{UserBaseAppId}' })
		.then((session) => session.user ? showUserLoggedIn(session.user.username) : resetAuthFields())
	</script>
  </head>
  <body>
    <div id="header">
		<div class="toptitle">
			<a href="$config->{HomePageURL}">$config->{HomePageName}</a> <a href="$config->{MainPageName}">$config->{PageTitle}</a> Tags
		</div>
		<div class="rightalign">
			<input onclick="changeButton();showhide()" type="button" value="Show Login" id="LoginButton"></input>
			<div id="LoggedInUser">&nbsp;</div>
		</div>
		
		<div class="spacer"/>

		<div class="toggle-div hidden" id="authforms">
			Login
			<form id="login-form">
				<input id="login-username" type="text" required placeholder="Username">
				<input id="login-password" type="password" required placeholder="Password">
				<input type="submit" value="Sign in">
			</form>
			<div id="login-error"></div>

			Create an account
			<form id="signup-form">
				<input id="signup-username" type="text" required placeholder="Username">
				<input id="signup-email" type="text" required placeholder="email">
				<input id="signup-password" type="password" required placeholder="Password">
				<input type="submit" value="Create an account">
			</form>
			<div id="signup-error"></div>
		</div>

		<script>
			initListeners()
		</script>
		<div class="spacer"/>
		<!-- spiffy rounded corners, from http://www.spiffycorners.com/ -->
		<div>
			<b class="spiffy">
			<b class="spiffy1"><b></b></b>
			<b class="spiffy2"><b></b></b>
			<b class="spiffy3"></b>
			<b class="spiffy4"></b>
			<b class="spiffy5"></b></b>

			<div class="spiffyfg">
				<div class="instructionlineleft">Select a word below to see photos tagged with that keyword.</div>
				<div class="instructionlineright">There are $numtags keywords</div>
			</div>

			<b class="spiffy">
			<b class="spiffy5"></b>
			<b class="spiffy4"></b>
			<b class="spiffy3"></b>
			<b class="spiffy2"><b></b></b>
			<b class="spiffy1"><b></b></b></b>
		</div>
	</div>
    <div class="spacer"/>
    <div id="wrapper">
HTML
  print (OUTFILE $HTML);

  &PrintNavTable ("Tags");

    $HTML = <<HTML;
    <div id="block_2">
      <p class="TagsBox">
HTML
    print (OUTFILE $HTML);

  &log ("Calculating tag buckets\n","info");

  # tags go here

  # Need to write a function to optimize the spread of values across the
  # size buckets. Not sure how to tell what is 'optimal' though!
  # it should show a 'long tail' type of curve, with a few values getting
  # the most 'hits' and many more values with fewer hits.
  # That is true. There are two algorithms used to pick the size 'buckets'
  # One way is using math, one is more brute force - it sorts the data, and then
  # picks buckets based on the position in the list, not raw math.
  # MethodA (math) works well when the initial set of tags (before pruning down) is very
  # large. When a sample that had 6000 tags was pruned down to 200, it worked well.
  # MethodB works for a sample that started with 701 tags, but only 102 had more than 1 value.

  for (my $i=0; $i<10; $i++) {
      $sizeBuckets[$i]=0;
  }
  my $bucket;

  # this is a copy of the tagshash, but will have a list of
  # sizes and buckets instead of a list of photo paths. This then
  # will allow me to sort by tag name.
  my %newtagshash;
  for $tag (keys %tagshash)
  {
      push @{ $newtagshash{$tag} }, "notused" ;
  }

  if ($originalNumTags > 1000)
  {
    &log ("Using mathematical long tail algorithm\n","verbose");
    my $smallestPercentageGroup = ($smallestNumberOfValues / $largestNumberOfValues) * 100;

    for $tag (keys %tagshash)
    {
      @value = @{ $tagshash{$tag}};
      $numValues = @value;
      my $percentageGroup = ($numValues / $largestNumberOfValues) * 100;
      if    ($percentageGroup > 7.0 * $smallestPercentageGroup) {$size=36; $bucket = 9;}
      elsif ($percentageGroup > 6.5 * $smallestPercentageGroup) {$size=28; $bucket = 8;}
      elsif ($percentageGroup > 6.0 * $smallestPercentageGroup) {$size=26; $bucket = 7;}
      elsif ($percentageGroup > 5.5 * $smallestPercentageGroup) {$size=24; $bucket = 6;}
      elsif ($percentageGroup > 5.0 * $smallestPercentageGroup) {$size=22; $bucket = 5;}
      elsif ($percentageGroup > 4.0 * $smallestPercentageGroup) {$size=16; $bucket = 4;}
      elsif ($percentageGroup > 3.0 * $smallestPercentageGroup) {$size=14; $bucket = 3;}
      elsif ($percentageGroup > 2.0 * $smallestPercentageGroup) {$size=12; $bucket = 2;}
      elsif ($percentageGroup > 1.1 * $smallestPercentageGroup) {$size=10; $bucket = 1;}
      else                          {$size=8;  $bucket = 0;}
      $sizeBuckets[$bucket]++;
      &log ("$tag, $numValues, $percentageGroup, $bucket\n","debug");
      push @{ $newtagshash{$tag} }, $size, $numValues;
    }
  }
  else # use simpler algorithm
  {
    &log ("Using brute force long tail algorithm\n","verbose");
    # i.e. - with 100 values, 00-18 bucket 0
    #                         19-55 bucket 1
    #                         56-71 bucket 2
    #                         72-78 bucket 3
    #                         79-84 bucket 4
    #                         85-89 bucket 5
    #                         90-92 bucket 6
    #                         93-94 bucket 7
    #                         95-96 bucket 8
    #                         97-100 bucket 9


    #create an array of tags, sorted by the number of values
    my @keys = sort {@{$tagshash{$a}} <=> @{$tagshash{$b}}} keys %tagshash;

    for (my $i=0; $i < @keys; $i++)
    {
      $tag = $keys[$i];
      @value = @{ $tagshash{$tag}};
      $numValues = @value;
      my $percentageGroup = $i / (@keys / 100);
      if    ($percentageGroup > 97) {$size=36; $bucket = 9;}
      elsif ($percentageGroup > 95) {$size=28; $bucket = 8;}
      elsif ($percentageGroup > 93) {$size=26; $bucket = 7;}
      elsif ($percentageGroup > 90) {$size=24; $bucket = 6;}
      elsif ($percentageGroup > 85) {$size=22; $bucket = 5;}
      elsif ($percentageGroup > 79) {$size=16; $bucket = 4;}
      elsif ($percentageGroup > 72) {$size=14; $bucket = 3;}
      elsif ($percentageGroup > 56) {$size=12; $bucket = 2;}
      elsif ($percentageGroup > 19) {$size=10; $bucket = 1;}
      else                          {$size=8;  $bucket = 0;}
      $sizeBuckets[$bucket]++;
      &log ("$tag, $numValues, $i, $bucket\n","debug");
      push @{ $newtagshash{$tag} }, $size, $numValues;
    }
  }

  #create an array of tags, sorted ASCII-wise
  my @sortedtags = sort keys %tagshash;

  for (my $i=0; $i < @sortedtags; $i++)
  {
    $tag = $sortedtags[$i];
    my $notused;
    ($notused, $size, $numValues) = @{ $newtagshash{$tag}};
    print (OUTFILE "    &nbsp;<a href=\"tags/$tag.html\" style=\"font-size: ".$size."px;\" class=\"PopularTag\" title=\"$numValues usages\">$tag</a>&nbsp;\n");
  }

  for (my $i=0; $i<@sizeBuckets; $i++) {
      &log ("bucket $i has $sizeBuckets[$i] values\n","debug");
  }

  print (OUTFILE "</p>\n");


  print (OUTFILE "</div>\n");
  print (OUTFILE &PageFooter());
  print (OUTFILE "</BODY>\n</HTML>\n");
  close OUTFILE;
  &copyifnewer ("basic.css",$config->{AlbumDir});
  &copyifnewer ("TwoColumn.css",$config->{AlbumDir});

  # create each tag page...
  # do in a seperate loop to be able to use OUTFILE in call, all over
  &log ("creating pages for each tag\n","info");

  for $tag (keys %tagshash)
  {
     &makeTagPage($tag);
  }
  &log ("\n","progress");	
}

#-----------------------------------------------------------------------------
# keep removing lesser-used tags until we have a reasonable number of tags.
#
sub OptimizeNumberOfTags ()
{
  my $minimumValuesToShow = 2;
  my $numtags = keys %tagshash;
  my $tag;
  my $numValues;
  my $maxTags = 3000;

  # delete strange crap with 0 length tag
  for $tag (keys %tagshash)
  {
    if (length $tag < 1) {
    	delete $tagshash{$tag};
    }
  }

  while ($numtags > $maxTags)
  {
    &log ("more than $maxTags tags ($numtags). Deleting tags with less than $minimumValuesToShow values.\n","info");
    for $tag (keys %tagshash)
    {
      $numValues = @{ $tagshash{$tag}};
      if ($numValues < $minimumValuesToShow) {
      	&log ("   deleting tag '$tag' because it has fewer than $minimumValuesToShow usages\n","debug");
      	delete $tagshash{$tag};
      }
      if (length $tag < 1) {
      	delete $tagshash{$tag};
      }
    }
    $minimumValuesToShow++;
    $numtags = keys %tagshash;
  }
}

#-----------------------------------------------------------------------------
# find key with largest number of values
#
sub GetLargestTagKey ()
{
  my $tag;
  my $numValues;
  my $largestNumberOfValues = 0;
  my $smallestNumberOfValues = 9999999;
  my $largestTagKey;

  for $tag (keys %tagshash)
  {
    $numValues = @{ $tagshash{$tag}};
    if ($numValues > $largestNumberOfValues) {
       $largestNumberOfValues = $numValues;
       $largestTagKey = $tag;
    }
    if ($numValues < $smallestNumberOfValues) {
       $smallestNumberOfValues = $numValues;
    }
  }
  my @TagValueList = ($largestTagKey,$largestNumberOfValues,$smallestNumberOfValues);
  return @TagValueList;
}

#-----------------------------------------------------------------------------
# what I really need to do is extract a function that just makes the HTML
# for an array of filenames. That could be resused in multiple places.
#
sub makeTagPage()
{
  my $loglevel = "verbose";
  # make page for this tag
  my $thisTag = $_[0];
  my $HTML;
  my @listOfPhotoInfos;
  @listOfPhotoInfos = @{ $tagshash{$thisTag}};
  my $numphotos = @listOfPhotoInfos;

  my $filename=">".$config->{AlbumDir}."/tags/".$thisTag.".html";

  &log ("creating tag page '$filename'\n","verbose");
  &log ("!","progress");

  open (OUTFILE,$filename) or die "can't create $filename for tag page $!";

$HTML = <<HTML;
<!DOCTYPE html>
<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en\" xml:lang=\"en\">
  <head>
    <title>$config->{PageTitle} - Tags - $thisTag</title>
    <link href="../TwoColumn.css" rel="stylesheet" type="text/css">
    <link href="../basic.css" rel="stylesheet" type="text/css">
  </head>
  <body>
    <div id="header">
      <div class="toptitle">
         <a href="$config->{HomePageURL}">$config->{HomePageName}</a>
         <a href="../$config->{MainPageName}">$config->{PageTitle}</a>
         <a href="../tags.html">Tags</a>
         $thisTag
      </div>
      <div class="spacer"/>
      <!-- spiffy rounded corners, from http://www.spiffycorners.com/ -->
      <div>
        <b class="spiffy">
        <b class="spiffy1"><b></b></b>
        <b class="spiffy2"><b></b></b>
        <b class="spiffy3"></b>
        <b class="spiffy4"></b>
        <b class="spiffy5"></b></b>

        <div class="spiffyfg">
            <div class="instructionlineleft">These are all the photos that either have been tagged with '$thisTag' or have that in their caption.</div>
            <div class="instructionlineright">$numphotos pictures</div>
        </div>

        <b class="spiffy">
        <b class="spiffy5"></b>
        <b class="spiffy4"></b>
        <b class="spiffy3"></b>
        <b class="spiffy2"><b></b></b>
        <b class="spiffy1"><b></b></b></b>
      </div>
    </div>
    <div class="spacer"/>
    <div id="wrapper">
HTML
  print (OUTFILE $HTML);

  &PrintNavTable ("Tags - $thisTag");

  print (OUTFILE "    <div id=\"block_2\"><p>&nbsp;</p>");

  #photos go here
  my $picname;
  my $NewFileName;
  my $picAltName;
  my $picCaption;
  my $picComment;
  my $picLink;
  my $NewFullDir;
  my $UnixValidDirName;
  my $ColumnCount = 1;

  #debug

  for my $photoInfo (@listOfPhotoInfos)
  {
    # the names listed in the tags are to the original photos,
    # and have the directory, a pipe, and then the filename: i.e.
    # knitting|20040816-194107.jpg
    # 2001-02|2001 - this is a cool picture.jpg
    $photoInfo =~ /\|/g;
    my $picpath = $`;
    my $picfilename = $';

    $UnixValidDirName = &getUnixValidDirName($picpath);
    $NewFullDir = $config->{AlbumDir}."/".$UnixValidDirName;

    &log ("Here is a tag line: $photoInfo [$picpath] [$picfilename]\n",$loglevel);

    ($picname,
     $NewFileName,
     $picAltName,
     $picCaption,
     $picComment,
     $picLink) = &GetPictureInfo($picpath,$picfilename,$NewFullDir);
     my $thumbName = $NewFileName."_sm.jpg";

    &log ("   [$picpath] [$picfilename] [$UnixValidDirName] [$NewFullDir] [$picname] [$NewFileName]\n",$loglevel);

    $HTML = <<HTML;
    <div class="float">
      <p class="centeredImage">
        <a href="../$UnixValidDirName/$NewFileName.htm\">
          <img src="../$UnixValidDirName/$thumbName" border="0" alt="$picCaption" />
        </a>
      </p>
      <p class="picCaption">$picCaption</p>
    </div>
HTML
      print (OUTFILE $HTML);

  }
  print (OUTFILE "    </div>");

  print (OUTFILE &PageFooter());
  print (OUTFILE "</body>\n</html>\n");
  close OUTFILE;

  #die "end of test";
}

#-----------------------------------------------------------------------------
# change plural words to singular word. Doesn't do anything yet. Would need to
# do something like have an English dictionary and if the word ends in "s" and 
# the word after removing the s is a legit English word, then return the word
# without the "s" 
sub makeSingular()
{
  my $tag = $_[0];
  my $retval;

  $retval = $tag;

  return $retval;
}

#-----------------------------------------------------------------------------
# start the log file
sub start_log()
{
  print (XMLLOG "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n");
  print (XMLLOG "<album name=\"$config->{ConfigName}\" URL=\"$config->{HomePageURL}\" time=\"$starttime\">\n");
}

sub end_log()
{
  print (XMLLOG "</album>\n");
}

#-----------------------------------------------------------------------------
# This function prints things out to the console for normal output, and will also
# log everything to an XML file for inclusion in the cruisecontrol log.
sub log()
{
  my $LogString = $_[0];
  my $LogLevel = $_[1];

SWITCH: {
  if ($LogLevel eq "debug")
  {
    if ($Debug) {print $LogString; }
    last SWITCH;
  }
  if ($LogLevel eq "verbose")
  {
    if ($Debug or $Verbose) {print $LogString; }
    last SWITCH;
  }
  if ($LogLevel eq "info")
  {
    print $LogString;
    last SWITCH;
  }
  if ($LogLevel eq "progress")
  {
    print $LogString;
    last SWITCH;
  }
  print "warning: no log level set\n";
  print $LogString;
  }

  if (($LogLevel eq "info") or ($LogLevel eq "progress"))
  {
    print (XMLLOG "  <message priority=\"$LogLevel\">");
    print (XMLLOG "<![CDATA[$LogString]]></message>\n");
  }
}

#-----------------------------------------------------------------------------
# borrowed some ideas from a script called diskpig.pl that I fonud on the web.
# recurses through directories and calculates size of the AlbumDirectory and
# returns that in bytes.
sub calc_size()
{
  my ($dir, $chopped, @filenames, $fcount,
  $tsize, $file, $myfile, $fsize, $root, @keys, $key, $value1,
  $entry, $size, $fname, @fnext);

  $dir = shift;

  # The directory path needs to end with a slash so the last character
  # is chopped off, compared, and added back with the slash if needed.

  $chopped = chop ($dir);
  if ($chopped eq "/"){$dir = "$dir$chopped";}
  else {$dir = "$dir$chopped/";}

  # Read in the files and directory names in the directory excluding . and ..

  unless (opendir (PDIR, $dir))
   {
   &log ("\n\n\tERROR: Path not found - $dir\n\n","info");
   exit 1;
   }
  @filenames = grep (!/^\.\.?$/ , readdir (PDIR));
  closedir PDIR;

  $tsize = 0; # Initialize a counter for total bytes

  foreach (@filenames)
   {
     $myfile = ("$dir$_");
     if (-d $myfile) # If a directory sends to subdir subroutine
     {
#      &log ("\t$myfile\n");
      $tsize = $tsize + &subdir("$myfile");
     }
     else
     {
      # Records the size of the files in the parent directory
      $fsize = 0;
      $fsize = -s ("$myfile");
      $tsize = ($tsize + $fsize);
     }
  }
  return $tsize;
}

#-----------------------------------------------------------------------------
# calculate the size of all the files in a subdirectory
sub subdir
{
  my $DIR = shift;
  my $entry;
  my $size;
  my $tsize = 0;

  if (opendir DIR, $DIR)
  {
    foreach (readdir(DIR))
    {
      next if $_ =~ m/^(\.|\.\.)$/;
      $entry = "$DIR/$_";
      if (-d $entry)
      {
        &subdir($entry);
      }
      else
      {
        $size = 0;
        $size = -s ("$entry");
        $tsize = ($tsize + $size);
      }
    }
    closedir DIR;
  }
  else
  {
    &log ("Can't open directory $DIR\n","info");
  }
  return $tsize;
}

#-----------------------------------------------------------------------------
# return a string in MB or KB of how large the album is
sub report_size ()
{
  my $AlbumSize = shift;
  my $message;

  if ($AlbumSize > 1073741824) 
  {
    my $GBSize = $AlbumSize / 1073741824;
   $message = sprintf "%.1f GBytes",$GBSize;
  }
  else {	  
	  if ($AlbumSize > 1048576)
	  {
	   my $MBSize = $AlbumSize / 1048576;
	   $message = sprintf "%.1f MBytes",$MBSize;
	  }
	  else
	  {
		if ($AlbumSize > 1024)
		{
		 my $KBSize = $AlbumSize / 1024;
		 $message = sprintf "%.0f KBytes",$KBSize;
		}
		else
		{
		 $message = "$AlbumSize Bytes";
		}
	  }
  }
	  return $message;
}

#-----------------------------------------------------------------------------
# show how log it took to complete, given a starting time
sub report_time ()
{
  my $starttime = shift;

  my $difftime = time - $starttime;
  my $hours = $difftime / 3600;
  $difftime %= 3600;
  my $minutes = $difftime / 60;
  $difftime %= 60;
  my $message = sprintf "Completed in %.2i:%.2i:%.2i\n", $hours,$minutes,$difftime;
  &log ($message,"info");

}

#-----------------------------------------------------------------------------
# copy a file to a directory if it is newer or not there
# copyifnewer (file,directory[,newfilename])
sub copyifnewer ()
{
  my $filename = $_[0];
  my $directory = $_[1];
  my $newfilename = $filename;
  if (@_ > 2) {
    $newfilename= $_[2];
  }
  my $DestFile = $directory."/".$newfilename;

  my $wasCopied = 0;
  if (-e $DestFile)
  {
    my $SourceFileStat = stat($filename);
    my $DestFileStat = stat($DestFile);
    if (scalar $SourceFileStat->mtime > scalar $DestFileStat->mtime)
    {
      unlink $DestFile;
      copy $filename, $DestFile or die "Couldn't copy $filename to $DestFile: $!";
	  $wasCopied = 1;
    }
  }
  else
  {
    copy $filename, $DestFile or die "Couldn't copy $filename to $DestFile: $!";
	$wasCopied = 1;
  }
  return $wasCopied;
}

#----------------------------------------------------------------------------------
# Create the UnixValidDirName by checking for certain patterns and converting them,
# or by just stripping invalid directory characters.
sub getUnixValidDirName ()
{
  my $UnixValidDirName;
  my $OriginalDirName = $_[0];

  if ($OriginalDirName =~ /(\d+)\\(.*)/)
  {
    my $fulldir = $config->{PhotosDir}."/".$OriginalDirName;
    my $SourceDirStat = stat($fulldir);
    # would be better to convert this to yyyy-mm-dd or something....
    $UnixValidDirName = scalar $SourceDirStat->ctime;

    &log ("Making up UnixValidDirName - original is $OriginalDirName, UnixValidDirName is $UnixValidDirName\n","info");
  } else {
    ($UnixValidDirName = $OriginalDirName) =~ tr/a-zA-Z0-9\.\-_//cd;

    if ($UnixValidDirName =~ /(\d+)_(\d+)_(\d+)(.*)/)
    {
      if ($4 eq "")
      {
        $UnixValidDirName = $1."-".$2;
      }
    }
  }

  return $UnixValidDirName;
}

#----------------------------------------------------------------------------------
# Create the DirDisplayName by either parsing out the month
# and year and creating the monthname yearname form, looking for year-month-day
# type things, or (if all else fails) by removing any non-alphanumeric characters
# at the beginning of the name that were just used to sort the directory names.
sub getDirDisplayName ()
{
  my $localLogLevel = "debug";
  my $DirDisplayName;
  my $dirName = $_[0];

  if ($dirName =~ /(\d+)[_-](\d+)[_-](\d+)(.*)/)
  {
    if ($4 eq "")
    {
      $DirDisplayName = $monthname{$2}." ".$1;
      &log ("Directory $dirName in YYYY_MM_DD format. DirDisplayName is '$DirDisplayName'\n",$localLogLevel);
    }
    else
    {
      $DirDisplayName = trim($4);
      &log ("Directory $dirName in YYYY_MM_DD format plus description. DirDisplayName is '$DirDisplayName'\n",$localLogLevel);
    }
  }
  else
  {
    if ($dirName =~ /(\d+)-(\d+)(.*)/)
    {
      if ($3 eq "")
      {
        $DirDisplayName = $monthname{$2}." ".$1;
        &log ("Directory $dirName in YYYY-MM format. DirDisplayName is '$DirDisplayName'\n",$localLogLevel);
      }
      else
      {
        $DirDisplayName = trim($3);
        &log ("Directory $dirName in YYYY-MM format plus description. DirDisplayName is '$DirDisplayName'\n",$localLogLevel);
      }
    }
    else
    {
      if ($dirName =~ /(\d+) (\d+)(.*)/)
      {
        if ($3 eq "")
        {
          $DirDisplayName = $monthname{$2}." ".$1;
          &log ("Directory $dirName in YYYY MM format. DirDisplayName is '$DirDisplayName'\n",$localLogLevel);
        }
        else
        {
          $DirDisplayName = trim($3);
          &log ("Directory $dirName in YYYY MM format plus description. DirDisplayName is '$DirDisplayName'\n",$localLogLevel);
        }
      }
      else
      {
        if ($dirName =~ /(\d+)\\(.*)/)
        {
          $DirDisplayName = $1." - ".$2;
          &log ("Directory $dirName in iPhoto format. DirDisplayName is '$DirDisplayName'\n",$localLogLevel);
        }
        else
        {
          ($DirDisplayName = $dirName) =~ tr/^[~!@#$%]+//d;
          &log ("Directory $dirName not in any known format, DirDisplayName is '$DirDisplayName'\n","info");
        }
      }
    }
  }

  return $DirDisplayName;
}

#----------------------------------------------------------------------------------
# define page footer
sub PageFooter ()
{
  my $Footer = <<FOOTER;
  <div id="footer">
    <hr>
    <p>
      $config->{copyrightString}
    </p>
  </div>
FOOTER

  return $Footer;
}

#-------------------------------------------------------------------
sub FileIsZeroSize ()
{
  my $filename = $_[0];
  my $retval = 1;
  if (-e $filename)
  {
    my $filesize = -s $filename;
    $retval = (0 == $filesize);
  }
  return $retval;
}
#-------------------------------------------------------------------
# see if the first file mentioned is newer than the second file
sub FileTimeIsNewer ()
{
  my $firstFile = $_[0];
  my $secondFile = $_[1];
  my $retVal = 0;

  if (-e $firstFile)
  {
    my $firstFileStat = stat($firstFile);
    if (-e $secondFile)
    {
      my $secondFileStat = stat($secondFile);
      my $firstTime = scalar $firstFileStat->mtime;
      my $secondTime = scalar $secondFileStat->mtime;
      if ($firstTime > $secondTime)
      {
        &log ("file1 $firstFile modified $firstTime (after $secondTime for $secondFile)\n","verbose");;
        $retVal = 1;
      }
    }
  }
  return $retVal;
}

#----------------------------------------------------------
sub ReadCaptionFile()
{
  my $CaptionFileName=$_[0];
  # parse this
  # <!-- THUMBSPART:name -->
  # Girls like music
  # <!-- THUMBSPART:caption -->
  # Jordan and Jada listening to CDs
  # <!-- THUMBSPART:comment -->
  # testing out thumbs shell extension
  open (CAPTIONFILE,"<$CaptionFileName") or die;

  my $state="none";
  my $found;
  my $picCaption = "";
  my $picAltName = "";
  my $picComment = "";

  while (<CAPTIONFILE>)
  {
    chomp;
    &log ("  caption line '$_'","debug");
    if (($found) = ($_ =~ /^<!--/))
    {
      if (($found) = ($_ =~ /^<!-- THUMBSPART:name -->/))
      {
        $state="name";
        &log (" changes state to 'name'\n","debug");
      }
      elsif (($found) = ($_ =~ /^<!-- THUMBSPART:caption -->/))
      {
        $state="caption";
        &log (" changes state to 'caption'\n","debug");
      }
      elsif (($found) = ($_ =~ /^<!-- THUMBSPART:comment -->/))
      {
        $state="comment";
        &log (" changes state to 'comment'\n","debug");
      }
      else {
        &log (" ERROR! Nothing done with caption line '$_'\n","info");
      }
    }
    else
    {
      if ($state eq "name")
      {
        $picAltName = $picAltName.$_."\n";
        &log (" added to name\n","debug");
      }
      elsif ($state eq "caption")
      {
        $picCaption = $picCaption.$_."\n";
        &log (" added to caption\n","debug");
      }
      elsif ($state eq "comment")
      {
        $picComment = $picComment.$_."\n";
        &log (" added to comments\n","debug");
      }
      else {
        &log (" ERROR! Nothing done with caption line '$_'\n","info");
      }
    }
  }
  close (CAPTIONFILE);

  chomp $picAltName;
  chomp $picCaption;
  chomp $picComment;

  my @PictureInfo = ($picAltName,$picCaption,$picComment);
  return @PictureInfo;

}

#----------------------------------------------------------------------------
# this needs some 'splainin, lucy.
#
sub GetPictureInfo ()
{
  my $loglevel="debug";
  my $picpath = $_[0];
  my $picfilename = $_[1];
  my $NewFullDir=$_[2];

  $picfilename =~ /\./g;
  my $picname = $`;
  my $picext = $';

  my $picCaption = "";
  my $picAltName = "";
  my $picComment = "";
  my $picLink = "";

  # this transliteration makes valid filenames
  (my $NewFileName = $picname) =~ tr/a-zA-Z0-9\.\-_//cd;

  my $CaptionFileName = $config->{PhotosDir}."/".$picpath."/".$picname.".txt";

  # see if there is a file with the same name, but .txt - if so, parse it for
  # caption and comment information. How it figures out caption stuff:
  # Step 1. See if there is a matching .txt file - i.e. 9999.jpg and 9999.txt. If so,
  # parse that for Thumbspart data.
  # Step 2. if no matching .txt file, look at the file name - if it has a name like
  # '9999 - this is a picture.jpg', then it sets the caption to 'this is a picture'.
  # Step 3. if no caption yet, look in the EXIF data to extract EXIf data. (not implemented - too slow)
  if (-e $CaptionFileName)
  {
    &log ("caption file $CaptionFileName exists\n",$loglevel);
    ($picAltName,$picCaption,$picComment) = &ReadCaptionFile($CaptionFileName);
    &AddTags($picAltName,"$picpath|$picname.$picext");
    &AddTags($picCaption,"$picpath|$picname.$picext");

    $picAltName =~ s/\n/<br\/>/g;
    $picCaption =~ s/\n/<br\/>/g;
    $picComment =~ s/\n/<br\/>/g;
  } # end if there was a caption file
  else
  {
    &log ("no caption file for $picname found at $CaptionFileName\n",$loglevel);
    # this removes the '99999 - ' from '99999 - this is a caption'
    # if there is match to the pattern, caption is just filename.
    ($picCaption = $picname) =~ s/^\d+ \- //;
    &AddTags($picCaption,"$picpath|$picname.$picext");
    $picComment = "";
    $picAltName = "";

    if ($picCaption eq $picname)
    {
      &AddTags("UnCaptioned","$picpath|$picname.$picext");
      if ($config->{email} ne "none")
      {
        $picComment = "<a href=\"mailto:".$config->{email}."?Subject=Caption%20for%20photo%20".$picfilename."\">Suggest a caption!</a>";
      }
    }
  }

  # set up the links
  if ($config->{email} ne "none")
  {
    if ($config->{BigPicLink} eq "request") {
       $picLink = "<a href=\"mailto:".$config->{email}."?Subject=Photo%20Request:%20please%20send%20photo%20".$picfilename."\">\n";
    }
  }
  if ($config->{BigPicLink} eq "localfullsize") {
     $picLink = "<a href=\"file://\\\\".$config->{PhotosDir}."\\".$picpath."\\".$picfilename."\">\n";
  }
  if ($config->{BigPicLink} eq "httpfullsize") {
    if (!$config->{FullSizeBaseURL}) {
       $picLink = "<a href=\"".$NewFileName."_lg.jpg\">\n";
    }
    else {
       $picLink = "<a href=\"".$config->{FullSizeBaseURL}.$picpath."/".$picfilename."\">\n";
    }

  }

  &log ("\t----\n",$loglevel);
  &log ("\tpicname      $picname\n",$loglevel);
  &log ("\tfilename     $picfilename\n",$loglevel);
  &log ("\tNewFileName  $NewFileName\n",$loglevel);
  &log ("\tCaption      $picCaption\n",$loglevel);
  &log ("\tAltName      $picAltName\n",$loglevel);
  &log ("\tComment      $picComment\n",$loglevel);
  &log ("\tLink         $picLink\n",$loglevel);

  my @PictureInfo = ($picname,$NewFileName,$picAltName,$picCaption,$picComment,$picLink);
  return @PictureInfo;
}

# remove leading and trailing spaces
sub trim {
    my @out = @_;
    for (@out) {
        s/^\s+//;
        s/\s+$//;
    }
    return wantarray ? @out : $out[0];
}
