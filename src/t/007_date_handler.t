#!/usr/bin/perl

=head1 NAME

007_time_convert.t

=head1 DESCRIPTION

Test for the date-format-frobbing code in Coataglue::Source

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

my @DATES = (
	'01/01/2001',
	'31/12/1999',
	'4/5/2006',
	'11/11/2011',
	'//232',
	'05/05/05'
);


my $LOGGER = "CoataGlue.tests.007";

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

ok($sources, "Initialised CoataGlue object");

my @sources = $sources->sources;

ok(@sources, "Got sources");

my $source = $sources[0];

my $handler = $source->{template_handlers}{metadata}{datecreated};

if( cmp_ok(ref($handler), 'eq', 'CODE', "Got a CODE reference for handler") ) {
	for my $date ( @DATES ) {
		my $cooked = &$handler($date);
		diag("$date => $cooked");
	}
}
