#!/usr/bin/perl

=head1 NAME

001_init.t

=head1 DESCRIPTION

Basic initialisation: create a UTSRDC object and get
data sources from it.

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

my $LOGGER = 'UTSRDC.tests.001_init';

if( !$ENV{RDC_LOG4J} ) {
	die("Need to set RDC_LOG4J to point at a Log4j config file");
}

Log::Log4perl->init($ENV{RDC_LOG4J});

my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

$log->debug(Dumper( { fixtures => $fixtures } ));

my $sources = UTSRDC->new(
	config => $ENV{RDC_CONFIG},
	templates => $ENV{RDC_TEMPLATES}
);

ok($sources, "Initialised UTSRDC object");

my @sources = $sources->sources;

ok(@sources, "Got sources");

cmp_ok(
	scalar(@sources),
	'==',
	scalar(@{$fixtures->{SOURCES}}),
	"Got correct number of sources"
);

cmp_ok(
	$sources[0]->{name},
	'eq',
	$fixtures->{SOURCES}[0],
	"Source name matches: $fixtures->{SOURCES}[0]"
);




