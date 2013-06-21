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


use Test::More tests => 32;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests is_fedora_up);

my $LOGGER = "CoataGlue.tests.006_fedora";

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

is_fedora_up(log => $log, repository => $repo);

my @sources = $CoataGlue->sources;

ok(@sources, "Got sources");

for my $source ( @sources ) {
 	my $sname = $source->{name};
	ok($source->open, "Opened source '$sname'");

	my @datasets = $source->scan;

	ok(@datasets, "Got at least one dataset");

	DATASET: for my $ds ( @datasets ) {
		my $datastreams = $ds->{datastreams};
		ok($datastreams && keys %$datastreams, 
			"Dataset has datastreams") || next DATASET;

		ok($ds->add_to_repository, "Added dataset to Fedora");

		ok($ds->{repository_id}, "Dataset has repostory_id: $ds->{repository_id}");
	
		for my $id ( keys %$datastreams ) {
			my $datastream = $datastreams->{$id};
			ok(
				$datastream->write(),
				"Added dataset $datastream->{id}: $datastream->{file}"
			);
		}
	}

}
