#/usr/bin/perl

use strict;

use Catmandu::FedoraCommons;

my %PARAMS = (
	baseurl => 'http://localhost:8080/fedora',
	usename => 'fedoraAdmin',
	password => 'hce39alp'
);

my $PID = 'RDC:1';
my $FILE = '/home/mike/workspace/RDC Data Capture/src/t/Fixtures/Capture/20130404_P1_E1_UTS Demo Microscope_Testable_JoeTest/Paramecium.jpg';

my $fc = Catmandu::FedoraCommons->new(%PARAMS) || do {
	die("Can't create Catmandu::FedoraCommons instance");
};


$fc->addDatastream(
	pid => $PID,
	file => $FILE,
	dsID => 'testDS1',
	label => 'Paramecium'
);