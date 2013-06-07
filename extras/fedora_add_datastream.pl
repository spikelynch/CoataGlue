#!/usr/bin/perl

use strict;

use Catmandu::FedoraCommons;
use Data::Dumper;

my %PARAMS = (
	baseurl => 'http://localhost:8080/fedora',
	usename => 'fedoraAdmin',
	password => 'hce39alp'
);



my $PID = 'RDC:1';
my $FILE = '/home/mike/workspace/RDC Data Capture/src/t/Fixtures/Capture/20130404_P1_E1/200_Noctiluca_scintillans_unica.jpg';
my $URL = 'http://localhost:8080/repository/local/RDC:115/Paramecium.jpg';
my $REAL_URL = 'https://www.dropbox.com/s/3yq83vjaozg16p9/Terra.tif';

my $fc = Catmandu::FedoraCommons->new(
	$PARAMS{baseurl}, $PARAMS{usename}, $PARAMS{password}
) || do {
	die("Can't create Catmandu::FedoraCommons instance");
};


add_datastream(
	'pid' => 'RDC:45',
 	'file' => $FILE,
 	'dsLabel' => 'Noctiluca',
 	'mimeType' => 'image/jpeg',
    'dsID' => "Datastream1"
);

add_datastream(
	'pid' => 'RDC:45',
 	'url' => $URL,
 	'dsLabel' => 'Paramecium',
 	'mimeType' => 'image/jpeg',
    'dsID' => "Datastream2"
);

add_datastream(
	'pid' => 'RDC:45',
 	'url' => $REAL_URL,
 	'dsLabel' => 'FSVO',
 	'mimeType' => 'image/tiff',
    'dsID' => "Datastream3"
);

sub add_datastream {
	my %params = @_;

	my $result = $fc->addDatastream(%params);
 
	if( $result->is_ok ) {
		print "Request worked.\n";
	} else {
		print $result->error . "\n";
		print "Result: $result\n";
		print Dumper({result => $result}) . "\n";
	}
}

