#!/usr/bin/perl
#
# @File get_hochschulen.pl
# @Created 09.10.2015 16:10:36
#

use utf8;
use strict;
use Getopt::Long;
use LWP::UserAgent;
use HTML::TableExtract;
use CheckRFC;
use Storable;
use open qw/:std :encoding(utf8)/;



my $CONST = {
    "source_url"	=> 'https://de.wikipedia.org/wiki/Liste_der_Hochschulen_in_Deutschland',
    "wikibase_url"	=> 'https://de.wikipedia.org',
    "cache_file"	=> 'Hochschulen.html',
    "store_file"	=> 'Hochschulen.store',
    "useragent"		=> 'Mozilla/5.0',
    "cachetime_single"	=> 60*60*24*7*30,
    "max_update"	=> 500,
    "unityp"		=> 'staatlich',
};

my $params = GetParams();
my $page;

if (($params->{'nocache'}!=1) && (-r $CONST->{"cache_file"})) {
    print STDERR "Using Cache\n";
    $page = LoadCache($CONST->{"cache_file"});
} else {
    print STDERR "Loading from ".$CONST->{"source_url"}."\n";

    $page = GetWikiIndex();
    WriteCache($CONST->{"cache_file"},$page);
}


my $indexdata = ExtractHochschulen($page);
my $olddata = GetCachedHochschulData();
$indexdata = Mergedata($indexdata,$olddata);
$indexdata = UpdateHochschulData($indexdata,1);
WriteHochschulData($indexdata);

if ($params->{'listout'}) {
    WriteList($indexdata);
}
exit;


###############################################################################
# Subs
###############################################################################
sub WriteList {
 my $data = shift;
    my $file = $params->{'listout'};
    

    if (-r $file) {
	rename($file,"$file.old");
    }
    my $key;
    my $subkey;

    open(f1,">$file");
	foreach $key (sort {$a <=> $b} keys %{$data}) {
	    if (is_URL($data->{$key}->{'url'})) {
		print f1 "Server ";
		print f1 $data->{$key}->{'url'};
		print f1 "\n";
	    }
	}
    close f1;
    print STDERR "Wrote URL list in $file\n" if ($params->{'debug'});

}
###############################################################################
sub Mergedata {
    my $list1 = shift;
    my $list2 = shift;
    my $new_hash = $list1; # make a copy; leave %hash1 alone

    foreach my $key2 ( keys %{$list2} )  {
	if( exists $new_hash->{$key2} ) {
	    # found , only overwrite lastcheck and url
	    
	    $new_hash->{$key2}->{'lastcheck'} = $list2->{$key2}->{'lastcheck'};
	    $new_hash->{$key2}->{'url'} = $list2->{$key2}->{'url'};
	    if ($new_hash->{$key2}->{'lostindex'}) {
		# do not write it down anymore, therfore remove it
	    }
	}  else {
	    # entry is not in index anymore. Maybe outdated, note it down
	    $new_hash->{$key2} = $list2->{$key2};
	    $new_hash->{$key2}->{'lostindex'} = time;
	 }
    }

    return $new_hash;

}
###############################################################################
sub GetCachedHochschulData {
    my $data;
    my $jsonfile = $CONST->{'store_file'};

    if (-r $jsonfile) {
	
 $data = retrieve($jsonfile);



	#my $json_text = do {
	#   open(my $json_fh, "<:encoding(UTF-8)", $jsonfile)
	#   open(my $json_fh, "<", $jsonfile)
	 #     or die("Can't open \$jsonfile\": $!\n");
	  # local $/;
	 #  <$json_fh>
#	};

#	my $json = JSON->new->utf8;
#	$data = $json->decode($json_text);

        #open( my $fh, "<:encoding(UTF-8)", $jsonfile );
	#my $json_text   = <$fh>;
	#$data = decode_json( $json_text );
	#close $fh;
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

 #   my $utf8_encoded_json_text = encode_json $data;
 #   open(f1,">$jsonfile");
 #   print f1 $utf8_encoded_json_text;
 #   close f1;

     store $data, $jsonfile;
    
}
###############################################################################
sub UpdateHochschulData() {
    my $data = shift;
    my $key;
    my $check;
    my $cnt;
    my $thiscachetime = time - $CONST->{"cachetime_single"};
    my $adddata;
    my $gotdata =0;
    my $enough = 0;
    my $sleeptime;
    my $pending;
    my $jsonfile = $CONST->{'store_file'};

    foreach $key (sort {$a <=> $b} keys %{$data}) {

	if ($params->{'debug'}) {
	    print STDERR $key."\n";
	    print STDERR "\tWikiurl: \"".$data->{$key}->{'wikiurl'}."\"\n";
	    print STDERR "\tlastcheck: ".localtime($data->{$key}->{'lastcheck'})."\n";
	}
	if (not $data->{$key}->{'wikiurl'}) {
	    print STDERR "\t\tWikiURL invalid.\n";
	    next;
	}
	if (($params->{"unityp"}) && ($data->{$key}->{'Traeger'}) && ($data->{$key}->{'Traeger'} ne $params->{"unityp"} )) {
	    print STDERR "\t\tWrong typ: ".$data->{$key}->{'Traeger'}." Looking for: ".$params->{"unityp"}."\n";
	    next;
        }
	    $cnt++;

	    if (((not $data->{$key}->{'lastcheck'}) || ($data->{$key}->{'lastcheck'} < $thiscachetime)) && (not $enough)) {
		if ($params->{'debug'}) {
			print STDERR "\tUpdate data\n";
		}
		$gotdata++;
		$adddata = GetSingleWikiHochschule($data->{$key}->{'wikiurl'});
		$sleeptime = int(rand(2))+1;		
		print STDERR "\t\twaiting $sleeptime seconds...\n" if ($params->{'debug'});
		sleep($sleeptime);

		    # we dont want to brute force wikipedia
		if ($adddata->{'url'}) {
		    $data->{$key}->{'lastcheck'} = $adddata->{'time'};    
		    if ($adddata->{'url'} !~ /^(f|ht|)tp(s*):\/\//i) {
			$adddata->{'url'} = 'http://'.$adddata->{'url'};
		    }
		    $data->{$key}->{'url'} = $adddata->{'url'};
		    if ($params->{'debug'}) {
			print "\tURL: $data->{$key}->{'url'}\n";
			print "\tset lastcheck time to ".localtime($data->{$key}->{'lastcheck'})."\n";
		    }
		}

		if ($adddata->{'Ort'}) {
		    $data->{$key}->{'Ort'} = $adddata->{'Ort'};
		} 
		if ($adddata->{'Trägerschaft'}) {
		    if ($adddata->{'Trägerschaft'} =~ /staatlich/i) {
			$data->{$key}->{'Traeger'} = 'staatlich';
		    } elsif ($adddata->{'Trägerschaft'} =~ /privat/i) {
			$data->{$key}->{'Traeger'} = 'privat';
		    } elsif ($adddata->{'Trägerschaft'} =~ /konfessionell/i) {
			$data->{$key}->{'Traeger'} = 'konfessionell';
		    }
		}
		if (($params->{"maxupdate"}) && ($gotdata>$params->{"maxupdate"})) {
		    $enough = 1;
		    # again: we dont want to make a brute force on wikipedia
		    next;
		}

	    }
	if ((not $data->{$key}->{'lastcheck'}) || ($data->{$key}->{'lastcheck'} < $thiscachetime)) {
	    $pending++;
	}
	   
    }	
    print "Found: ".$cnt."\n";
    print "Pending Entries: $pending\n";
    return $data;
    
}
###############################################################################
sub GetSingleWikiHochschule {
    my $thisurl = shift;

    $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'}=0;
    my $ua = LWP::UserAgent->new( timeout => 5, keep_alive => 1 );
    $ua->env_proxy;
    $ua->ssl_opts( "timeout" => 5, "Timeout" => 5, "verify_hostname" => 0 );
    $ua->default_header('Accept-Language' => "de, en");
    $ua->agent($CONST->{"useragent"});

    my $html; 


    my $url =  $thisurl;
    print STDERR "\t\tRufe Wikiseite ab: $url\n" if ($params->{'debug'});
 	
    local $SIG{ALRM} = sub { die "timeout\n" };

    	
    		# Create a request
	
    #	my $req = HTTP::Request->new(GET => $url);
	    	# Pass request to the user agent and get a response back
	my $res;
	my $out;
	$out->{'time'} = time;

	eval {
		alarm(10);
		$res = $ua->get($url);
		if ($res->is_success) {
			# ok, continue
		} else {		
			warn "Cannot connect to $url  - Error ".$res->code."\n";
			return $out;
		}
	};
	alarm(0);
	if ($@) {
		if ($@ =~ /timeout/) {
 		        warn "request timed out";
     		} else {
         		warn "error in request: $@";
    		}
		return $out;
 	}
	my $plaincontent;	    	
	my $statuscode = $res->code;

	if ($res->is_success) {

	    if ($res->content_charset eq 'UTF-8') {
		$html = $res->decoded_content;  # or whatever
	    } else {
		$html = $res->decoded_content('UTF-8');;  # or whatever
	    }
	   
	} else {
	    warn $res->status_line;
	    return $out;
	}


	
	if ($html) {
	    print STDERR "\t\t\tExtract Tabelle mit Unidaten\n" if ($params->{'debug'});

	    my $te = HTML::TableExtract->new( keep_html => 1, attribs => { id => 'Vorlage_Infobox_Hochschule' } );
	    $te->parse($html);    
	   
	    my $ts;
	    my $row;
	    my $name;
	    my $value;
	    my $n = 1;
	    foreach $ts ($te->tables) {
		if ($ts->{'attribs'}->{'id'} eq 'Vorlage_Infobox_Hochschule') {
			foreach $row ($ts->rows) {	
			    $name = $row->[0];
			    $value = $row->[1];

			    $name =~ s/^\s*//gi;
			    $name =~ s/\s*$//gi;
			    $value =~ s/^\s*//gi;
			    $value =~ s/\s*$//gi;

			    
	#		    print STDERR "\t".$name." => ".$value."\n";

			    if ($name && $value) {

				if ($name =~ /(Studenten|Mitarbeiter|davon Professoren)/i) {
				    ($value, undef) = split(/ /,$value,2);
				    $out->{$name} = $value;
				} elsif ($name =~/website/i) {
				    if ($value =~ /href=\"([^"><]+)\"/i) {
					    $out->{'url'} = $1;
					    
				    } else {
					    $value =~s/<([^<>]+)>//gi;
					    $out->{'url'} = $value;
				    }
				    $out->{'url'} =~ s/\/$//gi;
				} else {
				    # Remove HTML
				    $value =~s/<([^<>]+)>//gi;
				    # Remove Cite-Numbers
				    $value =~ s/\[([0-9]+)\]//gi;
				    $out->{$name} = $value;
				}	    
			    }

			}
			$n++;
		}
		
	    }
	}
	return $out;


}
###############################################################################
sub ExtractHochschulen {
    my $html = shift;

    print STDERR "Extract Tabellen\n" if ($params->{'debug'});

    my $te = HTML::TableExtract->new( "keep_html" => 1);
    $te->parse($html);    
    
    my $data;
    my $ts;
    my $row;
    my $name;
    my $land;
    my $traeger;
    my $url;
    my $gruendung;
    my $studis;
    my $stand;

    foreach $ts ($te->tables) {
#	print "Table found at ", join(',', $ts->coords), ":\n";
	foreach $row ($ts->rows) {
	    $name = $row->[0];
	    $land = $row->[1];
	    $traeger= $row->[2];
	    $gruendung = $row->[4];
	    $studis = $row->[5];
	    $stand = $row->[6];
	    if ($name=~ /href=\"([^\"]+)\"/i) {
		$url = $1;
		$name =~ s/<.+?>//gi;
		if ($url =~/^\//i) {
		    $url = $CONST->{"wikibase_url"}.$url;
		}
	    }
	    $studis =~ s/<span(.+)span>//gi;
	    if ($params->{'debug'}) {
		 #  print "$name ($url)\n";
		#  print "\t $studis Studierende ($stand), Typ: $traeger, Gründung: $gruendung\n";
	    }
	    
	    $data->{$name}->{'Name'} = $name;
	    $data->{$name}->{'wikiurl'} = $url;
	    $data->{$name}->{'ZahlStudierende'} = $studis;
	    $data->{$name}->{'Traeger'} = $traeger;
	    $data->{$name}->{'Gruendung'} = $gruendung;
	    $data->{$name}->{'Stand'} = $stand;
		

	}
    }


   return $data;
}
###############################################################################
sub WriteCache {
    my $file = shift;
    my $data = shift;
    if (-r $file) {
	rename($file,"$file.old");
    }
    open(f1,">$file");
    print f1 $data;
    close f1;
}
###############################################################################
sub LoadCache {
    my $file = shift;
    my $out;
    open(f1,"<$file");
    while(<f1>) {
	$out .= $_;
    }
    close f1;
    return $out;
}
###############################################################################
sub GetWikiIndex {
   


    $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'}=0;
    my $ua = LWP::UserAgent->new( timeout => 5, keep_alive => 1 );
    $ua->env_proxy;
    $ua->ssl_opts( "timeout" => 5, "Timeout" => 5, "verify_hostname" => 0 );
    $ua->default_header('Accept-Language' => "de, en");
    $ua->agent($CONST->{"useragent"});

    my $output; 


    my $url =  $CONST->{"source_url"};
	
 	
    local $SIG{ALRM} = sub { die "timeout\n" };

    	
    		# Create a request
	
    	my $req = HTTP::Request->new(GET => $url);
	    	# Pass request to the user agent and get a response back
	my $res;

	eval {
		alarm(10);
		$res = $ua->get($url);
		if ($res->is_success) {
			# ok, continue
		} else {		
			die "Cannot connect to $url  - Error ".$res->code."\n";
		}
	};
	alarm(0);
	if ($@) {
		if ($@ =~ /timeout/) {
 		        warn "request timed out";
     		} else {
         		warn "error in request: $@";
    		 }
		return 0;
 	}
	my $plaincontent;	    	
	my $statuscode = $res->code;

	if ($res->is_success) {
	    $output = $res->decoded_content;  # or whatever
	} else {
	    die $res->status_line;
	}
	return  $output; 


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
		print "\tnocache          - Load list from web not from local cache\n";
		print "\tmaxupdate=".$maxupdate." - How many URLs to get in this session from Mediawiki\n";
		print "\tlistout=FILENAME - Prints out index with valid URLs in a file, that may be used as input file for MnoGoSearch and check-website.pl.\n";
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
