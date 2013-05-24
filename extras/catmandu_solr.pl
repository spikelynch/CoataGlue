#!/usr/bin/perl

use strict;
use Data::Dumper;

use Apache::Solr;

my $SOLR = 'http://localhost:9000/solr';
my $CORE = 'fascinator';

my $ID = 'bb827f4ad530e1ef5035e0b6d1b4d046';
my $RDCURL = 'http\://research.uts.edu.au/datasets/id\:RC.234';

my $SEARCHFIELD = 'bibo\:Website.1.dc\:identifier';

print "Trying Apache::Solr\n";

my $solr = Apache::Solr->new(
    server => $SOLR,
    core => $CORE,
);

# "id:$ID"

my $q = join(':', $SEARCHFIELD, $RDCURL);
print "Searching $q\n";

my $results = $solr->select(q => $q);

my $n = $results->nrSelected;

print "Got $n results.";

my $doc = $results->selected(0);

if( $doc ) {

    print "Title: " . $doc->content('dc_title') . "\n";
    print "Access: " . $doc->content('dc_accessRights') . "\n";

    my @names = $doc->fieldNames();
    print join("\n", map { $_ . ":" . $doc->content($_) } @names );
    print "\n";
    
} else {
    print "Document not found in Solr.\n";
}
