# EXIF Data Extractor
#
# Copyright (c) 2001-2002
# by Andrew Gregory
# http://www.scsoftware.com.au/family/andrew/
#
# v1.0   26-Jun-2001   Initial version for QV-3000EX JPEGs.
#
# Usage:
#
#   require 'exif.pl';
#   ...
#   %exif = &exif_get_data("/path/to/your/picture.jpg");
#   ...
#   print $exif{'Shutter Speed'};
#
# Please include credits in your generated HTML code:
#
#   print "<!--\n" . &exif_get_credits . "\n-->\n";
#
# %exif has the following fields available:
#
# EXIF data fields
#
# 'AE'
# 'Aperture Stop'
# 'Comment'
# 'Date'
# 'Description'
# 'Exposure comp.'
# 'Flash'
# 'Focal Length'
# 'Focal Length (equiv)'
# 'Light Metering'
# 'Make'
# 'Model'
# 'Resolution'
# 'Shutter Speed'
# 'Zoom'
#
# Casio specific fields
#
# 'Contrast'
# 'Digital Zoom'
# 'Flash Intensity'
# 'Flash Mode'
# 'Focusing Mode'
# 'Quality'
# 'Recording Mode'
# 'Saturation'
# 'Sensitivity'
# 'Sharpness'
# 'White Balance'
#
###############################################################################

sub exif_get_credits {
  "EXIF Data Extractor\n" .
  "Copyright (c) 2001-2002\n" .
  "by Andrew Gregory\n" .
  "http://www.scsoftware.com.au/family/andrew/";
}

sub exif_get_data {
  local($filename) = @_;
  local(%exif); # Returned EXIF data
  local(@ifdq); # IFD queue (file offsets)
  local($buf);
  local($tag, $type, $len, $offset); # EXIF field data
  local($cnt, $num);
  local($base);
  local($flratio, $flmin); # focal length - ratio and minimum
  local($sizex, $sizey);
  local(*JPG);

  open(JPG, $filename);
  binmode JPG;			# Tell Windoze that we're reading a binary file

  # Jpeg must start with:
  # 0xFFD8     - SOI
  # 0xFFE1     - APP1
  # <len>      - APP1 block length
  # "Exif"     - EXIF ID code
  # 0x0000     - padding
  # 0x4D4D     - byte order <-- TIFF header starts here
  # 0x2A00     - magic number
  read(JPG, $buf, 16);
  my ($soi, $app1, $len, $exif, $pad, $bo, $magic) = unpack('n3a4n3', $buf);
  if ($soi == 0xFFD8 && $app1 == 0xFFE1 && $exif eq 'Exif' && $pad == 0x0000 &&
      $bo == 0x4D4D && $magic == 0x002A) {
    $base = 12;
    read(JPG, $buf, 4);
    push @ifdq, unpack('N1', $buf);
  }
  else {
    close JPG;
    print "Bad EXIF header in $filename\n";
    print "soi $soi not right\n" if ($soi != 0xFFD8);
    print "app1 $app1 not right\n" if ($app1 != 0xFFE1);
    print "exif $exif not right\n" if ($exif ne 'Exif');
    print "pad $pad not right\n" if ($pad != 0x0000);
    print "bo $bo not right\n" if ($bo != 0x4D4D);
    print "magic $magic not right\n" if ($magic != 0x002A);
    return %exif;
  }

  while (@ifdq) {
    $offset = pop @ifdq;
    seek(JPG, $base + $offset, 0);
    read(JPG, $buf, 2);
    ($num) = unpack('n1', $buf);
    for ($cnt = 0; $cnt < $num; $cnt++) {
      read(JPG, $buf, 12);
      ($tag, $type, $len, $offset) = unpack('n1n1N1N1', $buf);
      if ($tag){
        push @ifdq, $offset if ($tag == 0x8769); # Exif IFD
        push @ifdq, $offset if ($tag == 0x927C); # MakerNote IFD
        &exif_process_tag($tag, $type, $len, $offset);
      }
    }
    read(JPG, $buf, 4);
    ($offset) = unpack('N1', $buf);
    if ($offset){
      push @ifdq, $offset if ($offset != 0);
    }
  }

  close JPG;
  %exif;
}

sub exif_process_tag {
  local($tag, $type, $len, $offset) = @_;
  local(%tmp, $v, $short);

  $short = int($offset / 0x10000); # short data stored in offset field

  if ($tag == 2) {
    %tmp = (1, 'Economy',
            2, 'Normal',
            3, 'Fine');
    $exif{'Quality'} = $tmp{$short};
  }
  if ($tag == 1) {
    %tmp = ( 1, 'Single Shutter',
             7, 'Panorama',
            10, 'Night Scene',
            15, 'Portrait',
            16, 'Landscape');
    $exif{'Recording Mode'} = $tmp{$short};
  }
  if ($tag == 0x8822) {
    %tmp = (2,'Programmed AE',
            3, 'Aperture Priority',
            4, 'Shutter Priority',
            7, 'Portrait',
            8, 'Landscape');
    $exif{'AE'} = $tmp{$short};
  }
  if ($tag == 0x9207) {
    push @names, 'Light Metering';
    %tmp = (2, 'Center',
            3, 'Spot',
            5, 'Multi');
    $exif{'Light Metering'} = $tmp{$short};
  }
  if ($tag == 0x829A) {
    $v = &exif_get_tag_value($type, $len, $offset);
    if ($v < 1) {
      $v = int(1.0 / $v + 0.5);
      $v = "1/$v";
    } else {
      $v = int($v * 100.0);
      $v = int($v / 100.0) . '.' . ($v % 100);
    }
    $exif{'Shutter Speed'} = $v . 'sec';
  }
  if ($tag == 0x829D) {
    $exif{'Aperture Stop'} = 'F' . &exif_get_tag_value($type, $len, $offset);
  }
  if ($tag == 0x9204) {
    $exif{'Exposure comp.'} = sprintf('%1.2fEV', &exif_get_tag_value($type, $len, $offset) );
  }
  if ($tag == 3) {
    %tmp = (2, 'Macro',
            3, 'Auto Focus',
            4, 'Manual Focus',
            5, 'Infinity');
    $exif{'Focusing Mode'} = $tmp{$short};
  }
  if ($tag == 4) {
    %tmp = (1, 'Auto',
            2, 'On',
            4, 'Off',
            5, 'Red Eye Reduction');
    $exif{'Flash Mode'} = $tmp{$short};
  }
  if ($tag == 11) {
    %tmp = (0, 'Normal',
            1, 'Soft',
            2, 'Hard');
    $exif{'Sharpness'} = $tmp{$short};
  }
  if ($tag == 13) {
    %tmp = (0, 'Normal',
            1, 'Low',
            2, 'High');
    $exif{'Saturation'} = $tmp{$short};
  }
  if ($tag == 12) {
    %tmp = (0, 'Normal',
            1, 'Low',
            2, 'High');
    $exif{'Contrast'} = $tmp{$short};
  }
  if ($tag == 7) {
    %tmp = (  1, 'Auto',
              2, 'Tungsten',
              3, 'Daylight',
              4, 'Fluorescent',
              5, 'Shade',
            129, 'Manual');
    $exif{'White Balance'} = $tmp{$short};
  }
  if ($tag == 20) {
    %tmp = ( 64, 'Normal',
             80, 'Normal',
            100, 'High',
            125, '+1.0',
            250, '+2.0',
            244, '+3.0');
    $exif{'Sensitivity'} = $tmp{$short};
  }
  if ($tag == 10) {
    %tmp = (1, 'Off',
            2, 'x2');
    $exif{'Digital Zoom'} = $tmp{$short};
  }
  if ($tag == 0x132) {
    $exif{'Date'} = &exif_get_tag_value($type, $len, $offset);
  }
  if ($tag == 0x110) {
    $exif{'Model'} = &exif_get_tag_value($type, $len, $offset);
    $_ = $exif{'Model'};
    if (/3000/) {
      $flratio = 33 / 7;
      $flmin = 7.13;
    }
    if (/2000/) {
      $flratio = 36 / 6.5;
      $flmin = 6.6;
    }
    if (/8000/) {
      $flratio = 40 / 6.18;
      $flmin = 6.18;
    }
  }
  if ($tag == 0x10F) {
    $exif{'Make'} = &exif_get_tag_value($type, $len, $offset);
  }
  if ($tag == 0x10E) {
    $exif{'Description'} = &exif_get_tag_value($type, $len, $offset);
  }
  if ($tag == 0x9286) {
    $exif{'Comment'} = &exif_get_tag_value($type, $len, $offset);
  }
  if ($tag == 0x9209) {
    %tmp = (0, 'Did not fire',
            1, 'Fired');
    $exif{'Flash'} = $tmp{$short};
  }
  if ($tag == 5) {
    %tmp = (11, 'Weak',
            13, 'Normal',
            15, 'Strong');
    $exif{'Flash Intensity'} = $tmp{$short};
  }
  if ($tag == 6) {
    #$exif{'Object Distance'} = sprintf('%2.3fm', $short);
  }
  if ($tag == 0x920A) {
    $v = &exif_get_tag_value($type, $len, $offset);
    $exif{'Focal Length'} = $v . 'mm';
    $exif{'Focal Length (equiv)'} = sprintf('%3.2f', $v * $flratio) . 'mm';
    $exif{'Zoom'} = sprintf('%1.2f', $v / $flmin);
  }
  if ($tag == 0xA002 || $tag == 0xA003) {
    $sizex = $offset if ($tag == 0xA002);
    $sizey = $offset if ($tag == 0xA003);
    $exif{'Resolution'} = $sizex . "x" . $sizey;
  }
}

sub exif_get_tag_value {
  my ($type, $len, $offset) = @_;
  my ($old, $buf, $n1, $n2);
  $old = tell(JPG);
  seek(JPG, $base + $offset, 0);
  if ($type == 2) {
    # string
    read(JPG, $buf, $len);
    ($buf) = unpack("a$len", $buf);
    chop $buf; # strip terminating null
  }
  if ($type == 7) {
    # undefined
    read(JPG, $buf, $len);
    ($buf) = unpack("a$len", $buf);
    # check ID code
    if (substr($buf, 0, 8) eq "ASCII\0\0\0") {
      $buf = substr($buf, 8);
    } else {
      $buf = '';
    }
  }
  if ($type == 5 || $type == 10) {
    # rational
    read(JPG, $buf, 8);
    ($n1, $n2) = unpack('N2', $buf);
    $buf = $n1 / $n2;
  }
  seek(JPG, $old, 0);
  $buf;
}

1;
