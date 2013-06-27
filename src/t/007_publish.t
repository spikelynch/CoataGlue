#!/usr/bin/perl

=head1 NAME

010_publish.t

=head1 DESCRIPTION

Adds a record to Fedora, then publishes it to first the local
and then the public Damyata directories

=cut

use strict;

if( ! $ENV{COATAGLUE_PERLLIB} || ! $ENV{COATAGLUE_LOG4J}) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
}

use lib $ENV{COATAGLUE_PERLLIB};

use Test::More tests => 34;
use Test::WWW::Mechanize;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests is_fedora_up);

my $LOGGER = "CoataGlue.tests.007_publish";

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

is_fedora_up(log => $log, repository => $repo);

my $mech = Test::WWW::Mechanize->new;

my @sources = $CoataGlue->sources;

ok(@sources, "Got sources");

my %datasets = {};

for my $source ( @sources ) {

	ok($source->open, "Opened source '$source->{name}'");

	my @datasets = $source->scan;

	ok(@datasets, "Got at least one dataset");

	for my $ds ( @datasets ) {
	
		if( ok($ds->{datastreams} && keys %{$ds->{datastreams}}, "Dataset has datastreams") ) {

			ok($ds->add_to_repository, "Added dataset to Fedora");
			ok($ds->{repository_id}, "Dataset has repostoryid: $ds->{repository_id}");

			ok($ds->write_redbox, "Wrote metadata record for ReDBox");
		
			ok($ds->publish(to => 'local'), "Published dataset to local");			
			
#			push @ds_urls, $ds->url;
			
		}
	}
}