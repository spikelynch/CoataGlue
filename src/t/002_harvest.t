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

if( ! $ENV{COATAGLUE_PERLLIB} || ! $ENV{COATAGLUE_LOG4J}) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
}

use lib $ENV{COATAGLUE_PERLLIB};


use Test::More tests => 15;
use Data::Dumper;

use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);


my $LOGGER = "CoataGlue.tests.002";

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

my @sources = $CoataGlue->sources;

ok(@sources, "Got sources");

my $source = $sources[0];

my $count_ds = $fixtures->{DATASETS}{$source->{name}};

# scanning without locking the source should return 0 datasets

my @datasets = $source->scan;

ok(!@datasets, "Scan doesn't work until source has been opened.");

ok($source->open, "Opened source");

@datasets = $source->scan;

cmp_ok(scalar(@datasets), '==', $count_ds, "Got $count_ds datasets");

my $ds = $datasets[0];

my $status = $ds->get_status;
cmp_ok($status->{status}, 'eq', 'new', "Status of dataset is 'new'");

$ds->set_status_ingested;

my $status = $ds->get_status;
cmp_ok($status->{status}, 'eq', 'ingested', "Status of dataset is now 'ingested'");

cmp_ok($ds->{id}, '==', 1, "Dataset has ID == 1");

ok($source->close, "Source closed");

ok($source->open, "Source re-opened");

@datasets = $source->scan;

my $new_count_ds = $count_ds - 1;

cmp_ok(scalar(@datasets), '==', $new_count_ds, "Got $new_count_ds datasets");

$ds = $datasets[0];

my $status = $ds->get_status;
cmp_ok($status->{status}, 'eq', 'new', "Status of dataset is 'new'");

$ds->set_status_ingested;

my $status = $ds->get_status;
cmp_ok($status->{status}, 'eq', 'ingested', "Status of dataset is now 'ingested'");

cmp_ok($ds->{id}, '>', 1, "Dataset has ID > 1");


ok($source->close, "Source closed");

