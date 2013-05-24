#!/usr/bin/perl

use strict;
use Data::Dumper;

use FedoraCommons::APIA version => 3.6;

my $FEDORA = {
	host => 'localhost',
	port => '8080',
	usr => 'fedoraAdmin',
	pwd => 'hce39alp'
};

my $ID = 'RDC.1';



my $fc = FedoraCommons::APIA->new(%$FEDORA) || die(
	"Couldn't create FedoraCommons::APIA instance"
);


my $results;

my $status = $fc->findObjects(
	resultFields => [],
	maxResults => 10,
	fldsrchProperty => 'PID',
	fldsrchValue => $ID,
	fldsrchOperator => '=',
	searchRes_ref => \$results
);

print "Search status = $status\n";

if( $status ) {
	print "Error: " . $fc->error() . "\n";
} else {
	print Dumper({results => $results});
}