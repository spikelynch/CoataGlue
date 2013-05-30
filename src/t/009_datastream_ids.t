#!/usr/bin/perl

=head1 NAME

009_datastream_ids.t

=head1 DESCRIPTION

Tests the CoataGlue::Dataset's fix_datastream_ids method's ability to
correct messy datastream ids that aren't allowed by Fedora, yet still
keep them unique.

=cut


if( ! $ENV{COATAGLUE_PERLLIB} || ! $ENV{COATAGLUE_LOG4J}) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
}

use lib $ENV{COATAGLUE_PERLLIB};

use strict;


use Test::More;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $LOGGER = "CoataGlue.tests.009";

my $DATASET_RE = 'P1_E1';

my %BAD_IDS = (
	'000' => 'D000',
	'200x900_photo.jpg' => 'D200x900_photo.jpg',
	'Warning:contains:colons' => 'Warning_contains_colons',
	'Has spaces?' => 'Has_spaces_',
	'this name is full of spaces and is also quite long. The algorithm needs to truncate it and replace the spaces with underscores' => 'this_name_is_full_of_spaces_and_is_also_quite_long._The_algorith'
);

my $BASE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ';
my $NMANY = 6000;


plan tests => $NMANY + 12;


if( !$ENV{COATAGLUE_LOG4J} ) {
	die("Need to set COATAGLUE_LOG4J to point at a Log4j config file");
}

Log::Log4perl->init($ENV{COATAGLUE_LOG4J});

my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $CoataGlue = CoataGlue->new(
	global => $ENV{COATAGLUE_CONFIG},
	sources => $ENV{COATAGLUE_SOURCES},
	templates => $ENV{COATAGLUE_TEMPLATES}
);

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
		file => $bad_id
	}
}

my $dataset = $source->dataset(
	metadata => {},
	file => 'file.xml',
	datastreams => $datastreams
);

my $fixed = $dataset->fix_datastream_ids;

if( ok($fixed, "Got hash of datastreams with clean IDs") ) {
	for my $new_id ( keys %$fixed ) {
		my $old_id = $fixed->{$new_id}{old_id};
		if( exists $BAD_IDS{$old_id} ) {
			cmp_ok($new_id, 'eq', $BAD_IDS{$old_id}, "Converted '$old_id' to '$new_id'");
		}
	}
}

# This makes an absurd number of datastreams with keys that
# will not be unique when truncated to 64 characters.

my $manystreams = {};


for my $i ( 1..$NMANY ) {
	my $id = sprintf("$BASE%0000d", $i);
	$manystreams->{$id} = {
		id => $id,
		file => "File$i",
	}
}

my $dataset2 = $source->dataset(
	metadata => {},
	file => 'file.xml',
	datastreams => $manystreams
);

my $manyfixed = $dataset2->fix_datastream_ids;

if( ok($manyfixed, "Got fixed keys") ) {

	my @keys = keys %$manyfixed;
	my $n = scalar(@keys);

	cmp_ok($n, '==', $NMANY, "Got back $NMANY keys");
	
	for my $new_id ( sort keys %$manyfixed ) {
		my $old_id = $manyfixed->{$new_id}{old_id};
		my $new_file = $manyfixed->{$new_id}{file};
		my $old_file = $manystreams->{$old_id}{file};
		
		
		cmp_ok($new_file, 'eq', $old_file, "Match for $new_id");
	}

}