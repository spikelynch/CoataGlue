#!/usr/bin/perl

use strict;
use Data::Dumper;

use Apache::Solr;

my $SOLR = 'https://redbox.research.uts.edu.au/redbox-solr';
my $CORE = 'fascinator';

my $ID = '69e60340b7918f8e3222eac87e5e5b50';
my $RDCURL = 'http\://data.research.uts.edu.au/dataset/au.edu.uts780';
my $SEARCHFIELD = 'bibo\:DataLocation.1.dc\:location';

print "Trying Apache::Solr\n";

my $solr = Apache::Solr->new(
    server => $SOLR,
    core => $CORE,
    ) || die;

# "id:$ID"

#do_search('id', $ID);

do_search($SEARCHFIELD, $RDCURL);



sub do_search {
    my ( $field, $search ) = @_;

    my $q = join(':', $field, $search);
    print "Searching $q\n";
    
    my $results = $solr->select(q => $q);
    
    my $n = $results->nrSelected;
    
    print "Got $n results.\n";
    
    my $doc = $results->selected(0);
    
    if( $doc ) {
        
        print "\n\nTitle: " . $doc->content('dc_title') . "\n";
        print "Access: " . $doc->content('dc_accessRights') . "\n";
        
        my @names = $doc->fieldNames();
        print join("\n", map { $_ . ":" . $doc->content($_) } @names );
        print "\n";
        
    } else {
        print "Document not found in Solr.\n";
    }
}
