#!/usr/bin/perl
#
# TrainFaces.pl
# 
# Face Recognition Training Script for Photo Album Generator
# Sets up training directories and trains the face recognition model
#
# The directories/names of faces to be recognized are in this script.
#
# There are two usages for this script. The first sets up the directory
# structure.
#
# Usage: perl TrainFaces.pl [config_name]
#
# After running it this way, use the second usage to train the database
# on those faces.
# 
# Usage: perl TrainFaces.pl [config name] train 
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

if ($ARGV[0]) {
    if (-e "AlbumSettings.".$ARGV[0].".txt") {
        print "Configuration file AlbumSettings.".$WhichAlbum.".txt found\n";
        $WhichAlbum = $ARGV[0];
    } else {
        die "Configuration file AlbumSettings.".$ARGV[0].".txt not found.\n";
    }
}

if (-e "AlbumSettings.".$WhichAlbum.".txt") {
    $config = require "AlbumSettings.".$WhichAlbum.".txt";
    $config->{ConfigName} = $WhichAlbum;
} else {
    die "Could not find configuration file AlbumSettings.".$WhichAlbum.".txt\n";
}

# Default face recognition settings if not in config
$config->{FaceTrainingDir} //= 'faces';
$config->{FaceConfidenceThreshold} //= 0.6;
$config->{EnableFaceRecognition} //= 1;

print "Face Recognition Training Setup\n";
print "================================\n\n";

if (!$config->{EnableFaceRecognition}) {
    die "Face recognition is disabled in configuration. Set EnableFaceRecognition => 1\n";
}

my $training_dir = $config->{FaceTrainingDir};
my @family_members = (
    "\@JulieDonie",
    "\@JordanDonie", 
    "\@LeeDonie",
    "\@ScottDonie",
    "\@RolDonie",
    "\@JudyDonie",
    "\@MikeDonie",
    "\@SteveDonie",
    "\@KatieRaver",
    "\@BryanSloane"
);

print "Setting up training directories in '$training_dir'...\n";

# Create main training directory
if (!-d $training_dir) {
    make_path($training_dir) or die "Cannot create training directory '$training_dir': $!\n";
}

# Create subdirectories for each family member
foreach my $person (@family_members) {
    my $person_dir = "$training_dir/$person";
    if (!-d $person_dir) {
        make_path($person_dir) or die "Cannot create person directory '$person_dir': $!\n";
        print "  Created directory for $person\n";
        
        # Create a README file in each directory
        open(my $fh, '>', "$person_dir/README.txt") or die "Cannot create README: $!\n";
        print $fh "Training photos for $person\n";
        print $fh "=" x (length($person) + 20) . "\n\n";
        print $fh "Add 3-10 clear photos of $person to this directory.\n";
        print $fh "Photos should:\n";
        print $fh "- Show the person's face clearly\n";
        print $fh "- Be well-lit\n";
        print $fh "- Have the person looking roughly toward the camera\n";
        print $fh "- Preferably have only one person in the photo\n";
        print $fh "- Be in JPG, PNG, or other common image formats\n\n";
        print $fh "After adding photos, run: perl TrainFaces.pl train\n";
        close($fh);
    } else {
        print "  Directory for $person already exists\n";
    }
}

print "\nTraining directory setup complete!\n\n";

# Check if this is a training run - ARGV[-1] means the last element in the array
if (@ARGV > 0 && $ARGV[-1] eq 'train') {
    print "Starting face recognition training...\n";
    train_model();
} else {
    print "Next steps:\n";
    print "1. Add 3-10 clear photos of each person to their respective directories in '$training_dir'/\n";
    print "2. Run: perl TrainFaces.pl train\n";
    print "3. Test recognition: python face_recognizer.py recognize path/to/test/photo.jpg\n";
    print "4. Run MakeAlbum.pl normally - face recognition will be automatic!\n\n";
    
    print "Training directories created:\n";
    foreach my $person (@family_members) {
        my $person_dir = "$training_dir/$person";
        my @files = glob("$person_dir/*.{jpg,jpeg,png,bmp}");
        my $count = scalar(@files);
        print "  $person: $count training photos\n";
    }
}

sub train_model {
    print "\nChecking Python dependencies...\n";
    
    # Check if required Python packages are installed
    my $check_cmd = 'python -c "import face_recognition, cv2, numpy, pickle; print(\'Dependencies OK\')"';
    my $result = `$check_cmd 2>PythonCheck.txt`;
    
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
    foreach my $person (@family_members) {
        my $person_dir = "$training_dir/$person";
        my @files = glob("$person_dir/*.{jpg,jpeg,png,bmp}");
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
    
    # Run the Python training
    my $train_cmd = "python face_recognizer.py train";
    $result = `$train_cmd 2>nul`;
    
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