#!/usr/bin/perl

# CREATE TABLE builds (
#    repo TEXT,
#    project TEXT,
#    build INTEGER,
#    branch TEXT,
#    commit TEXT,
#    status TEXT,
#    duration TEXT,
#    started TEXT,
#    completed TEXT,
#    triggered_by TEXT,
#    description TEXT,
#    overnight INTEGER,
#    logs TEXT,
#    artifacts TEXT,
#    images TEXT
# );

use strict;
use warnings;
use Text::CSV;

my $input = shift || 'builds.csv';

my $csv = Text::CSV->new({
    binary    => 1,
    auto_diag => 1,
});

open my $fh, '<', $input
    or die "Cannot open $input: $!";

my $header = $csv->getline($fh);

die "Empty CSV\n" unless $header;

# Convert CSV column names to SQL-safe identifiers.
my @columns = map {
    '"' . $_ =~ s/"/""/gr . '"'
} @$header;

print "BEGIN TRANSACTION;\n\n";

while (my $row = $csv->getline($fh)) {

    my @values = map {
        if (!defined($_) || $_ eq '') {
            'NULL';
        } else {
            "'" . $_ =~ s/'/''/gr . "'";
        }
    } @$row;

    print "INSERT INTO builds (";
    print join(', ', @columns);
    print ") VALUES (";
    print join(', ', @values);
    print ");\n";
}

print "\nCOMMIT;\n";

close $fh;
