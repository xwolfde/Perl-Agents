#!/usr/bin/perl

use utf8;
binmode STDOUT, ":utf8";

my $utf8string = "ÖÄÜ öäü ß ";

print $utf8string;
print "\n";


use Encode qw(decode encode);

$characters = decode('UTF-8', $utf8string    );
print "DECODE(UTF8,$utf8string) = $characters\n";

$octets     = encode('UTF-8', $utf8string);
print "ENCODE(UTF8,$utf8string) = $octets\n";


$data = decode("iso-8859-1", $utf8string);  #2
print "DECODE(ISO,$utf8string) = $data\n";

$data = encode("iso-8859-1", $utf8string);  #2
print "ENCODE(ISO,$utf8string) = $data\n";

