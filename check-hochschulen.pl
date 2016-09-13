#!/usr/bin/perl
#
# @File check-hochschulen.pl
# @Author unrz59
# @Created 06.11.2015 12:15:33
#


use utf8;
use CheckRFC;
use strict;
use Getopt::Long;
use lib './WWW-Analyse/lib/';
use WWW::Analyse;
use Storable;
use open qw/:std :encoding(utf8)/;

my $CONST = {
    "store_file"	=> 'Hochschulen.store',
    "useragent"		=> 'Mozilla/5.0',
    "cachetime_single"	=> 60*60*24*7*30,
    "max_update"	=> 500,
    "errorurl_file"	=> 'error-urls.txt',
    "current_csv_file"	=> 'current.csv',
};

my $params = GetParams();
my $data = GetCachedHochschulData();


if (not $data) {
    print "No data found.\n";
    exit;
}
my $newdata = analyselist($data);
WriteHochschulData($newdata);

exit;

##############################################################################
# Funktionen
##############################################################################
sub analyselist {
	my $data = shift;
	my $key;
	my $url;
	my $gen;
	my $links;
	my $tracker;
	my $title;

	open(f3,">".$CONST->{'errorurl_file'});
	open(f4,">".$params->{'current_csv_file'});
	print f4 "Name\tURL\tCMS\tVersion\n";

    foreach $key (sort keys %{$data}) {
	$data->{$key}->{'Name'} =~s/&amp;/&/gi;
	next if not $key;
	if ($params->{'debug'}) {
	    print STDERR $key."\n";
	}
	if (($data->{$key}->{'url'}) && (!is_URL($data->{$key}->{'url'}))) {
	    # Eintrag vorhanden, aber inkorrekte Syntax.
	    if ($data->{$key}->{'url'} =~ /\s+/i) {
		# Falls mehrere URLs in der Zeile
		($data->{$key}->{'url'},undef) = split(/ /,$data->{$key}->{'url'},2);
	    }
	}
	if ( (not $data->{$key}->{'url'}) || (!is_URL($data->{$key}->{'url'}))) {
	    print f3 $data->{$key}->{'Name'}.":\n";
	    print f3 $data->{$key}->{'wikiurl'}.":\n";
	    print f3 " URL (".$data->{$key}->{'url'}.") invalid or empty\n";
	    print STDERR "\t\tURL invalid or empty\n";
	    next;
	}
	$url = $data->{$key}->{'url'};

	my $website = new WWW::Analyse;
	$website->url($url);		
	my $status = $website->get();
	if ($status==0) {
	        print f3 $data->{$key}->{'Name'}.":\n";
		print f3 $data->{$key}->{'wikiurl'}.":\n";
	        print f3 " URL (".$data->{$key}->{'url'}.") error on read: ".$website->statuscode()."\n";
		print STDERR "Fehler. Website konnte nicht ausgelesen werden. Code: ", $website->statuscode(), "\n";
		
		$gen = "Unbekannt"; 
		$data->{$key}->{'generator'} = $gen;
	} else {
	
	    $gen =$website->findgenerator();		
	    $gen =~s/^\s*//gi;
	    $gen =~s/\s*$//gi;
	    if (not $gen) {
		$gen  = "Unbekannt"; 
	    } else {
		my $ngen = $website->normalize_generator($gen);
		my $version;
		($gen,$version) = split(/;/,$ngen,2);
		if (not $gen) {
		    $gen = $ngen;
		} elsif ($version) {
		    $data->{$key}->{'generator-version'} = $version;
		}
	    }
	    $data->{$key}->{'generator'} = $gen;
	
	    $tracker = $website->listtracker();
	    $data->{$key}->{'tracker'} = $tracker;

	    $title = $website->get_pagetitle();
	    $data->{$key}->{'sitetitle'} = $title;
	}

	if ($params->{'debug'}) {
	    print  "\t$url\n";
	    print  "\tName: ".$data->{$key}->{'Name'}."\n";
	    print  "\tTitle: $title\n";
	    print  "\tGenerator: \"".$data->{$key}->{'generator'}."\"\n";
	    print  "\n";
	}
	print f4 $data->{$key}->{'Name'}."\t";
	print f4 $data->{$key}->{'url'}."\t";
	print f4 $data->{$key}->{'generator'};
	if ($data->{$key}->{'generator-version'}) {
	    print f4 "\t";
	    print f4 $data->{$key}->{'generator-version'};
	}
	print f4 "\n";
	
	
    }	
  
    close f4;
    close f3;

   return $data;

}

###############################################################################
sub GetCachedHochschulData {
    my $data;
    my $jsonfile = $CONST->{'store_file'};

    if (-r $jsonfile) {
    
	$data = retrieve($jsonfile);
	return $data;

    }  else {
	print STDERR "Es wurden noch keine Daten gespeichert in $jsonfile\n" if ($params->{'debug'});
	return;
    }


}
###############################################################################
sub WriteHochschulData {
    my $data = shift;
    my $jsonfile = $CONST->{'store_file'};
    
    if (-r $jsonfile) {
	rename($jsonfile,"$jsonfile.old");
    }

    store $data, $jsonfile;

}
###############################################################################
sub GetParams {
    my $help;
    my $result;
    my $debug =1;
    my $usecache =0;
    my $listout;
    my $maxupdate = $CONST->{"max_update"};
    my $unityp;
    my $cvsoutfile = $CONST->{'current_csv_file'};

    my $options = GetOptions(
			    "help|h|?"		=> \$help,
			    "debug" => \$debug,
			    "nocache" => \$usecache,
			    "listout=s" => \$listout,
			    "maxupdate=s"   => \$maxupdate,
			    "unityp=s"	 => \$unityp,
			    "csvout=s"	=> \$cvsoutfile,
			);
					
	
	if ($help) {
		print "$0 [Options]\n";
		print "Options could be:\n";
		print "\tdebug            -  Debugmode on\n";  
		print "\tunityp=staatlich|privat - Filter for kind of university\n";
		exit;
	}

    $listout =~s/[^a-z0-9\-\/\._]*//gi;

    $result->{'debug'} = $debug;	    
    $result->{'nocache'} = $usecache;	
    if (length($listout)>1) {
       $result->{'listout'} = $listout;	
    }
    if (($maxupdate) && ($maxupdate>0)) {
	$result->{'maxupdate'} = $maxupdate;
    } else {
	$result->{'maxupdate'} = $CONST->{"max_update"};
    }
    $result->{'current_csv_file'} = $cvsoutfile;

    return $result;
}


##############################################################################
