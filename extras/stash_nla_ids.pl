#!/usr/bin/perl

# Does a solr lookup for people with NLA IDs and saves them

use strict;

use Apache::Solr;
use Data::Dumper;

my $SERVER = 'https://mint.research.uts.edu.au/solr';
my $CORE = 'fascinator';

my $FIELD = 'dc_identifier';

my $ID = 'http://hdl.handle.net/11057/idaac499d9';

my $handles = read_handles('./People_NLAIDs.csv');

for my $hdl ( @$handles ) {

    my $results = mint_lookup('ID', $hdl);

    if( $results ) {

        my $n = $results->nrSelected;

        for my $i ( 0 .. $n - 1 ) {
            my $doc = $results->selected($i);
            my $nla = $doc->content('nlaId');
            my $handle = $doc->content('ID');
            my $family_name = $doc->content('Family_Name');
            my $given_name = $doc->content('Given_Name');

            print "$handle,$family_name,given_name,$nla\n";
        }
    } else {
        print "$hdl,noresults\n";
    }
}



sub read_handles {
    my ( $file ) = @_;

    my $handles = [];
    
    open(CSV, "<$file") || die($!);

    while ( my $line =<CSV> ) {
        if( $line =~ /^(http[^,]*),/ ) {
            push @$handles, $1;
        }
    }

    close CSV;

    return $handles
}





sub mint_lookup {
    my ( $field, $value ) = @_;

	my $solr = Apache::Solr->new(
    	server => $SERVER,
    	core => $CORE
	) || do {
		error("Couldn't connect to ReDBox/Solr");
		die;
	};

	$field =~ s/:/\\:/g;
	$value =~ s/:/\\:/g;


	my $query = join(':', $field, $value);

	my $results = $solr->select(q => $query);
	
	$results or die $results->errors;

	warn "Got results: $results\n";
	
	my $n = $results->nrSelected;
	
	if( !$n ) {
		warn "No results.\n";
	}

	warn "Got $n results\n";

    return $results;
}
