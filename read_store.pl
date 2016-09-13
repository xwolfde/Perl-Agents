#!/usr/bin/perl

use utf8;

use strict;
use Storable;
use open qw/:std :encoding(utf8)/;

my $filename = $ARGV[0];

print "open $filename\n";


my $hashref = retrieve($filename);
my $key;
my $subkey;
foreach $key (sort {$a <=> $b} keys %{$hashref}) {
    print "$key\n";
    foreach $subkey (keys %{$hashref->{$key}}) {
	print "\t".$subkey.": \t".$hashref->{$key}->{$subkey}."\n";
    }	
}