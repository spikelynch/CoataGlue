#!/usr/bin/perl

=head1 NAME

002_harvest.t

=head1 DESCRIPTION

Tests the following:

* scan a metadata harvest directory
* flagging datasets as ingested
* rescanning which doesn't pick up the flagged datasets.

=cut

use strict;


use FindBin qw($Bin);
use lib "$Bin/../lib";

# Note: count = 2 + $NUMBER_OF_SOURCES * 14;

use Test::More tests => 2 + 3 * 14;

use Data::Dumper;

use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.002_harvest";
Log::Log4perl->init($LOG4J);
my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $CoataGlue = CoataGlue->new(%{$fixtures->{LOCATIONS}});

ok($CoataGlue, "Initialised CoataGlue object");

my @sources = $CoataGlue->sources;

ok(@sources, "Got sources");

for my $source ( @sources ) {
	my $f = $fixtures->{$source->{name}};

	my $count_ds = scalar keys %$f;

	# scanning without locking the source should return 0 datasets

	my @datasets = $source->scan;

	ok(!@datasets, "Scan doesn't work until source has been opened.");

	ok($source->open, "Opened source");

	@datasets = $source->scan;

        my $ndatasets = scalar @datasets;
        
	cmp_ok($ndatasets, '>=', 1, "Got $count_ds datasets");

        if( $ndatasets < 1 ) {
            die("No datasets, can't continue");
	}

	my $ds = shift @datasets;
	
	my $status = $ds->get_status;
		
	cmp_ok(
		$status->{status}, 'eq', 'new',
		"Status of dataset is 'new'"
	);

	$ds->set_status_ingested;

	my $status = $ds->get_status;
	
	cmp_ok(
		$status->{status}, 'eq', 'ingested',
		"Status of dataset is now 'ingested'"
	);
	
	my $id = $ds->{id};

	like($id, qr/\d+/, "Dataset id is numeric");

	ok($source->close, "Source closed");

	ok($source->open, "Source re-opened");

	@datasets = $source->scan;

	my $new_count_ds = $ndatasets - 1;

	cmp_ok(
		scalar(@datasets), '==', $new_count_ds,
		"Got $new_count_ds datasets"
	);

	$ds = shift @datasets;

	my $status = $ds->get_status;
	cmp_ok(
		$status->{status}, 'eq', 'new',
		"Status of dataset is 'new'"
	);

	$ds->set_status_ingested;

	my $status = $ds->get_status;
	cmp_ok(
		$status->{status}, 'eq', 'ingested',
		"Status of dataset is now 'ingested'"
	);

	cmp_ok($ds->{id}, '>', $id, "Dataset has ID > $id");

	ok($ds->{dateconverted}, "Has a value for dateconverted '$ds->{dateconverted}'");

	ok($source->close, "Source closed");
}
