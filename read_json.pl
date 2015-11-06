#!/usr/bin/perl
#
# @File read_json.pl
# @Author unrz59
# @Created 06.11.2015 10:35:30
#

use strict;
use JSON;

my $filename = $ARGV[0];

print "open $filename\n";

my $json_text = do {
   open(my $json_fh, "<:encoding(UTF-8)", $filename)
      or die("Can't open \$filename\": $!\n");
   local $/;
   <$json_fh>
};

my $json = JSON->new;
print $json->pretty->encode($json->decode($json_text));

exit;

