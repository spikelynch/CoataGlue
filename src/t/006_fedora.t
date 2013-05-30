#!/usr/bin/perl

=head1 NAME

006_fedora.t

=head1 DESCRIPTION

Tests adding a record to Fedora.

=cut

use strict;

if( ! $ENV{COATAGLUE_PERLLIB} || ! $ENV{COATAGLUE_LOG4J}) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
}

use lib $ENV{COATAGLUE_PERLLIB};


use Test::More tests => 11;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $LOGGER = "CoataGlue.tests.006";

my $DATASET_RE = 'P1_E1';

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

my @datasets = $source->scan;

ok(@datasets, "Got at least one dataset");

my $ds = shift @datasets;

my ( $ds ) = grep { $_->{file} =~ /$DATASET_RE/ } @datasets;

if( ok($ds, "Found dataset matching /$DATASET_RE/") ) {

	ok($ds->add_to_repository, "Added dataset to Fedora");

	ok($ds->{repositoryid}, "Dataset has repostoryid: $ds->{repositoryid}");

	ok($ds->{datastreams} && keys %{$ds->{datastreams}}, 
		"Dataset has datastreams");

	my $datastreams = $ds->fix_datastream_ids;
	
	if( ok($datastreams &&  keys %{$ds->{datastreams}},
		"Got standardised-ID datastreams") ) {
	
		for my $id ( %$datastreams ) {
			my $datastream = $datastreams->{$id};
			ok(
				$ds->add_datastream(%$datastream),
				"Added dataset $datastream->{id}: $datastream->{file}"
			);
		}
	}

	my $file = $ds->write_redbox;

	if( ok($file, "Wrote XML: $file") ) {
		diag("TODO");
	}

}
