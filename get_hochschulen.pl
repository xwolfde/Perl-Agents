#!/usr/bin/perl
#
# @File get_hochschulen.pl
# @Created 09.10.2015 16:10:36
#

use strict;
use Getopt::Long;
use LWP::UserAgent;
use HTML::TableExtract;
use CheckRFC;


my $CONST = {
    "source_url"    => 	'https://de.wikipedia.org/wiki/Liste_der_Hochschulen_in_Deutschland',
    "wikibase_url"  => 'https://de.wikipedia.org',
    "cache_file" => 'Liste_der_Hochschulen_in_Deutschland.html',
    "output"	=> 'Liste_der_Hochschulen_in_Deutschland.tab',
    "useragent"	=> 'Mozilla/5.0',
    "cachetime_single"	=> 60*60*24*7*30,
    "max_update"    => 10,
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

exit;


###############################################################################
# Subs
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
    my $file = $CONST->{'output'};  
    

    if (-r $file) {
	my $key;
	my $subkey;
	my @content;
	my $i;
	my ($name, $value);

	open(f1,"<$file");
	while(<f1>) {
	    $_ =~ s/\s*$//gi;
	    @content = split(/\t/,$_);
	    $key = $content[0];
	    for ($i=1; $i<=$#content; $i++) {
		($name, $value) = split(/: /,$content[$i],2);
		$data->{$key}->{$name} = $value;
	    }
	}
	close f1;
	return $data;
    }  else {
	print STDERR "Es wurden noch keine Daten gespeichert in $file\n" if ($params->{'debug'});
	return;
    }


}
###############################################################################
sub WriteHochschulData {
    my $data = shift;
    my $file = $CONST->{'output'};
    
    if (-r $file) {
	rename($file,"$file.old");
    }
    my $key;
    my $subkey;

    open(f1,">$file");
	foreach $key (sort {$a <=> $b} keys %{$data}) {
	    print f1 $key;
	    print f1 "\t";
	    foreach $subkey (keys %{$data->{$key}}) {
		print f1 $subkey.": ".$data->{$key}->{$subkey}."\t";  
	    }
	    print f1 "\n";
	}
    close f1;

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

    foreach $key (sort {$a <=> $b} keys %{$data}) {
	if ($params->{'debug'}) {
	    print STDERR $key."\n";
	    print STDERR "\tWikiurl: ".$data->{$key}->{'wikiurl'}."\n";
	}
	    $cnt++;

	    if (((not $data->{$key}->{'lastcheck'}) || ($data->{$key}->{'lastcheck'} < $thiscachetime)) && (not $enough)) {
		if ($params->{'debug'}) {
			print STDERR "\tUpdate data\n";
		}
		$gotdata++;
		$adddata = GetSingleWikiHochschule($data->{$key}->{'wikiurl'});
		$sleeptime = int(rand(4))+1;
		sleep($sleeptime);
		    # we dont want to brute force wikipedia
		if ($adddata->{'url'}) {
		    $data->{$key}->{'lastcheck'} = $adddata->{'time'};    
		    if ($adddata->{'url'} !~ /^(f|ht|)tp(s*):\/\//i) {
			$adddata->{'url'} = 'http://'.$adddata->{'url'};
		    }
		    $data->{$key}->{'url'} = $adddata->{'url'};
		    print "\tURL: $data->{$key}->{'url'}\n";
		}

		if (($CONST->{"max_update"}) && ($gotdata>$CONST->{"max_update"})) {
		    $enough = 1;
		    # again: we dont want to make a brute force on wikipedia
		}

	    }
	   
    }	
    print "gefundene Einträge: ".$cnt."\n";
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
	
    	my $req = HTTP::Request->new(GET => $url);
	    	# Pass request to the user agent and get a response back
	my $res;

	$res->{'time'} = time;

	eval {
		alarm(10);
		$res = $ua->get($url);
		if ($res->is_success) {
			# ok, continue
		} else {		
			warn "Cannot connect to $url  - Error ".$res->code."\n";
			return $res;
		}
	};
	alarm(0);
	if ($@) {
		if ($@ =~ /timeout/) {
 		        warn "request timed out";
     		} else {
         		warn "error in request: $@";
    		 }
		return $res;
 	}
	my $plaincontent;	    	
	my $statuscode = $res->code;

	if ($res->is_success) {
	    $html = $res->decoded_content;  # or whatever
	} else {
	    die $res->status_line;
	}


	
	if ($html) {
	    print STDERR "\t\tExtract Tabelle mit Unidaten\n" if ($params->{'debug'});

	    my $te = HTML::TableExtract->new();
	    $te->parse($html);    
	   
	    my $ts;
	    my $row;

	    foreach $ts ($te->tables) {
		foreach $row ($ts->rows) {		    
		    if ($row->[0] =~/website/i) {
			$res->{'url'} = $row->[1];
		    }
		}
	    }
	}
	return $res;


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

    my $options = GetOptions(
			    "help|h|?"		=> \$help,
			    "debug" => \$debug,
			    "nocache" => \$usecache,
			);
					
	
	if ($help) {
		print "$0 [Options]\n";
		print "Options could be:\n";
		print "\tdebug -  Debugmode on\n";  
		print "\tnocache - Load list from web not from local cache\n";
		
		exit;
	}

    $result->{'debug'} = $debug;	    
    $result->{'nocache'} = $usecache;	

    return $result;
}


##############################################################################
