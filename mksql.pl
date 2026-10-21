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

my $input = shift || 'all.csv';

open my $fh, '<', $input
    or die "Cannot open $input: $!";

sub parse_csv_line {
    my ($line) = @_;
    my (@fields, $field);
    my $quoted = 0;
    $field = '';

    # Remove the record-ending newline.
    $line =~ s/\r?\n$//;

    my @chars = split //, $line;

    for (my $i = 0; $i < @chars; $i++) {
        my $c = $chars[$i];

        if ($quoted) {
            if ($c eq '"') {
                if ($i + 1 < @chars && $chars[$i + 1] eq '"') {
                    $field .= '"';
                    $i++;
                } else {
                    $quoted = 0;
                }
            } else {
                $field .= $c;
            }
        } elsif ($c eq ',' ) {
            push @fields, $field;
            $field = '';
        } elsif ($c eq '"' && $field eq '') {
            $quoted = 1;
        } else {
            $field .= $c;
        }
    }

    die "Unterminated quoted CSV field\n" if $quoted;

    push @fields, $field;
    return @fields;
}

my $header_line = <$fh>;
die "Empty CSV\n" unless defined $header_line;

my @headers = parse_csv_line($header_line);

# Quote SQL identifiers safely.
my @columns = map {
    my $name = $_;
    $name =~ s/"/""/g;
    qq{"$name"};
} @headers;

print "BEGIN TRANSACTION;\n";

while (my $line = <$fh>) {
    next if $line =~ /^\s*$/;

    my @fields = parse_csv_line($line);

    die "Column count mismatch in CSV row\n"
        unless @fields == @headers;

    my @values = map {
        if (!defined($_) || $_ eq '') {
            'NULL';
        } else {
            my $value = $_;
            $value =~ s/'/''/g;
            "'$value'";
        }
    } @fields;

    print "INSERT INTO builds (",
          join(', ', @columns),
          ") VALUES (",
          join(', ', @values),
          ");\n";
}

print "COMMIT;\n";

close $fh;
