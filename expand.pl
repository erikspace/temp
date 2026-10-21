#!/usr/bin/perl

use strict;
use warnings;

my $input = shift || 'all.csv';

open my $in, '<', $input
    or die "Cannot open $input: $!";

my $header = <$in>;
chomp $header;

my @columns = split /,/, $header;

my %column;
@column{@columns} = (0 .. $#columns);

die "CSV has no project column\n"
    unless exists $column{project};

print "$header\n";

while (<$in>) {
    chomp;

    my @row = split /,/, $_, -1;

    if (defined $row[$column{project}]
        && lc($row[$column{project}]) eq 'integrated') {

        for my $project ('Bandit', 'Eyespy', 'KSA 400', 'ICE', 'MOS') {
            my @new_row = @row;
            $new_row[$column{project}] = $project;
            print join(',', @new_row), "\n";
        }

    } else {
        print "$_\n";
    }
}

close $in;
