#!/usr/bin/perl

use strict;

use Apache::Solr;

my $SERVER = 'http://test-mint.research.uts.edu.au/solr';
my $CORE = 'fascinator';


my $solr = Apache::Solr->new(
    server => $SERVER,
    core => $CORE
) || do {
	error("Couldn't connect to ReDBox/Solr");
	die;
};

