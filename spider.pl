#!/usr/bin/perl -w
# spider.pl
# Spiders a given url up to a given depth. 
# Frameset are not counted as a level for the depth bound.
# The search can be restricted by a mask.
# For all subdomains the start page and one random page is validated at w3 and
# the existence of a impressum is checked.


use strict;

#-----

require LWP::UserAgent;
require URI::URL;
use List::Util 'shuffle';
# use WWW::CheckSite::Validator;




my $impr = "(([I,i]mpressum)|([K,k]ontakt))";
my $version = 0.05;
my $ua; 			#LWP::RobotUA
my $url;			#URL::URI
my $content;

#params, given by ARGV
my $start;
my $depth;
my $mask;
my $validate;
my $checkimpressum;

# global results
my %subdomains;
my %unsubdomains;
my @errors;
my @deadlinks;
my %unvisited;
my %visited;

#-----


#Initialize UserAgent
$ua = LWP::UserAgent->new;
$ua->agent('Spider $version');
$ua->protocols_allowed( [ 'http', 'https'] );
$ua->timeout(10);
$ua->env_proxy;

$url = URI::URL->new;

print "$0 - $version\n";

if (!$ARGV[0]) {
	print "Usage: perl $0 <URL> <depth> <mask> <validate> <checkimpressum>\n";
	print "Example: perl $0 ".
		"http://wwwcip.informatik.uni-erlangen.de/~sidamich/blackamp/main.html 5 ".
		"http://wwwcip.informatik.uni-erlangen.de/~sidamich/blackamp/ 1 1\n";
	print "If depth is '0', the script searches without any limit.\n";
	print "Framesets do NOT count as a level for depth!\n";
	exit;
}


$start = $ARGV[0];
$depth = $ARGV[1];
$mask = $ARGV[2];
$validate = $ARGV[3];
$checkimpressum = $ARGV[4];
spider($start, 0, 0);

if(%unvisited) {
	print "\n\nUnvisited pages: " . (keys %unvisited) ."\n";
	foreach (sort keys %unvisited) {
		print "$_\n";
	}
}

#if(%visited) {
#	print "\n\nVisited pages: " . (keys %visited) . "\n";
#	foreach (sort keys %visited) {
#		print "$_\n";
#	}
#}

if(%unsubdomains) {
	print "\n\nUnvisited subdomains: " . (keys %unsubdomains) . "\n";
	foreach (sort keys %unsubdomains) {
		print "$_\n";
	}
}

if(%subdomains) {
	print "\n\nVisited sudomains: " . (keys %subdomains) ."\n";
	foreach (sort keys %subdomains) {
		print "$_\n";
	}
}

if(@deadlinks) {
	print "\n\nDeadlinks: " . ($#deadlinks + 1) ."\n";
	foreach (sort @deadlinks) {
		print "$_\n";
	}
}

if(@errors) {
	print "\n\nErrors: " . (($#errors + 1) / 2) ."\n";
	foreach (@errors) {
		print "$_\n";
	}
}

if($validate){
	# Validate first and one random page of each subdomain
	if(%subdomains) {
		print "----\nValidation results: \n";
		foreach (sort keys %subdomains) {
			my $temp = $_;
			my @urls;
			my $wcv;
			foreach(keys %visited){
				if($_ =~ m/^$temp/) {
					push @urls, $_;
				}
			}

	#		$wcv = WWW::CheckSite::Validator->new(uri => $temp);
	#		print $wcv->write_report;

	#		$temp = $urls[rand @urls];
	#		$wcv = WWW::CheckSite::Validator->new(uri => $temp);
	#		print $wcv->write_report;
		}
	}
}

if($checkimpressum) {
	# Check each Subdomain for existing impressum.
	if(%subdomains) {
		print "----\nSubdomains without Impressum: \n";
		foreach (sort keys %subdomains) {
			delete @visited{keys %visited};
			$content = "";
			$mask = $_;
			$depth = 1;
			spider($_, 0, 1);
			#print $content;

			if(!($content =~ m/$impr/i)){
				print $_ . "\n";
			}
				
		}
	}
}


	
#-----

# spider
# 	parameter: <URL to spider>, <current depth>, <savecontent>
# 	returns: <success>, -1 on errors, 0 otherwise
sub spider{
	my $todo = $_[0];
	my $curdepth = $_[1];
	my $savecon = $_[2];
	my $response;
	my @links;
	my $page;
	my $subdomain;

	$todo =~ s/\?/\\\?/g;
	$todo =~ m/^(http:\/\/[^\/]*)/;
	$subdomain = $1;
	

	#stop recursion if $todo was already visited, $todo is outside mask or if
	#depth bound is reached
	if($mask and !($todo =~ m/$mask/)) {
		$todo =~ s/\\\?/\?/g;
		$unvisited{$todo . ", reason: mask"} = 1;
		$unsubdomains{$subdomain} = 1;
		return 0;
	}
	if(grep(/^$todo$/, %visited)) {
		return 0;
	}
	if($depth and $curdepth >= $depth)	{
		$todo =~ s/\\\?/\?/g;
		$unvisited{$todo . ", reason: depth"} = 1;
		$unsubdomains{$subdomain} = 1;
		return 0;
	}

	$todo =~ s/\\\?/\?/g;

	$response = $ua->get($todo);

	#$todo =~ s/[^\/]*$//;
		print "Spidering $todo\n";
	

	if ($response->is_success) {
		$subdomains{$subdomain} = 1;
		$visited{$todo} = 1;

		# Get links, ignore comments and split links to @links
		$page = $response->content;
		if($savecon) {
			$content .= $page;
		}
		$page =~ s/<!--.*?-->//sg;

		@links = split(/>/, $page);

#		@lines = $response->content =~ /<a .*href(..)<\/a>/g

		foreach (@links) {
			my $tempdepth = $curdepth;
			my $entry = $_;
			my $target;

			if(/<a [^>]*href=\"([^\"]*)/) {
				$target = $1;
			} elsif(/<frame [^>]*src=\"([^\"]*)/) {
				$target = $1;
				$tempdepth--;
			}
			if($target) {
				# To analyse errors you can use this to print $entrys for erroneuos targets
				if ($target =~ /^\.\//) {
					print "Target = $target\n";
					print "$entry\n";
				}

				if($target =~ m/^#/ or $target =~ m/^mailto:/){
					#Don't do anything, we don't need them
				} else {
					my $next = (URI::URL->new($target, $response->base))->abs;
					my $return = spider($next, $tempdepth + 1, $savecon);
					if ($return == -1) {
						push @deadlinks, "$todo links to $next";
					} elsif($return == 2) {
						push @errors, "\tFound on $todo";
					}
				}
			}
		}
	} else {
		if($response->status_line =~ m/^404/){
			return -1;
		} else {
			push @errors, $response->status_line . ": $todo";
			return 2;
		}
	}
	return 0;
}
