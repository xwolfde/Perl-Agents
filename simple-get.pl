#!/usr/bin/perl
#
# @File simple-get.pl
# @Author unrz59
# @Created 09.10.2015 15:48:37
#

use strict;
use Getopt::Long;
require LWP::UserAgent;
 


my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;
$ua->ssl_opts("verify_hostname" => 0);
my $options = GetParams();
my $geturl;


if ($options->{'url'}) {
    $geturl = $options->{'url'};
} else {
    print STDERR "Enter URL.\n";
    print STDERR "$0 --url=http://www.rrze.de\n";
    exit;
}

if ($options->{'debug'}) {
    print "SSL Opts:\n";
    print $ua->ssl_opts;
}

my $response = $ua->get($geturl); 
 
 if ($response->is_success) {
     print $response->decoded_content;  # or whatever
 }
 else {
     die $response->status_line;
 }
exit;

############
# Subs
############
sub GetParams {
    my $url;
    my $help;
    my $result;
    my $debug =1;
    my $options = GetOptions("url=s" 		=> \$url,
			    "help|h|?"		=> \$help,
			    "debug" => \$debug,
			
			);
					
	
	if (($help) || ((not $url) )) {
		print "$0 [Options]\n";
		print "Options could be:\n";
		print "\turl=s          -  URL to look for\n";
		
		exit;
	}

    $result->{'url'} = $url;	
    $result->{'debug'} = $debug;	

    return $result;
}