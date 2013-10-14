#!/usr/bin/perl

use strict;

use Apache::Solr;
use Data::Dumper;

my $SERVER = 'https://mint.research.uts.edu.au/solr';
my $CORE = 'fascinator';

my $FIELD = 'dc_identifier';

my $ID = 'http://hdl.handle.net/11057/59416f87';


mint_lookup();




sub mint_lookup {

	my $solr = Apache::Solr->new(
    	server => $SERVER,
    	core => $CORE
	) || do {
		error("Couldn't connect to ReDBox/Solr");
		die;
	};

	$FIELD =~ s/:/\\:/g;
	$ID =~ s/:/\\:/g;


	my $query = join(':', $FIELD, $ID);

	print "Solr query: $query\n";
    
	my $results = $solr->select(q => $query);
	
	$results or die $results->errors;

	print "Got results: $results\n";
	
	print "Results is a " . ref($results) . "\n";
		
	my $n = $results->nrSelected;
	
	if( !$n ) {
		print "No results.\n";
	}

	print "Got $n results\n";

	for my $i ( 0 .. $n - 1 ) {
		my $doc = $results->selected($i);
        
        print "Document $i\n";

        for my $field ( $doc->fieldNames ) {
            print "$field: " . $doc->content($field) . "\n";
        }

        print "\n---\n\n";
	
	}	
}
