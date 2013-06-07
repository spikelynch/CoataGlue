#!/usr/bin/perl

=head1 NAME

003_crosswalks.t

=head1 DESCRIPTION

Test the crosswalk from raw to cooked metadata

=cut

use strict;

if( ! $ENV{COATAGLUE_PERLLIB} || ! $ENV{COATAGLUE_LOG4J}) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
}

use lib $ENV{COATAGLUE_PERLLIB};


use Test::More tests => 11;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $LOGGER = "CoataGlue.tests.003_crosswalks";

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

ok($source->open, "Opened source $source->{name}") || die;

my @datasets = $source->scan;

ok(@datasets, "Got at least one dataset");

$source->close;

my $ds = shift @datasets;


my $md = $ds->metadata();

if( ok($md, "Got metadata hash") ) {
	
	cmp_ok(
		$md->{title}, 'eq', $ds->{raw_metadata}{Experiment_Name},
		"title = Experiment_Name = $md->{title}"
	);

	cmp_ok(
		$md->{projectname}, 'eq', $ds->{raw_metadata}{Project_Name},
		"projectname = Project_Name = $md->{projectname}"
	);

	my $handle = $source->staff_id_to_handle(
		id => $ds->{raw_metadata}{Project_Creator_Staff_Student_ID}
	);

	cmp_ok(
		$md->{creator}, 'eq', $handle,
		"creator = $handle = $md->{creator}"
	);

	cmp_ok(
		$md->{description}, 'eq', $fixtures->{DESCRIPTION},
		"<description> content as expected"
	) || do {
		my $diff = diff \$fixtures->{DESCRIPTION}, \$md->{description};
		print "DIFF: \n$diff\n";
	};

	cmp_ok(
		$md->{service}, 'eq', $fixtures->{SERVICE},
		"service = $fixtures->{SERVICE}"
	);
	
	
}

ok($ds->{datecreated}, "Dataset has datecreated '$ds->{datecreated}'");
	


