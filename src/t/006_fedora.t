#!/usr/bin/perl

=head1 NAME

006_fedora.t

=head1 DESCRIPTION

Publishes all of the text fixture records and adds them to Fedora.

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More skip_all => "Haven't set up a working Fedora repository"; #tests => 80;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;

use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests is_fedora_up);

my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.006_fedora";
Log::Log4perl->init($LOG4J);
my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $CoataGlue = CoataGlue->new(%{$fixtures->{LOCATIONS}});

$log->warn("HELLO");

ok($CoataGlue, "Initialised CoataGlue object");

my $repo = $CoataGlue->repository;

ok($repo, "Connected to Fedora Commons");

is_fedora_up(log => $log, repository => $repo);

my @sources = $CoataGlue->sources;

ok(@sources, "Got sources");

for my $source ( @sources ) {
 	my $sname = $source->{name};

  SKIP: {
      skip "Source $sname inactive", 26 if $source->skip;


	ok($source->open, "Opened source '$sname'");

	my @datasets = $source->scan;

	ok(@datasets, "Got at least one dataset");

 	DATASET: for my $ds ( @datasets ) {
		$ds->{metadata}{access} = 'public';
		my $datastreams = $ds->{datastreams};
		ok($datastreams && keys %$datastreams, 
			"Dataset has datastreams") || next DATASET;
		ok($ds->{metadata}{access}, "Dataset has access value $ds->{metadata}{access}");
		$log->warn("Dataset $ds->{id} has access value $ds->{metadata}{access}");
		ok($ds->add_to_repository, "Added dataset to Fedora");

		ok($ds->{repository_id}, "Dataset has repostory_id: $ds->{repository_id}") || do {
            die("Check that Fedora is running.");
        };
		my $url = $ds->url;

		my $expect = $source->conf('Publish', 'dataseturl');

		if( $expect !~ /\/$/ ) {
			$expect .= '/';
		}

		$expect .= $ds->safe_repository_id;
		cmp_ok($url, 'eq', $expect, "Dataset has URL $expect");
	
		ok($ds->write_redbox, "Wrote metadata record for ReDBox");
		
		ok($ds->publish(to => $ds->{metadata}{access}), 

           "Published dataset to $ds->{metadata}{access}");			
	
		for my $id ( keys %$datastreams ) {
			my $datastream = $datastreams->{$id};
			my $stream_url = $datastream->url;
			my $expect_stream = join(
				'/', $source->conf('Publish', 'datastreamurl'),
				$ds->access, $ds->safe_repository_id, $datastream->{id}
			);
					
			cmp_ok($stream_url, 'eq', $expect_stream, "Datastream has URL: $expect_stream");
		}

	}

    }
}
