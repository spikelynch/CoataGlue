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
my $FILE = '/home/mike/workspace/RDC Data Capture/src/t/Fixtures/Capture/20130404_P1_E1_UTS Demo Microscope_Testable_JoeTest/Paramecium.jpg';

my $fc = Catmandu::FedoraCommons->new(
	$PARAMS{baseurl}, $PARAMS{usename}, $PARAMS{password}
) || do {
	die("Can't create Catmandu::FedoraCommons instance");
};

my $result = $fc->addDatastream(
	'pid' => 'RDC:45',
 	'file' => '/home/mike/workspace/RDC Data Capture/src/t/Test/Capture/20130404_P1_E1_UTS Demo Microscope_Testable_JoeTest/220px-Noctiluca_scintillans_unica.jpg',
    'dsID' => "Datastream1"
);
 
#
#	pid => $PID,
#	dsID => 'Paramecium',
#	file => $FILE,
#	dsLabel => 'Paramecium wiggedy',
#	mimeType => 'image/jpeg'
#);

if( $result->is_ok ) {
	print Dumper({result => $result->parse_content}) . "\n";
} else {
	print $result->error . "\n";
} 