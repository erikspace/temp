#!/usr/bin/env perl

use strict;
use warnings;

my $csv_file = $ARGV[0] // 'builds.csv';
my $sh_file  = $ARGV[1] // 'generate-changes.sh';

# Read a standard CSV line, including quoted fields.
sub parse_csv_line {
    my ($line) = @_;
    chomp $line;
    $line =~ s/\r$//;

    my @fields;
    my $field = '';
    my $quoted = 0;

    for (my $i = 0; $i < length($line); $i++) {
        my $c = substr($line, $i, 1);

        if ($quoted) {
            if ($c eq '"') {
                if (substr($line, $i + 1, 1) eq '"') {
                    $field .= '"';
                    $i++;
                } else {
                    $quoted = 0;
                }
            } else {
                $field .= $c;
            }
        } elsif ($c eq ',') {
            push @fields, $field;
            $field = '';
        } elsif ($c eq '"') {
            $quoted = 1;
        } else {
            $field .= $c;
        }
    }

    die "Unclosed CSV quote\n" if $quoted;
    push @fields, $field;

    return @fields;
}

open my $in, '<', $csv_file
    or die "Cannot open $csv_file: $!\n";

my $header = <$in> // die "Empty CSV file\n";
my @headers = parse_csv_line($header);

my %column;
@column{@headers} = (0 .. $#headers);

die "CSV must contain build and commit columns\n"
    unless exists $column{build} && exists $column{commit};

my @rows;

while (my $line = <$in>) {
    next if $line =~ /^\s*$/;

    my @fields = parse_csv_line($line);

    my $build  = $fields[$column{build}]  // '';
    my $commit = $fields[$column{commit}] // '';

    next unless $build =~ /^\d+$/;
    next unless $commit =~ /^[0-9a-fA-F]+$/;

    push @rows, {
        build  => $build,
        commit => $commit,
    };
}

close $in;

# Newest build first.
@rows = sort { $b->{build} <=> $a->{build} } @rows;

open my $out, '>', $sh_file
    or die "Cannot create $sh_file: $!\n";

print $out "#!/bin/sh\nset -e\n\n";

# Compare each build with the next older build.
# The oldest build has no comparison, so it is skipped.
for (my $i = 0; $i < $#rows; $i++) {
    my $newer = $rows[$i];
    my $older = $rows[$i + 1];

    my $dir = "BX$newer->{build}";

    print $out "mkdir -p $dir\n";
    print $out "git log $older->{commit}..$newer->{commit} > $dir/changes.txt\n\n";
}

close $out;

print "Generated $sh_file\n";
