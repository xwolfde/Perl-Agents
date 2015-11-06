#!/usr/bin/perl
#
# @File check-hochschulen.pl
# @Author unrz59
# @Created 06.11.2015 12:15:33
#


use open qw/:std :encoding(utf8)/;
use utf8;
use CheckRFC;
use JSON;
use strict;
use Getopt::Long;
use lib './WWW-Analyse/lib/';
use WWW::Analyse;


my $CONST = {
    "json_index"	=> 'Liste_der_Hochschulen_in_Deutschland.json',
    "useragent"	=> 'Mozilla/5.0',
    "cachetime_single"	=> 60*60*24*7*30,
    "max_update"    => 20,
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
	
    foreach $key (sort {$a <=> $b} keys %{$data}) {
	if ($params->{'debug'}) {
	    print STDERR $key."\n";
	}
	
	if ( (not $data->{$key}->{'url'}) || (!is_URL($data->{$key}->{'url'}))) {
	    print STDERR "\t\tURL invalid or empty\n";
	    next;
	}
	$url = $data->{$key}->{'url'};

	my $website = new WWW::Analyse;
	$website->url($url);		
	my $status = $website->get();
	if ($status==0) {
		print STDERR "Fehler. Website konnte nicht ausgelesen werden. Code: ", $website->statuscode(), "\n";
		next;
	}
	
	$gen =$website->findgenerator();				
	$gen = "Unbekannt" if (not $gen);
	$data->{$key}->{'generator'} = $gen;

	$links = $website->getdocumentlinks();
	my @liste = @{$links};
	$data->{$key}->{'linknum'} = $#liste;

	$tracker = $website->listtracker();
	$data->{$key}->{'tracker'} = $tracker;

	$title = $website->get_pagetitle();
	$data->{$key}->{'sitetitle'} = $title;

	if ($params->{'debug'}) {
	    print  "\t$url\n";
	    print  "\tTitle: $title\n";
	    print  "\tGenerator: $gen\n";
	    print  "\n";
	}

    }	
  
   return $data;

}

###############################################################################
sub GetCachedHochschulData {
    my $data;
    my $jsonfile = $CONST->{'json_index'};

    if (-r $jsonfile) {

        open( my $fh, '<', $jsonfile );
	my $json_text   = <$fh>;
	$data = decode_json( $json_text );
	close $fh;
	return $data;

    }  else {
	print STDERR "Es wurden noch keine Daten gespeichert in $jsonfile\n" if ($params->{'debug'});
	return;
    }


}
###############################################################################
sub WriteHochschulData {
    my $data = shift;
    my $jsonfile = $CONST->{'json_index'};
    
    if (-r $jsonfile) {
	rename($jsonfile,"$jsonfile.old");
    }

    my $utf8_encoded_json_text = encode_json $data;
    open(f1,">$jsonfile");
    print f1 $utf8_encoded_json_text;
    close f1;

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


    my $options = GetOptions(
			    "help|h|?"		=> \$help,
			    "debug" => \$debug,
			    "nocache" => \$usecache,
			    "listout=s" => \$listout,
			    "maxupdate=s"   => \$maxupdate,
			    "unityp=s"	 => \$unityp,
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


    return $result;
}


##############################################################################
