#!/usr/bin/perl
##############################################################################
# Website-Check
##############################################################################
# Auslesen von Websites aus einem Index und ueberpruefen nach
# diversen Kriterien
##############################################################################
use utf8;
use Encode;
binmode(STDOUT, ":utf8");
binmode(STDIN, ":utf8");
use open ':utf8';
use Getopt::Long;
use lib './WWW-Analyse/lib/';
use WWW::Analyse;
use strict;
##############################################################################

use Data::Dumper;

my @DESIGNLIST = (
	"d3-ocean",
	"d3-fire",
	"d3-bio",
	"d4",
	"d4-2spalter",
	"d5",
	"d6-gelb",
	"d6",
	"d7",
	"d7-2spalter",
	"flexi",
	"rrze-portal"	
);

my $parameter = GetParameter();
if ($parameter->{'list'}) {
	analyselist($parameter->{'list'})
} elsif ($parameter->{'url'}) {
	analyse($parameter->{'url'});
}

exit;
##############################################################################
# Funktionen
##############################################################################
sub analyselist {
	my $list = shift;
	
	if (not (-r $list)) {
		print STDERR "Cannot read URL-List \"$list\"\n";
		exit;
	}
	my $url;
	my @urllist;
	
	open(f1,"<$list");
		while(<f1>) {
			chomp($_);
			next if ($_ !~ /^Server/i);
			
			(undef,$url) = split(/\s+/,$_,2);
			if ($url) {
				push(@urllist, $url);
			}
		}
	close f1;
	
	if (not @urllist) {
		print STDERR "No URL found in URL-List file \"$list\"\n";
		print STDERR "Notice: Each line with a URL must start with \"Server\". Example:\n";
		print STDERR "  Server http://www.example.org\n";
		print STDERR "Other lines are ignored.\n";
		exit;		
	}
	
	
	my $i;
	if ($parameter->{'sortlist'}) {
		@urllist = sort @urllist;
	}

	for ($i=0; $i<=$#urllist; $i++) {
		if ($parameter->{'compactlist'}) {		
			compactanalyse($urllist[$i]);			
		} else {
			analyse($urllist[$i]);
		}
		sleep(1);
	}
}
##############################################################################
sub compactanalyse {
	my $url = shift;
	my $website = new WWW::Analyse;
	
	$website->url($url);		
	
	my $res = $website->get();
	my $info;	
	my $modidate = $website->getheader("Date") || $website->getheader("last-modified") || $website->{'last-modified'};
	my $title =  	$website->getheader("Title");
	$url =~ s/http(s|):\/\///gi;
	if (not $res) {
		my $statuscode = $website->statuscode();
		if (not $title) {
			$title = "(Zugriff nicht moeglich)";
		}
		
		$info = "ERROR $statuscode";
		$info .= "\t$modidate\t";
		printf "%-45s\t%-50s\t%s\n",$url,$title,$info; 
		return;
	}
	if (not $title) {
		$title =  "(Seitentitel nicht gesetzt)";	
	}

	my $list = $website->getheaderlinks();
	my $version = 	$website->webbaukasten();
	my $gen =	$website->findgenerator();	
	$title =~ s/\s*$//gi;
	$title =~ s/^\s*//gi;
	my $key;
	my $design;

	

	
	if ($version) {					
		foreach $key (sort {$a <=> $b}keys %{$list}) {
			if (($list->{$key}->{'type'} =~ /css/i) && ($list->{$key}->{'media'} !~ /alternate/i)) {
				if (($list->{$key}->{'media'} =~ /projection/i)
					&& ($list->{$key}->{'title'} =~ /default/)) {					
					$design = $list->{$key}->{'url'};
					$design =~ s/\/css\///gi;
					$design =~ s/\/(.*)$//gi;					
					
				}
			}
				
		}
		if (not $design) {
			$design = "modifiziert";
		} else {
			my $d;
			my $found;
			for ($d=0; $d<=$#DESIGNLIST; $d++) {			
				if (lc($design) eq lc($DESIGNLIST[$d])) {
					$found = 1;
					last;
				}
			}
			if (not $found) {
				$design .= " (modifiziert)";
			}
		}
		my $rel = $website->{'body'}->{'data'}->{'webbaukasten_relauch'} || $modidate;
		$info = "Webbaukasten Version $version\t$rel\t$design";	
	} else {
		if ($gen) {
			if (ref($gen) eq "ARRAY") {
				my $l;
				my @this = @{$gen};
				for ($l=0; $l<=$#this;$l++) {
					$info .= ", " if ($info);
					$info .= "$this[$l]";
				}
			} else {
				$info = $gen;
			}
		} else {
			$info = "Unbekannt";
		}
		$info .= "\t$modidate\t";
	}
	my $tracker = $website->findtracker();
	if (($parameter->{'showtracker'}) &&($tracker)) {
		$info .="\tTracker: ";
		my $track;
		foreach $track (keys %{$website->{'body'}->{'data'}->{'tracker'}}) {
			$info .= "$track; " if ($website->{'body'}->{'data'}->{'tracker'}->{$track}==1);
		}
			
	}
	
	printf "%-45s\t%-50s\t%s\n",$url,$title,$info;
	return;
}
##############################################################################
sub analyse {
	my $url = shift;
	
	my $website = new WWW::Analyse;
	$website->url($url);		
	my $status = $website->get();
	if ($status==0) {
		print STDERR "Fehler. Website konnte nicht ausgelesen werden. Code: ", $website->statuscode(), "\n";
		return;
	}

	my $list = $website->getheaderlinks();
	
	print "$url\t";
	print $website->getheader("Title");
	print "\n";
	
	
	my $key;
	my $i;
	foreach $key (sort {$a <=> $b}keys %{$list}) {
		if ($parameter->{'showcss'}) {
			if (($list->{$key}->{'type'} =~ /css/i) && ($list->{$key}->{'media'} !~ /alternate/i)) {
				print "\t";
				print "$list->{$key}->{'url'}";
				if ($list->{$key}->{'media'}) {
					print "\t$list->{$key}->{'media'}";
				}
				if ($list->{$key}->{'title'}) {
					print " ($list->{$key}->{'title'})";
				}
				print "\n";
				
			}
		}
			
	}
	if ($parameter->{'checkwebbaukasten'}) {
		print "\tWebbaukasten	\t";
		my $version = $website->webbaukasten();
		if ($version) {
			print "Ja";			
			print "  (Version $version)";
		} else {
			print "Nein";
		}
		print "\n";
	}
	
	if ($parameter->{'showgenerator'}) {
		my $gen =$website->findgenerator();				
		$gen = "Unbekannt" if (not $gen);
		 print "\tGenerator: \"$gen\"\n";	
	}	
	if ($parameter->{'showdoclinks'}) {
		my $links = $website->getdocumentlinks();
		my $found;
		 print "\tLinks:\n";
		if ($links) {
		my @liste = @{$links};
		for ($i=0; $i<=$#liste; $i++) {
			next if (not $liste[$i]->{'href'});
			if (($liste[$i]->{'href'} =~ /^#/i) && (not $parameter->{'showanchor'})) {
				next;
			}
			print "\t\t$liste[$i]->{'href'} ($liste[$i]->{'text'})\n";
			$found =1;
		}
		}
		print "\t\tKeine Links gefunden\n" if (not $found);
	}
	if ($parameter->{'showdocimages'}) {
		my $links = $website->getdocumentimages();
	 	my @liste;	
		if ($links) {
			@liste = @{$links};
		}
		my $found;
		print "\tImages:\n";
		for ($i=0; $i<=$#liste; $i++) {
			next if (not $liste[$i]->{'href'});
			print "\t\t$liste[$i]->{'href'} ($liste[$i]->{'alt'})\n";
			$found =1;
		}
		print "\t\tKeine Bilder gefunden\n" if (not $found);
	}	
	
	my $tracker = $website->findtracker();
	if (($parameter->{'showtracker'}) &&($tracker)) {
		print "\tTracker-Software gefunden\n";
		my $track;
		foreach $track (keys %{$website->{'body'}->{'data'}->{'tracker'}}) {
			print "\t\t$track\n" if ($website->{'body'}->{'data'}->{'tracker'}->{$track}==1);
		}
		
		
	}
}
##############################################################################
sub GetParameter {
	my $result;
	my $quiet;
	my $url;
	my $showcss =1;
	my $help;
	my $showgenerator =1;
	my $showdoclinks = 1;
	my $showdocimages = 1;
	my $showanchor =0;
	my $checkwebbaukasten =1;
	my $list;
	my $sortlist =1;
	my $compactlist =1;
	my $showtracker = 0;
	my $options = GetOptions("url=s" 		=> \$url,
				"showcss" 		=> \$showcss,
				"showgenerator|gen" 	=> \$showgenerator,
				"showdoclinks|links" 	=> \$showdoclinks,
				"showdocimages" 	=> \$showdocimages,
				"showanchor" 		=> \$showanchor,
				"checkwebbaukasten" 	=> \$checkwebbaukasten,
				"showtracker"	=> \$showtracker,
				"list=s"		=> \$list,
				"help|h|?"		=> \$help,
				"sortlist"		=> \$sortlist,
				"quiet|q" 		=> \$quiet,
				"compactlist" 		=> \$compactlist,		
			);
					
	
	if (($help) || ((not $url) && (not $list))) {
		print "$0 [Options]\n";
		print "Options could be:\n";
		print "\turl=s          -  URL to look for\n";
		print "\tlist=s         -  File of URLs to check. Each URL must be start with \'Server URL\'\n";		
	#	print "\tquiet    - No output on stdout\n";
		print "\tshowcss        - Show CSS-Informations\n";	
		print "\tshowgenerator  - Display Generator-Meta\n";	
		print "\tshowdoclinks   - Show links in body\n";	
		print "\tshowdocimages  - Show images in body\n";
		print "\tcheckwebbaukasten - Pruefe ob die Website den Webbaukasten nutzt\n";
		print "\tcompactlist    - Wenn eine Liste geprueft wird, wird mit diesem Modus\n";
		print "\t                  eine uebersichtlicher Kurztest gemacht\n";
		exit;
	}

	$result->{'url'} = $url;	
	$result->{'list'} = $list;	
	
	$result->{'showcss'} = $showcss;
	$result->{'showgenerator'} = $showgenerator;
	$result->{'showdoclinks'} = $showdoclinks;	
	$result->{'showdocimages'} = $showdocimages;
	$result->{'showanchor'} = $showanchor;
	$result->{'checkwebbaukasten'} = $checkwebbaukasten;
	$result->{'showtracker'} = $showtracker;
	$result->{'help'} = $help;
	$result->{'quiet'} = $quiet;
	$result->{'sortlist'} = $sortlist;
	$result->{'compactlist'} = $compactlist;
	
	
	
	
	return $result;
	
}

##############################################################################
# EOF
##############################################################################


