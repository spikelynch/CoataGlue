#!/usr/bin/perl

=head1 NAME

002_harvest.t

=head1 DESCRIPTION

Scan a metadata capture folder, check that it ingested
the right number of datasets, then run it again and
check that it doesn't rehavest the same datasets
twice

=cut

use strict;

if( ! $ENV{RDC_PERLLIB} || ! $ENV{RDC_LOG4J}) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
}

use lib $ENV{RDC_PERLLIB};


use Test::More tests => 4;
use Data::Dumper;

use UTSRDC;
use UTSRDC::Source;
use UTSRDC::Converter;
use UTSRDC::Dataset;
use UTSRDC::Test qw(setup_tests);

my $LOGGER = 'UTSRDC.tests.002_harvest';

if( !$ENV{RDC_LOG4J} ) {
	die("Need to set RDC_LOG4J to point at a Log4j config file");
}

Log::Log4perl->init($ENV{RDC_LOG4J});

my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

$log->debug(Dumper( { fixtures => $fixtures } ));

my $sources = UTSRDC->new(conf => $ENV{RDC_CONFIG});

ok($sources, "Initialised UTSRDC object");

my @sources = $sources->sources;

ok(@sources, "Got sources");

my $source = $sources[0];

my $count_ds = $fixtures->{DATASETS}{$source->{name}};

my @datasets = $source->scan;

cmp_ok(scalar(@datasets), '==', $count_ds, "Got $count_ds datasets");


