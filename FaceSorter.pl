#!/usr/bin/perl
#
# FaceSorter.pl
# 
# Tools to help sort thousands of unknown faces for training
# 
# Usage:
#   perl FaceSorter.pl <config_name> stats                    # Show statistics about unknown faces
#   perl FaceSorter.pl <config_name> duplicates               # Find and remove likely duplicates
#   perl FaceSorter.pl <config_name> similar                  # Group similar faces together
#   perl FaceSorter.pl <config_name> web [port]               # Start web interface for sorting
#   perl FaceSorter.pl <config_name> batch-move <person>      # Move selected faces to person directory
#

use strict;
use warnings;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy move);
use File::Basename;
use File::Spec;
use File::Find;
use File::stat;
use Image::Size;
use Digest::MD5;
use JSON;
use lib '.';

# Get configuration like MakeAlbum.pl does
my $config;
my $WhichAlbum = "default";

if ($ARGV[0] && -e "AlbumSettings.".$ARGV[0].".txt") {
    $WhichAlbum = $ARGV[0];
    shift @ARGV;  # Remove config name from arguments
}

if (-e "AlbumSettings.".$WhichAlbum.".txt") {
    $config = require "AlbumSettings.".$WhichAlbum.".txt";
    $config->{ConfigName} = $WhichAlbum;
} else {
    die "Could not find configuration file AlbumSettings.".$WhichAlbum.".txt\n";
}

print "Using config '".$WhichAlbum."' which has unknown faces in '".$config->{UnknownFacesDir}."'\n";

# Default settings
$config->{FaceTrainingDir} //= 'faces';
$config->{UnknownFacesDir} //= 'faces/Unknown';

my $unknown_dir = $config->{UnknownFacesDir};
my $training_dir = $config->{FaceTrainingDir};

# Command dispatch
my $command = shift @ARGV || 'help';

if ($command eq 'stats') {
    show_statistics();
} elsif ($command eq 'duplicates') {
    find_duplicates();
} elsif ($command eq 'similar') {
    group_similar_faces();
} elsif ($command eq 'web') {
    start_web_interface(@ARGV);
} elsif ($command eq 'batch-move') {
    batch_move_faces(@ARGV);
} elsif ($command eq 'help') {
    show_help();
} else {
    print "Unknown command: $command\n";
    show_help();
}

#-----------------------------------------------------------------------------
sub show_help {
    print "FaceSorter.pl - Tools for sorting unknown faces\n\n";
    print "Usage:\n";
    print "  perl FaceSorter.pl [config] stats           # Show statistics\n";
    print "  perl FaceSorter.pl [config] duplicates      # Find and remove duplicates\n";
    print "  perl FaceSorter.pl [config] similar         # Group similar faces\n";
    print "  perl FaceSorter.pl [config] web [port]      # Web interface for sorting\n";
    print "  perl FaceSorter.pl [config] batch-move <person> # Move selected faces\n";
    print "\nExamples:\n";
    print "  perl FaceSorter.pl stats\n";
    print "  perl FaceSorter.pl web 8080\n";
    print "  perl FaceSorter.pl batch-move 'Julie Donie'\n";
}

#-----------------------------------------------------------------------------
sub show_statistics {
    print "Face Recognition Statistics\n";
    print "=" x 40 . "\n\n";
    
    # Get unknown faces
    my @unknown_faces = get_unknown_faces();
    my $unknown_count = scalar(@unknown_faces);
    
    print "Unknown faces: $unknown_count\n";
    
    if ($unknown_count == 0) {
        print "No unknown faces found in $unknown_dir\n";
        return;
    }
    
    # Calculate total size
    my $total_size = 0;
    my %size_distribution = ();
    my %date_distribution = ();
    my %source_photos = ();
    
    foreach my $face_file (@unknown_faces) {
        my $full_path = "$unknown_dir/$face_file";
        my $stat = stat($full_path);
        my $size = $stat->size;
        $total_size += $size;
        
        # Size distribution (in KB ranges)
        my $size_kb = int($size / 1024);
        my $size_range = int($size_kb / 10) * 10 . "-" . (int($size_kb / 10) * 10 + 9) . "KB";
        $size_distribution{$size_range}++;
        
        # Date distribution (by day)
        my $date = localtime($stat->mtime);
        my ($day) = $date =~ /^(\w+ \w+ \d+)/;
        $date_distribution{$day}++;
        
        # Source photo analysis
        if ($face_file =~ /^(.+)_face\d+/) {
            $source_photos{$1}++;
        }
    }
    
    printf "Total size: %.1f MB\n", $total_size / (1024 * 1024);
    printf "Average size per face: %.1f KB\n", ($total_size / $unknown_count) / 1024;
    
    print "\nTop 10 source photos with most faces:\n";
    my @top_sources = sort { $source_photos{$b} <=> $source_photos{$a} } keys %source_photos;
    for my $i (0..9) {
        last unless $top_sources[$i];
        printf "  %-40s %d faces\n", $top_sources[$i], $source_photos{$top_sources[$i]};
    }
    
    print "\nFaces created by date (last 10 days):\n";
    my @recent_dates = sort { $date_distribution{$b} <=> $date_distribution{$a} } keys %date_distribution;
    for my $i (0..9) {
        last unless $recent_dates[$i];
        printf "  %-20s %d faces\n", $recent_dates[$i], $date_distribution{$recent_dates[$i]};
    }
    
    # Show existing training directories
    print "\nExisting people in training:\n";
    opendir(my $dh, $training_dir) || die "Cannot open training directory: $!\n";
    my @people_dirs = grep { 
        -d "$training_dir/$_" && 
        $_ ne '.' && 
        $_ ne '..' && 
        $_ ne 'Unknown'
    } readdir($dh);
    closedir($dh);
    
    foreach my $person (sort @people_dirs) {
        my @training_files = glob("$training_dir/$person/*.{jpg,jpeg,png,bmp}");
        printf "  %-30s %d training photos\n", $person, scalar(@training_files);
    }
}

#-----------------------------------------------------------------------------
sub get_unknown_faces {
    return () unless -d $unknown_dir;
    
    opendir(my $dh, $unknown_dir) || die "Cannot open unknown faces directory: $!\n";
    my @faces = grep { 
        -f "$unknown_dir/$_" && 
        /\.(jpg|jpeg|png|bmp)$/i 
    } readdir($dh);
    closedir($dh);
    
    return @faces;
}

#-----------------------------------------------------------------------------
sub find_duplicates {
    print "Finding duplicate faces...\n";
    
    my @unknown_faces = get_unknown_faces();
    my $total_faces = scalar(@unknown_faces);
    
    if ($total_faces == 0) {
        print "No unknown faces found.\n";
        return;
    }
    
    print "Analyzing $total_faces faces for duplicates...\n";
    
    # Calculate MD5 checksums for all faces
    my %checksums = ();
    my $processed = 0;
    
    foreach my $face_file (@unknown_faces) {
        my $full_path = "$unknown_dir/$face_file";
        
        open(my $fh, '<', $full_path) or next;
        binmode($fh);
        my $checksum = Digest::MD5->new->addfile($fh)->hexdigest;
        close($fh);
        
        push @{$checksums{$checksum}}, $face_file;
        
        $processed++;
        if ($processed % 100 == 0) {
            printf "Processed %d/%d faces (%.1f%%)\r", $processed, $total_faces, ($processed/$total_faces)*100;
        }
    }
    print "\n";
    
    # Find and report duplicates
    my @duplicates = grep { scalar(@{$checksums{$_}}) > 1 } keys %checksums;
    my $duplicate_files = 0;
    
    if (@duplicates) {
        print "\nFound " . scalar(@duplicates) . " groups of duplicate faces:\n\n";
        
        foreach my $checksum (@duplicates) {
            my @files = @{$checksums{$checksum}};
            $duplicate_files += scalar(@files) - 1;  # Keep one, count others as duplicates
            
            print "Duplicate group (" . scalar(@files) . " files):\n";
            foreach my $file (@files) {
                print "  $file\n";
            }
            
            for my $i (1..$#files) {
                my $file_to_delete = "$unknown_dir/$files[$i]";
                if (unlink($file_to_delete)) {
                    print "  Deleted: $files[$i]\n";
                } else {
                    print "  Error deleting: $files[$i]\n";
                }
            }
            print "\n";
        }
        
        printf "Total duplicate files that were removed: %d\n", $duplicate_files;
        printf "This saved approximately %.1f MB\n", 
               ($duplicate_files * ($total_faces > 0 ? (get_directory_size($unknown_dir) / $total_faces) : 0)) / (1024 * 1024);
    } else {
        print "No exact duplicates found.\n";
    }
}

#-----------------------------------------------------------------------------
sub get_directory_size {
    my $dir = shift;
    my $size = 0;
    
    find(sub {
        $size += -s $_ if -f $_;
    }, $dir);
    
    return $size;
}

#-----------------------------------------------------------------------------
sub group_similar_faces {
    print "Grouping similar faces using Python face recognition...\n";
    
    my @unknown_faces = get_unknown_faces();
    my $total_faces = scalar(@unknown_faces);
    
    if ($total_faces == 0) {
        print "No unknown faces found.\n";
        return;
    }
    
    if ($total_faces > 500) {
        print "Warning: $total_faces faces found. This may take a very long time.\n";
        print "Consider running on a smaller subset first.\n";
        print "Continue? (y/N): ";
        my $response = <STDIN>;
        chomp($response);
        return unless $response =~ /^[yY]/;
    }
    
    # Create a Python script to group similar faces
    create_face_grouping_script();
    
    print "Running face similarity analysis on ".$total_faces." faces...\n";
    my $cmd = "python face_grouper.py \"$unknown_dir\" 2>nul";
    my $result = `$cmd`;
    
    if ($? != 0) {
        print "Error running face grouping. Make sure Python face_recognition is installed.\n";
        return;
    }
    
    # Parse results
    eval {
        my $groups = decode_json($result);
        
        print "\nFound " . scalar(@$groups) . " groups of similar faces:\n\n";
        
        my $group_num = 1;
        foreach my $group (@$groups) {
            next if scalar(@$group) < 2;  # Skip groups with only one face
            
            print "Group $group_num (" . scalar(@$group) . " similar faces):\n";
            foreach my $face (@$group) {
                print "  $face\n";
            }
            
            # Ask if user wants to create a directory for this group
            print "Create directory for this group? Enter person name (or press Enter to skip): ";
            my $person_name = <STDIN>;
            chomp($person_name);
            
            if ($person_name && $person_name ne '') {
                my $person_dir = "$training_dir/$person_name";
                if (!-d $person_dir) {
                    make_path($person_dir) or print "Error creating directory: $!\n";
                }
                
                if (-d $person_dir) {
                    foreach my $face (@$group) {
                        my $src = "$unknown_dir/$face";
                        my $dst = "$person_dir/$face";
                        if (move($src, $dst)) {
                            print "  Moved: $face -> $person_name/\n";
                        } else {
                            print "  Error moving: $face\n";
                        }
                    }
                }
            }
            
            print "\n";
            $group_num++;
        }
    };
    
    if ($@) {
        print "Error parsing grouping results: $@\n";
    }
}

#-----------------------------------------------------------------------------
sub create_face_grouping_script {
    my $script = <<'PYTHON';
#!/usr/bin/env python3
import face_recognition
import numpy as np
import os
import sys
import json
from pathlib import Path

def group_similar_faces(unknown_dir, tolerance=0.6):
    """Group similar faces using face encodings"""
    
    if not os.path.exists(unknown_dir):
        return []
    
    # Get all face files
    face_files = []
    for ext in ['jpg', 'jpeg', 'png', 'bmp']:
        face_files.extend(Path(unknown_dir).glob(f'*.{ext}'))
        face_files.extend(Path(unknown_dir).glob(f'*.{ext.upper()}'))
    
    if not face_files:
        return []
    
    # Calculate encodings for all faces
    encodings = []
    file_names = []
    
    for face_file in face_files:
        try:
            image = face_recognition.load_image_file(str(face_file))
            face_encodings = face_recognition.face_encodings(image)
            
            if face_encodings:
                encodings.append(face_encodings[0])
                file_names.append(face_file.name)
        except Exception as e:
            continue
    
    if not encodings:
        return []
    
    # Group similar faces
    groups = []
    used = set()
    
    for i, encoding1 in enumerate(encodings):
        if i in used:
            continue
            
        group = [file_names[i]]
        used.add(i)
        
        for j, encoding2 in enumerate(encodings):
            if j in used:
                continue
            
            distance = face_recognition.face_distance([encoding1], encoding2)[0]
            if distance < tolerance:
                group.append(file_names[j])
                used.add(j)
        
        if len(group) > 1:  # Only include groups with multiple faces
            groups.append(group)
    
    return groups

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python face_grouper.py <unknown_faces_directory>")
        sys.exit(1)
    
    unknown_dir = sys.argv[1]
    groups = group_similar_faces(unknown_dir)
    print(json.dumps(groups))
PYTHON

    # Write the script to a file
    open(my $fh, '>', 'face_grouper.py') or die "Cannot create face_grouper.py: $!\n";
    print $fh $script;
    close($fh);
}

#-----------------------------------------------------------------------------
sub batch_move_faces {
    my $person_name = shift;
    
    if (!$person_name) {
        print "Usage: perl FaceSorter.pl batch-move <person_name>\n";
        print "This will look for a file 'selected_faces.txt' with face filenames to move.\n";
        return;
    }
    
    if (!-f 'selected_faces.txt') {
        print "Error: selected_faces.txt not found.\n";
        print "Create this file with one face filename per line.\n";
        return;
    }
    
    my $person_dir = "$training_dir/$person_name";
    if (!-d $person_dir) {
        make_path($person_dir) or die "Cannot create directory $person_dir: $!\n";
        print "Created directory: $person_dir\n";
    }
    
    open(my $fh, '<', 'selected_faces.txt') or die "Cannot open selected_faces.txt: $!\n";
    my $moved_count = 0;
    
    while (my $face_file = <$fh>) {
        chomp($face_file);
        next if $face_file =~ /^\s*$/;  # Skip empty lines
        
        my $src = "$unknown_dir/$face_file";
        my $dst = "$person_dir/$face_file";
        
        if (-f $src) {
            if (move($src, $dst)) {
                print "Moved: $face_file\n";
                $moved_count++;
            } else {
                print "Error moving $face_file: $!\n";
            }
        } else {
            print "File not found: $face_file\n";
        }
    }
    close($fh);
    
    print "\nMoved $moved_count faces to $person_name directory.\n";
    print "Consider running: perl TrainFaces.pl train\n";
}

#-----------------------------------------------------------------------------
sub start_web_interface {
    my $port = shift || 8080;
    
    print "Web interface not yet implemented.\n";
    print "This would start a web server on port $port to help sort faces visually.\n";
    print "For now, use the other commands to help organize your faces.\n";
}