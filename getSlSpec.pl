#!/usr/bin/perl -w
#

use strict;

use Getopt::Long;
use List::MoreUtils qw(uniq);

my $usage = qq{

  $0 --input-file dwi.json --output-file slspec.txt
      

  Required args:

   --input-file
     File produced by dcm2niix containing the slice ordering.
 
   --output-file
     File to save output. An annotated version is written to stdout.

  Options:

    --ignore-slices 
      Number of slices to ignore, starting at 0. Sometimes slices have to be cut off
      to make topup happy. If this is done, the slice numbering must be changed accordingly
 
  Output:
  
   Slice ordering in the format required by eddy. From the eddy manual, the example is:

    0 5 10
    2 7 12
    4 9 14
    1 6 11
    3 8 13

   meaning MBA factor 3 and slices 0, 5, and 10 are acquired together, etc. Note the 
   slice numbers are indexed from 0.


   IMPORTANT: This script assumes that the slice timings go from the bottom of the image to the top.   

   I think this is true for Siemens data, see https://www.mccauslandcenter.sc.edu/crnl/tools/stc 



  
};

if ($#ARGV < 0) {
    print $usage;
    exit 1;
}


my $jsonFile = "";

my $outputFile = "";

my $ignoredSlices = 0;

GetOptions ("input-file=s" => \$jsonFile,
	    "output-file=s" => \$outputFile,
	    "ignore-slices=i" => \$ignoredSlices
    )
    or die("Error in command line arguments\n");


if (!length($outputFile)) {
    die "  Output file required\n";
}


local $/ = "";

open (my $fh, "<", $jsonFile) or die "  Cannot read input file $jsonFile\n";

my $json = <$fh>;

close($fh);

$/ = "\n";

$json =~ /"MultibandAccelerationFactor": (\d+)/;

my $mba = $1;

if (! $mba ) {
    die "  Cannot read Multiband Acceleration Factor from JSON file\n";
}

$json =~ m/"SliceTiming": \[([^\]]+)\]/;

my $timingList = $1;

$timingList =~ s/\s//g;

# Timings for each slice
my @sliceTimings = split(",", $timingList);

# Remove any slices that are not included in the data passed to topup / eddy
@sliceTimings = @sliceTimings[$ignoredSlices .. $#sliceTimings];

# List of acquisition times, slices acquired together share one of these times
my @acquisitionTimes = uniq(sort {$a <=> $b} @sliceTimings);


my $numGroups = scalar(@acquisitionTimes);

# Final product is the list of slices in each group
my @slSpec = ("")x$numGroups;

# group counter 
my $group = 0;

for (my $sliceCounter = 0; $sliceCounter < scalar(@sliceTimings); $sliceCounter++) {

    my $sliceTime = $sliceTimings[$sliceCounter];

    for ($group = 0; $group < $numGroups; $group++) {
	
	if ($sliceTime == $acquisitionTimes[$group]) {
	    $slSpec[$group] = "$slSpec[$group] $sliceCounter"; 
	    last;
	}
    }
}

for ($group = 0; $group < $numGroups; $group++) {
    $slSpec[$group] =~ s/^ //;
}

open($fh, ">", "$outputFile");

print $fh join("\n", @slSpec);

close($fh);

print "\nMultiband acceleration factor: $mba \n";

print "\nSlices,AcquisitionTime\n";

for ($group = 0; $group < $numGroups; $group++) {
    my $line = "$slSpec[$group],$acquisitionTimes[$group]";

    $line =~ s/ /,/g;

    print "$line\n";
}

