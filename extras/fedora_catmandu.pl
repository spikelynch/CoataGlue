#!/usr/bin/perl

use strict;
use Data::Dumper;

use Catmandu::FedoraCommons;

my $FEDORA = {
	url => 'http://localhost:8080/fedora',
	user => 'fedoraAdmin',
	password => 'hce39alp'
};

my $ID = 'RDC:1';


my $fc = Catmandu::FedoraCommons->new(
	$FEDORA->{url}, $FEDORA->{user}, $FEDORA->{password}
) || die("Couldn't connect to Fedora");

# Note: searching doesn't work?

my $result = $fc->getObjectProfile(pid => $ID);

if( $result->is_ok ) {
	my $obj = $result->parse_content;
	print "Object profile $ID\n";
	print Dumper( {obj => $obj} ) ."\n\n";
}

$result = $fc->listDatastreams(pid => $ID);

if( $result->is_ok ) {
	my $dss = $result->parse_content;
	print "List of datastreams\n";
	print Dumper( { ds => $dss } ) . "\n\n";
	for my $ds ( @{$dss->{datastream}} ) {
		my $dsid = $ds->{dsid};
		print "Datastream: $dsid\n";
		my $data = '';
		$fc->getDatastreamDissemination(
			pid => $ID,
			dsID => $dsid,
			callback => sub {
				my ( $d, $response, $protocol ) = @_;
				$data .= $d;
				print Dumper({response => $response}). "\n";
			}
		);
		#print "Data:\n$data\n\n";
	}
} else {
	print "Datastream lookup failed: " . $result->error . "\n";
}

