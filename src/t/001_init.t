#!/usr/bin/perl

=head1 NAME

001_init.t

=head1 DESCRIPTION

Basic initialisation: create a CoataGlue object and get
data sources from it.

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 5;
use Data::Dumper;

use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.001_init";
Log::Log4perl->init($LOG4J);
my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $sources = CoataGlue->new(%{$fixtures->{LOCATIONS}});

ok($sources, "Initialised CoataGlue object");

my @sources = $sources->sources;

ok(@sources, "Got sources");

my @fixtures = sort grep { $_ !~ /STAFF|LOCATIONS/ } keys %$fixtures;

cmp_ok(
	scalar(@sources),
	'==',
	scalar(@fixtures),
	"Got correct number of sources"
);

my @got_names = sort map { $_->{name} } @sources;

for my $got ( @got_names ) {
	my $expect = shift @fixtures;
	cmp_ok(
		$got, 'eq', $expect,
		"Got source name $expect"
	);
}





