#!/usr/bin/perl
#
# TrainFaces.pl
# 
# Face Recognition Training Script for Photo Album Generator
# Sets up training directories and trains the face recognition model
#
# This version automatically discovers any directories starting with '@' in the faces directory
#
# Usage: perl TrainFaces.pl [config_name]        # Setup and show status
# Usage: perl TrainFaces.pl [config_name] train  # Actually train the model
#

use strict;
use warnings;
use File::Path qw(make_path);
use File::Copy;
use File::Basename;
use File::stat;
use File::Basename;
use File::Spec;
use File::Glob ':glob';
use lib '.';

# Get configuration like MakeAlbum.pl does
my $config;
my $WhichAlbum = "default";

if ($ARGV[0] && $ARGV[0] ne 'train') {
    if (-e "AlbumSettings.".$ARGV[0].".txt") {
        $WhichAlbum = $ARGV[0];
    } else {
        die "Configuration file AlbumSettings.".$ARGV[0].".txt not found.\n";
    }
}

if (-e "AlbumSettings.".$WhichAlbum.".txt") {
    print "Configuration file AlbumSettings.".$WhichAlbum.".txt found\n";
    $config = require "AlbumSettings.".$WhichAlbum.".txt";
    $config->{ConfigName} = $WhichAlbum;
} else {
    die "Could not find configuration file AlbumSettings.".$WhichAlbum.".txt\n";
}

# Default face recognition settings if not in config
$config->{FaceTrainingDir} //= 'faces';
$config->{FaceConfidenceThreshold} //= 0.6;
$config->{EnableFaceRecognition} //= 1;

print "Face Recognition Training - Auto-discovery Mode\n";
print "===============================================\n\n";

if (!$config->{EnableFaceRecognition}) {
    die "Face recognition is disabled in configuration. Set EnableFaceRecognition => 1\n";
}

my $training_dir = $config->{FaceTrainingDir};

print "Will train on any directories in '$training_dir' that start with '\@'\n\n";

# Create main training directory
if (!-d $training_dir) {
    make_path($training_dir) or die "Cannot create training directory '$training_dir': $!\n";
    print "Created training directory: $training_dir\n";
}

# Discover directories that start with @
print "Scanning for people directories (starting with '\@')...\n";
opendir(my $dh, $training_dir) || die "Cannot open training directory '$training_dir': $!\n";
my @people_dirs = grep { 
    -d "$training_dir/$_" && 
    $_ ne '.' && 
    $_ ne '..' && 
    $_ ne 'Unknown' &&
    substr($_, 0, 1) eq '@'  # Only directories starting with @
} readdir($dh);
closedir($dh);

if (@people_dirs == 0) {
    print "No people directories found (directories starting with '\@').\n";
    print "Create directories like:\n";
    print "  faces/\@JulieDonie/\n";
    print "  faces/\@JordanDonie/\n";
    print "  faces/\@ScottDonie/\n";
    print "And add 3-10 training photos to each directory.\n\n";
    print "Then run: perl TrainFaces.pl [config_name] train\n";
    exit 0;
}

print "Found " . @people_dirs . " people directories:\n";
foreach my $person (@people_dirs) {
    my $person_dir = "$training_dir/$person";
    my @files = bsd_glob("$person_dir/*.{jpg,jpeg,png,bmp}");
    my $count = scalar(@files);
    print "  $person: $count training photos\n";
}

print "\nTraining directory setup complete!\n\n";

# Check if this is a training run - look for 'train' as the last argument
my $is_training = (@ARGV > 0 && $ARGV[-1] eq 'train');

if ($is_training) {
    print "Starting face recognition training...\n";
    train_model(@people_dirs);
} else {
    print "Next steps:\n";
    print "1. Add 3-10 clear photos of each person to their respective directories in '$training_dir'/\n";
    print "2. Run: perl TrainFaces.pl";
    print " $WhichAlbum" if $WhichAlbum ne 'default';
    print " train\n";
    print "3. Test recognition: python face_recognizer.py recognize path/to/test/photo.jpg\n";
    print "4. Run MakeAlbum.pl normally - face recognition will be automatic!\n\n";
    
    if (@people_dirs > 0) {
        print "Current training directories:\n";
        foreach my $person (@people_dirs) {
            my $person_dir = "$training_dir/$person";
            my @files = bsd_glob("$person_dir/*.{jpg,jpeg,png,bmp}");
            my $count = scalar(@files);
            print "  $person: $count training photos in $person_dir\n";
        }
    }
}

sub train_model {
    my @people_to_train = @_;
    
    print "\nChecking Python dependencies...\n";
    
    # Check if required Python packages are installed
    my $check_cmd = 'python -c "import face_recognition, cv2, numpy, pickle; print(\'Dependencies OK\')"';
    my $result = `$check_cmd 2>nul`;
    
    if ($? != 0) {
        print "Error: Required Python packages not found.\n";
        print "Please install them with:\n";
        print "  pip install face_recognition opencv-python numpy\n\n";
        print "Note: face_recognition requires cmake and dlib, which may need additional setup.\n";
        print "See: https://github.com/ageitgey/face_recognition#installation\n";
        exit 1;
    }
    
    print "Python dependencies found.\n\n";
    
    # Check that we have training photos
    my $total_photos = 0;
    foreach my $person (@people_to_train) {
        my $person_dir = "$training_dir/$person";
        my @files = bsd_glob("$person_dir/*.{jpg,jpeg,png,bmp}");
        my $count = scalar(@files);
        $total_photos += $count;
        if ($count == 0) {
            print "Warning: No training photos found for $person in $person_dir/\n";
        } else {
            print "Found $count training photos for $person\n";
        }
    }
    
    if ($total_photos == 0) {
        print "\nError: No training photos found in any directories.\n";
        print "Please add photos to the training directories first.\n";
        exit 1;
    }
    
    print "\nStarting face recognition training with $total_photos total photos...\n";
    
    # Run the Python training. Output that python prints goes to the variable $result, which is then
    # thrown away. Let's put that back in in debug mode.
    my $train_cmd = "python face_recognizer.py train";
    $result = `$train_cmd`;
    if (1) {
      print $result;
    }
    
    if ($? == 0) {
        print "\nTraining completed successfully!\n";
        print "You can now run MakeAlbum.pl and faces will be automatically recognized.\n\n";
        
        # Show stats
        my $stats_cmd = "python face_recognizer.py stats";
        my $stats_output = `$stats_cmd 2>nul`;
        if ($? == 0) {
            print "Model statistics:\n";
            print $stats_output;
        }
    } else {
        print "\nTraining failed. Please check the error messages above.\n";
        exit 1;
    }
}