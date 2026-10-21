#!/usr/bin/perl

use strict;
use warnings;
use Text::CSV;

my $input = shift || 'all.csv';

my $csv = Text::CSV->new({
    binary    => 1,
    auto_diag => 1,
});

open my $in, '<', $input
    or die "Cannot open $input: $!";

my $header = $csv->getline($in);
$csv->print(\*STDOUT, $header);
print "\n";

my %column;
@column{@$header} = (0 .. $#$header);

die "CSV has no project column\n"
    unless exists $column{project};

while (my $row = $csv->getline($in)) {

    if (defined $row->[$column{project}]
        && lc($row->[$column{project}]) eq 'integrated') {

        for my $project ('Bandit', 'Eyespy', 'KSA 400', 'ICE', 'MOS') {
            my @new_row = @$row;
            $new_row[$column{project}] = $project;

            $csv->print(\*STDOUT, \@new_row);
            print "\n";
        }

    } else {
        $csv->print(\*STDOUT, $row);
        print "\n";
    }
}

close $in;
