#!/usr/bin/perl

=head1 NAME

103_datastream_ids.t

=head1 DESCRIPTION

Tests the CoataGlue::Dataset's datastreams method's ability to
correct messy datastream ids that aren't allowed by Fedora, yet still
keep them unique.  And preserve their extensions so that we can
assign the correct MIME type

=cut


use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";


use Test::More;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $DATASET_RE = 'P1_E1';

my %BAD_IDS = (
	'000' => 'D00',
	'200x900_photo.jpg' => 'D00x900_photo.jpg',
	'Warning:contains:colons' => 'Warning_contains_colons',
	'Has spaces?' => 'Has_spaces_',
	'Has spaces also.txt' => 'Has_spaces_also.txt',
	'this name is full of spaces and is also quite long. The algorithm needs to truncate it and replace the spaces with underscores.png' =>
        'needs_to_truncate_it_and_replace_the_spaces_with_underscores.png',
    'A name which                                                  will certainly break now that I have changed the algorithm.gif' => 'D_will_certainly_break_now_that_I_have_changed_the_algorithm.gif'
);


my $BASE = "riverrun, past Eve and Adam's, from swerve of shore to bend of bay, brings us by a commodius vicus of recirculation back to Howth Castle and Environs.";

my @EXTENSIONS = ('', '.txt', '.png', '.tiff', '.csv' );
my $NMANY = 1000;


plan tests => $NMANY * 3 + 21;

my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.103_datastream_ids";
Log::Log4perl->init($LOG4J);
my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $CoataGlue = CoataGlue->new(%{$fixtures->{LOCATIONS}});

ok($CoataGlue, "Initialised CoataGlue object");

my $repo = $CoataGlue->repository;

ok($repo, "Connected to Fedora Commons");

my @sources = $CoataGlue->sources;

ok(@sources, "Got sources");

my $source = $sources[0];

ok($source->open, "Opened source '$source->{name}'");

# test with a set of names which are known to contain bad characters

my $datastreams = {};

for my $bad_id ( keys %BAD_IDS ) {
	$datastreams->{$bad_id} = {
		id => $bad_id,
		original => $bad_id,
		mimetype => 'text/xml'
	}
}

my $dataset = $source->dataset(
	metadata => {},
	file => 'file.xml',
    location => 'location',
	datastreams => $datastreams
);

my $fixed = $dataset->datastreams;

if( ok($fixed, "Got hash of datastreams with clean IDs") ) {
	for my $new_id ( keys %$fixed ) {
		my $old_id = $fixed->{$new_id}{oid};
		if( ok($old_id && exists $BAD_IDS{$old_id}, "Got old ID: $old_id" )  ) {
			cmp_ok($new_id, 'eq', $BAD_IDS{$old_id}, "Converted '$old_id' to '$new_id'");
		}
	}
}

# This makes an absurd number of datastreams with keys that
# will not be unique when truncated to 64 characters.

my $manystreams = {};
my $e = 0;

for my $i ( 1..$NMANY ) {
	my $id = sprintf("$BASE%0000d", $i);
	$id .= $EXTENSIONS[$e];
	$e++;
	if( $e == scalar(@EXTENSIONS) ) {
		$e = 0;
	}
	$manystreams->{$id} = {
		id => $id,
		original => "File$i",
		mimetype => 'text/xml'
	}
}

my $dataset2 = $source->dataset(
	metadata => {},
	file => 'file.xml',
    location => 'location',
	datastreams => $manystreams
);

my $manyfixed = $dataset2->datastreams;



if( ok($manyfixed, "Got fixed keys") ) {

	my @keys = keys %$manyfixed;
	
	my $n = scalar(@keys);

	cmp_ok($n, '==', $NMANY, "Got back $NMANY keys");
	
	for my $new_id ( sort keys %$manyfixed ) {
		my $old_id = $manyfixed->{$new_id}{oid};
		my $new_file = $manyfixed->{$new_id}{original};
		my $old_file = $manystreams->{$old_id}{original};
		
		ok($new_file && $old_file, "Got new and old IDs ($new_file, $old_file)");
		cmp_ok($new_file, 'eq', $old_file, "Match for $new_id");
        my $l = length($new_id);
        cmp_ok($l, '<', 65, "Length $l < 65");
	}

}
