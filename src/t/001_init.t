#!/usr/bin/perl

=head1 NAME

001_init.t

=head1 DESCRIPTION

Basic initialisation: create a CoataGlue object and get
data sources from it.

=cut

use strict;

if( ! $ENV{COATAGLUE_PERLLIB} || ! $ENV{COATAGLUE_LOG4J}) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
}

use lib $ENV{COATAGLUE_PERLLIB};


use Test::More tests => 4;
use Data::Dumper;

use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $LOGGER = "CoataGlue.tests.001";

if( !$ENV{COATAGLUE_LOG4J} ) {
	die("Need to set COATAGLUE_LOG4J to point at a Log4j config file");
}

Log::Log4perl->init($ENV{COATAGLUE_LOG4J});

my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $sources = CoataGlue->new(
	global => $ENV{COATAGLUE_CONFIG},
	sources => $ENV{COATAGLUE_SOURCES},
	templates => $ENV{COATAGLUE_TEMPLATES}
);

diag("\@INC =\n" . join("\n", @INC));


ok($sources, "Initialised CoataGlue object");

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




