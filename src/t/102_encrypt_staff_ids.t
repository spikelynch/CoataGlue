#!/usr/bin/perl

=head1 NAME

008_encrypt_staff_ids.t

=head1 DESCRIPTION

Test the staff_id => handle encryption

=cut

use strict;

if( ! $ENV{COATAGLUE_PERLLIB} || ! $ENV{COATAGLUE_LOG4J}) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
}

use lib $ENV{COATAGLUE_PERLLIB};


use Test::More tests => 5;
use Data::Dumper;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Person;
use CoataGlue::Test qw(setup_tests);


my %STAFF_IDS = (
	910031 => 'http://hdl.handle.net/11057/idb14e8cdc',
	105465 => 'http://hdl.handle.net/11057/idaac499d9',
	890007 => 'http://hdl.handle.net/11057/idb1e5f066'
);



my $LOGGER = "CoataGlue.tests.008";

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

ok(@sources, "Got source");

my $source = $sources[0];

for my $id ( keys %STAFF_IDS ) {
	my $expect = $STAFF_IDS{$id};
	my $got = $source->staff_id_to_handle(id => $id);
	cmp_ok($got, 'eq', $expect, "id $id => $expect"); 
}

