#!/usr/bin/env perl

use strict;
use warnings;

my $csv_file = $ARGV[0] // 'builds.csv';
my $sh_file  = $ARGV[1] // 'generate-changes.sh';

sub parse_csv_line {
    my ($line) = @_;
    chomp $line;
    $line =~ s/\r$//;

    my (@fields, $field);
    my $quoted = 0;
    $field = '';

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

my %builds;

while (my $line = <$in>) {
    next if $line =~ /^\s*$/;

    my @fields = parse_csv_line($line);

    my $build  = $fields[$column{build}]  // '';
    my $commit = $fields[$column{commit}] // '';

    next unless $build =~ /^\d+$/;
    next unless $commit =~ /^[0-9a-fA-F]+$/;

    if (exists $builds{$build}) {
        die "Conflicting commit hashes for build $build\n"
            if lc($builds{$build}) ne lc($commit);
        next;
    }

    $builds{$build} = $commit;
}

close $in;

my @build_numbers = sort { $b <=> $a } keys %builds;

open my $out, '>', $sh_file
    or die "Cannot create $sh_file: $!\n";

print $out "#!/bin/sh\nset -e\n\n";
print $out "mkdir -p changelogs\n\n";

# Skip the oldest build; it has no previous build to compare against.
for (my $i = 0; $i < $#build_numbers; $i++) {
    my $newer = $build_numbers[$i];
    my $older = $build_numbers[$i + 1];

    my $dir = "changelogs/BX$newer";

    print $out "mkdir -p $dir\n";
    print $out "git log $builds{$older}..$builds{$newer} > $dir/changes.txt\n\n";
}

close $out;

print "Generated $sh_file with ", $#build_numbers,
      " changelog commands\n";
