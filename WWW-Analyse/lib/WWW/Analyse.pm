package WWW::Analyse;

use 5.008008;
use LWP::UserAgent;
use HTML::Parser;
use Encode      qw( decode encode );
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';

my $matchgenlist = {
    'Powered by Visual Composer - drag and drop page builder for WordPress' => 'WordPress',
    'Total WordPress Theme 3.5.2'   => 'WordPress',
    'Rails Connector for Infopark CMS Fiona by Infopark AG (www.infopark.de)'	=> 'Infopark CMS Fiona',
    'UniMR CMS (Plone - http://plone.org)'  => 'Plone',
};

##############################################################################
sub get_pagetitle {
    my $obj = shift;
    if (not $obj) {
	return;
    }
    my $title = $obj->getheader("Title");
    if (ref($title) eq 'ARRAY') {
	my $i;
	my @tl = @{$title};
	my $res;
	for ($i=0;$i<=$#tl;$i++) {
	   # $res .= decode( "utf8", $tl[$i])." | ";
	    $res .= $tl[$i]." | "; 
	}
	$res =~ s/ \| $//g;
	return $res;
    } else {
	return $title; # decode( "utf8", $title);
    }

}
##############################################################################
sub listtracker {
    my $obj = shift;
    if (not $obj) {
	return;
    }
    my $found = $obj->findtracker();
    if ($found) {
	return $obj->{'body'}->{'data'}->{'tracker'};
    }
    return; 
}
##############################################################################
sub findtracker {
	my $obj = shift;
	if (not $obj) {
		return;
	}
	 if (not $obj->{'parserstatus'}) {
                $obj->parser();
        }
        my $foundtracker = 0;
        $obj->{'body'}->{'data'}->{'tracker'} = ();
	
	my $content = $obj->getcontent();
	if (($content =~ /_uacct/i) || ($content =~ /_gat\._getTracker\(/i)) {
		# Suche nach Google Analytics
		$obj->{'body'}->{'data'}->{'tracker'}->{'Google-Analytics'} =1;
		$foundtracker =1;
	}
	if ($content =~ /piwik\.php/i) {
		$obj->{'body'}->{'data'}->{'tracker'}->{'Piwik'} =1;
		$foundtracker =1;
	} 	
	if ($content =~ /sitemeter\.com\/meter\.asp/i) {
		$obj->{'body'}->{'data'}->{'tracker'}->{'Sitemeter'} =1;
		$foundtracker =1;
	} 	
	if ($content =~ /statse\.webtrendslive\.com\/dc/i) {
		$obj->{'body'}->{'data'}->{'tracker'}->{'Webtrendslive'} =1;
		$foundtracker =1;
	} 	
	if ($content =~ /prof\.estat\.com\/m/i) {
		$obj->{'body'}->{'data'}->{'tracker'}->{'eStat'} =1;
		$foundtracker =1;
	} 	
	if ($content =~ /ivwbox\.de\/cgi\-bin\/ivw/i) {
		$obj->{'body'}->{'data'}->{'tracker'}->{'IVW'} =1;
		$foundtracker =1;
	} 	
	if ($content =~ /www\.etracker\.de/i) {
		$obj->{'body'}->{'data'}->{'tracker'}->{'eTracker'} =1;
		$foundtracker =1;
	} 		
	return  $foundtracker;
}
##############################################################################
sub findgenerator {
	my $obj = shift;
        if (not $obj->status){
                return;
        }
	if (not $obj->{'parserstatus'}) {
                $obj->parser();
        }
	my $generator = $obj->getheader("x-meta-generator");
	if (ref($generator) eq 'ARRAY') {
		my $newgen;
		$newgen = $generator->[0];
		$generator = $newgen;
	}


	if ($generator) {
		my $resgen;	
		if ($generator =~ /^Web-Baukasten der/i) {
			$resgen = "RRZE Webbaukasten";
		} elsif ($generator =~ /^Blogdienst der FAU/i) {
			$resgen = "WordPress";
			if ($generator =~ /([0-9\.]+)\s*$/i) {
			   $resgen  .= " ".$1;
			}
		} elsif ($matchgenlist->{$generator}) {
		    $resgen = $matchgenlist->{$generator};
		} else {
			$resgen = $generator;
		}

		
		return $resgen;
	}
	my $content = $obj->getcontent();
	if ($content =~ /\/wp\-content\/themes\//i) {
		$generator = "WordPress";
		if ($content =~ /\/wp\-includes\/css\/dashicons\.min\.css\?ver=([0-9\.]+)/i) {	
			$generator .= " ".$1;
		}
	} elsif ($content =~ /\/typo3temp\//i) {
		$generator = "TYPO3";
	} elsif ($obj->getheader("x-meta-application-name")) {
		 $generator = $obj->getheader("x-meta-application-name");
	} elsif ($content =~/InstanceBeginEditable/i) {
		$generator = "Dreamweaver";
	} elsif ($content =~ /\/modules\/output_filter/i) {
		$generator = "WebsiteBaker";
	} elsif ($content =~ /This website is powered by Neos/i) {
		$generator = "Neos";
	} elsif ($content =~ /jQuery\.extend\(Drupal\.settings/i) {
		$generator = "Drupal";
	} elsif ($content =~ /Drupal.extend\(/i) {
		$generator = "Drupal";
	} elsif ($content =~/\/wGlobal\/layout/i) {
	    $generator = "Weblication Content Management Server";
	} elsif ($content =~ /typo3temp/i) {
		$generator = "TYPO3";
	} elsif ($content =~ /default\.aspx/i) {
		$generator = "Microsoft SharePoint";

	} elsif ($content =~ /powered by TYPO3/i) {
		$generator = "TYPO3";
	}
	return $generator;
}
##############################################################################
sub normalize_generator {
    my $obj = shift;
    if (not $obj) {
		return;
	}
    my $gen = shift;

    my $name;
    my $version;
    my $result;

    if ($gen =~ /^TYPO3/i) {
	$name = "TYPO3";
	if ($gen =~ /^TYPO3\s+([0-9\.]+)/i) {
	    $version = $1;
	} 
    } elsif ($gen =~ /^WordPress/i) {
	$name = "WordPress";
	if ($gen =~ /^WordPress\s+([0-9\.]+)/i) {
	    $version = $1;
	} 
    } elsif ($gen =~ /^Plone/i) {
	$name = "Plone";
	
    } elsif ($gen =~ /^Contao Open/i) {
	$name = "Contao";
    } elsif ($gen =~ /^Drupal/i) {
	$name = "Drupal";
	if ($gen =~ /^Drupal\s+([0-9\.]+)/i) {
	    $version = $1;
	} 
    } elsif ($gen =~ /^ZMS/i) {
	$name = "ZMS";
    } elsif ($gen =~ /^Imperia/i) {
	$name = "Imperia";
	if ($gen =~ /^Imperia\s+([0-9\.]+)/i) {
	    $version = $1;
	} 
    } elsif ($gen =~ /^Infopark CMS Fiona/i) {
	$name = "Infopark CMS Fiona";
	if ($gen =~ /^Infopark CMS Fiona;\s+([0-9\.]+)/i) {
	    $version = $1;
	} 
    } elsif ($gen =~ /^Rails Connector for Infopark CMS Fiona/i) {
	$name = "Infopark CMS Fiona";
	if ($gen =~ /Version ([0-9\.]+)/i) {
	    $version = $1;
	} 
    } elsif ($gen =~ /^Cabacos CMS/i) {
	$name = "Cabacos CMS";
	if ($gen =~ /^Cabacos CMS\s+\(Version ([0-9\.]+)\)/i) {
	    $version = $1;
	} 
    } else {
	return $gen;
    }
    
    $result = $name;
    if ($version) {
	$result .= ';'.$version;
    }
    
    return $result;
}
##############################################################################
sub webbaukasten {
	my $obj = shift;
	if (not $obj->status){
		return;	
	}
	if (not $obj->{'parserstatus'}) {
		$obj->parser();
	}
	
	# Webbaukasten ist es dann,
	#  wenn im HEAD der Meta-Tag Generator den Inhalt
	#    Vorlagenkatalog   
	#    Web-Baukasten
	# 
	#  oder
	#   im BODY die Bereiche
	#      <div id="content">, <div id="kopf">, <div id="footer">
	#      <div id="seite"> 
	#      existieren
	
	my $generator = $obj->findgenerator(); # $obj->getheader("x-meta-generator");
	$obj->{'body'}->{'data'}->{'webbaukasten'} = "";
	
	if (($generator) && (($generator =~ /Vorlagenkatalog/i) || ($generator =~ /Web\-Baukasten/i) || ($generator =~ /Webbaukasten/i))) {
		if ($generator =~ /\((.*)\)/i) {
			$obj->{'body'}->{'data'}->{'webbaukasten'} = $1;
		} else {
			$obj->{'body'}->{'data'}->{'webbaukasten'} = "1";			
		}
	}
	my $content = $obj->getcontent();
	if (not $obj->{'body'}->{'data'}->{'webbaukasten'}) {			
		if (($content =~ /<div id="seite"/i) 
		&& ($content =~ /<div id="kopf">/i)
		&& ($content =~ /<div id="content">/i)		
		&& ($content =~ /<div id="footer">/i)) {
			$obj->{'body'}->{'data'}->{'webbaukasten'} = "1";
		}
	}
	
	if ($obj->{'body'}->{'data'}->{'webbaukasten'} eq "1") {
		# Alte Version, vor 9.7.2009  oder Versionen die keinen metatag fuehren
		# versuche Version zu ermitteln.
		if ($content =~ /\/css\/fau\-2016\/layout\.css/i) {
                        $obj->{'body'}->{'data'}->{'webbaukasten'} = "FAU-Design 2016";
                } elsif ($content =~ /\/patches\/patch.css" rel="stylesheet" type="text\/css" \/>/i) {
			$obj->{'body'}->{'data'}->{'webbaukasten'} = "07/2011";
		} elsif ($content =~ /<meta http\-equiv="Content\-Type"\s+content="text\/html;\s+charset=iso\-8859\-1"/i) {
			$obj->{'body'}->{'data'}->{'webbaukasten'} = "09/2006 bis 10/2008";
		} elsif ($content =~ /<meta http\-equiv="Content\-Type"\s+content="text\/html;\s+charset=utf\-8"/i) { 
			$obj->{'body'}->{'data'}->{'webbaukasten'} = "10/2008 bis 06/2009";
		} elsif ($content =~ /\/wp\-content\/themes\/WKE2014/i) {
			$obj->{'body'}->{'data'}->{'webbaukasten'} = "Wordpress Theme WKE2014";
		} else {
			$obj->{'body'}->{'data'}->{'webbaukasten'} = "09/2006 bis 10/2008";
		}					
	}
	
	# versuche relaunch-Datum anhand des datums der Datei vkdaten/vorlagen.conf zu ermitteln
	
	my $vkconffile = $obj->url();
	$vkconffile .= "/vkdaten/vorlagen.conf";
	my $vkinfo = $obj->getwebfileinfo($vkconffile);
	if (($vkinfo) && ($vkinfo->{'last-modified'})) {
		$obj->{'body'}->{'data'}->{'webbaukasten_relauch'} = $vkinfo->{'last-modified'};
		
	}
#	use Data::Dumper;
#	print Dumper($vkinfo);
	
	
	return $obj->{'body'}->{'data'}->{'webbaukasten'};	
}
##############################################################################
sub getwebfileinfo {
	my $obj = shift;
	my $url = shift;
	
	my $ua = LWP::UserAgent->new;
    	$ua->agent($obj->useragent());
    		# Create a request
    	my $req = HTTP::Request->new(GET => $url);
	    	# Pass request to the user agent and get a response back
    	my $res = $ua->request($req);
	    	# Check the outcome of the response
	my $plaincontent;	    	
	my $statuscode = $res->code;
	
    	if ($statuscode<400) {
		return $res->{'_headers'};
        } else {
  	
        	return; 	        
        }
}
##############################################################################
sub get {
	my $obj = shift;
	my $url = $obj->url(shift);
	
 	$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'}=0;
	local $SIG{ALRM} = sub { die "timeout\n" };

    	my $ua = LWP::UserAgent->new( timeout => 5, keep_alive => 1 );
	$ua->ssl_opts( "timeout" => 5, "Timeout" => 5, "verify_hostname" => 0 );
    	$ua->agent($obj->useragent());
    		# Create a request
	$ua->default_header(
	    'Accept-Language' => 'de,en-US;q=0.7,en;q=0.3',
	    'Accept-Charset' => 'utf-8',
	    'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*'
	);


#    	my $req = HTTP::Request->new(GET => $url);
	    	# Pass request to the user agent and get a response back
	my $res;

	eval {
		alarm(10);
		$res = $ua->get($url);
		if ($res->is_success) {
			# ok, continue
		} else {		
			my $statuscode = $res->code;
			$obj->statuscode($statuscode);
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
		 $obj->status(0);
		
		return 0;
 	}
	my $plaincontent;	    	
	my $statuscode = $res->code;
	$obj->{'last-modified'} = $res->header('last-modified') || $res->{'_headers'}->{'last-modified'};
	$obj->statuscode($statuscode);
    	if ($statuscode<400) {
      		$obj->response($res);
      		$obj->status(1);
      		return 1;
        } else {
        	$obj->status(0);       	
        	return 0; 	        
        }
        
}
##############################################################################
sub getdocumentimages {
	my $obj = shift;
	if (not $obj->status){
		return;	
	}
	if (not $obj->{'parserstatus'}) {
		$obj->parser();
	}
	return $obj->{'body'}->{'data'}->{'images'};	
}
##############################################################################
sub getdocumentlinks {
	my $obj = shift;
	if (not $obj->status){
		return;	
	}
	if (not $obj->{'parserstatus'}) {
		$obj->parser();
	}
	return $obj->{'body'}->{'data'}->{'link'};	
}
##############################################################################
sub parser {
	my $obj = shift;
	our %inside;
	our $data;
	our $thislink;
	our $thisimage;
	
	$obj->{'parser'} =  HTML::Parser->new(api_version   => 3,
				handlers    => [
						start => [\&tag, "tagname, tokenpos, text, attr, line"],
						end   => [\&endtag, "tagname, text"],
						text  => [\&text, "text, line"],
						process     => [\&text, "text"],

					],
				marked_sections => 0,	 
		
			);

	$obj->{'parser'}->eof;	     			
	my $content = $obj->getcontent;	
	$obj->{'parser'}->parse($content);
	$obj->{'body'}->{'data'} = $data;
	$obj->{'parserstatus'} = 1;
	return;
	
	sub tag {		
		my $tag = shift;
		my $pos = shift;
		my $text = shift;
		my $attribute = shift;
		my $line = shift;
		$inside{$tag} += 1;
		
		
		if ($tag eq "a") {						
			$thislink = $attribute;		
			$thislink->{'line'} = $line;																		
	        }
	        if ($tag eq "img") {
	              $thisimage = $attribute;         
	              $thisimage->{'line'} = $line;		    	
	              push(@{$data->{'images'}},$thisimage);
	        }
	}
		
	###########################################
	sub endtag {
		
		my $tag = shift;
		$inside{$tag} -= 1;
		if ($tag eq "a") {
			push(@{$data->{'link'}}, $thislink);
			$thislink = ();
		}
	}
	####################
	sub text {
		
            	my $thistext = shift;
            	my $line = shift;
          
                       
		if (($inside{script}) || ($inside{style})) {
			  return;
		}
		if ($inside{'h1'}) {
			push(@{$data->{'tag'}->{'h1'}},$thistext);			
		} 			
		if ($inside{'h2'}) {
			push(@{$data->{'tag'}->{'h2'}},$thistext);		
		} 
		if ($inside{'a'}) {
			$thislink->{'text'} = $thistext;
		} 				
					
	}	
}
##############################################################################
sub getheaderlinks {
	my $obj = shift;
	
	if (not $obj->status){
		return;	
	}
	# Dies ist leider schlecht in HTTP:HEADERS, so dass ich hier
	# direkt drauf zugreif
	my $ref = $obj->response;
	my @liste;
	my $out = ref($ref->{'_headers'}->{'link'});
	if ((ref($ref->{'_headers'}->{'link'}) eq 'ARRAY') || (ref($ref->{'_headers'}->{'link'}) eq 'HASH')) {
		@liste = @{$ref->{'_headers'}->{'link'}};
	} elsif ($ref->{'_headers'}->{'link'}) {
		push(@liste,$ref->{'_headers'}->{'link'});
	}
	
	my $i;
	my $this;
	my $url;
	my $type;
	my $rel;
	my $title;
	my $media;
	my $result;
	my $num;
	for ($i=0; $i<=$#liste; $i++) {
		$num = $i+1;
		$this = $liste[$i];
		next if (not $this);
		$url = "";
		$rel = "";
		$type= "";
		$title = "";
		$media = "";
		if ($this =~ /^<([^<>]+)>/i) {
			$url = $1;
		}
		if ($this =~ / media="([^"']+)"/i) {
			$media = $1;
		}
		if ($this =~ / rel="([^"']+)"/i) {
			$rel = $1;
		}
		if ($this =~ / title="([^"']+)"/i) {
			$title = $1;
		}		
		if ($this =~ / type="([^"']+)"/i) {
			$type = $1;
		}		
		if ($url) {
			$result->{$num}->{'url'} = $url;
			$result->{$num}->{'type'} = $type if ($type);
			$result->{$num}->{'title'} = $title if ($title);
			$result->{$num}->{'rel'} = $rel if ($rel);
			$result->{$num}->{'media'} = $media  if ($media);			
		}
	}
	return $result;	
}
##############################################################################
sub getheader {
	my $obj = shift;
	my $var = shift;
	if (not $obj->status){
		return;	
	}
	if (not $var) {
		return $obj->response->{'_headers'};		
	} else {
		return 	$obj->response->{'_headers'}->{$var} if ($obj->response->{'_headers'}->{$var});
		
		# Checke noch nach ob Case-Insensitive wirkt..
		my $key;
		foreach $key (keys %{$obj->response->{'_headers'}}) {
			if (($key) && (lc($key) eq lc($var))) {
				$var = $key;
				last;
			}		
		}
		return $obj->response->{'_headers'}->{$var};
		
	}
}
##############################################################################
sub getcontent {
	my $self = shift;
	if (not $self->status) {
		return;	
	}
	return $self->response->decoded_content(default_charset => 'UTF-8');	
}
##############################################################################
sub statuscode {
   my $obj = shift;
   my $newvalue = shift;
   if (defined($newvalue)) { 
   	$obj->{'statuscode'} = $newvalue; 
   }
   return $obj->{'statuscode'};
}
##############################################################################
sub response {
   my $obj = shift;
   my $newvalue = shift;
   if (defined($newvalue)) { 
   	$obj->{'response'} = $newvalue; 
   }
   return $obj->{'response'};
}
##############################################################################
sub status {
   my $obj = shift;
   my $newvalue = shift;
   if (defined($newvalue)) { 
   	$obj->{'status'} = $newvalue; 
   }
   return $obj->{'status'};
}
##############################################################################
sub useragent {
   my $obj = shift;
   my $newvalue = shift;
   if (defined($newvalue)) { 
   	$obj->{'connect'}->{'useragent'} = $newvalue; 
   }
   return $obj->{'connect'}->{'useragent'};
}
##############################################################################
sub url {
   my $self = shift;
   my $newvalue = shift;
   if (defined($newvalue)) { 
   	$self->{'url'} = $newvalue; 
   }
   return $self->{'url'};
}
##############################################################################
sub new {
	my $self = {};
	bless $self;
 	$self->_initialize();
  	return $self;
}
##############################################################################
sub _initialize {
  	my $obj = shift;
  
  	# Set defaults
  	$obj->{'url'} = '';
  	$obj->{'head'} = ();
#  	$obj->{'data'} = ();
  	$obj->{'body'} = ();
  	$obj->{'connect'}->{'useragent'} = "WWW::Analyse ($VERSION)";
  	$obj->{'response'} = ();
  	$obj->{'status'} = 0;
  	$obj->{'statuscode'} = 0;
  	return 1;
}  
##############################################################################
1;
__END__

=head1 NAME

WWW::Analyse - Perl extension for testing websites for a set of tests

=head1 SYNOPSIS

  use WWW::Analyse;
 
 

=head1 DESCRIPTION


Not ready yet


=head1 AUTHOR

Wolfgang Wiese, E<lt>xwolf@xwolf.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2015 by Wolfgang Wiese

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
