#!/usr/bin/perl

=head1 NAME

00301_converter_XML.t

=head1 DESCRIPTION

Test the crosswalk from raw to cooked metadata for an XML datasource

=cut

use strict;

if( ! $ENV{COATAGLUE_PERLLIB} || ! $ENV{COATAGLUE_LOG4J}) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
}

use lib $ENV{COATAGLUE_PERLLIB};


use Test::More tests => 12;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $LOGGER = "CoataGlue.tests.00302_converter_XML";

if( !$ENV{COATAGLUE_LOG4J} ) {
	die("Need to set COATAGLUE_LOG4J to point at a Log4j config file");
}

Log::Log4perl->init($ENV{COATAGLUE_LOG4J});

my $log = Log::Log4perl->get_logger($LOGGER);

my $f = setup_tests(log => $log);

my $fixtures = $f->{Labshare};

my $CoataGlue = CoataGlue->new(
	global => $ENV{COATAGLUE_CONFIG},
	sources => $ENV{COATAGLUE_SOURCES},
	templates => $ENV{COATAGLUE_TEMPLATES}
);

ok($CoataGlue, "Initialised CoataGlue object");


my @sources = $CoataGlue->sources;

ok(@sources, "Got sources");

my ( $source ) = grep { $_->{name} eq 'Labshare' } @sources;

if( !ok($source, "Got the Labshare XML source") ) {
	die("Can't continue");
}


ok($source->open, "Opened source $source->{name}") || die;

my @datasets = $source->scan;

ok(@datasets, "Got at least one dataset") || die;

$source->close;

my $ds = shift @datasets;

my $md = $ds->metadata();

if( ok($md, "Got metadata hash") ) {
	
	cmp_ok(
		$md->{title}, 'eq', $ds->{raw_metadata}{title},
		"title = $md->{title}"
	);

	cmp_ok(
		$md->{projectnumber}, 'eq', $ds->{raw_metadata}{activity},
		"projectnumber = activity = $md->{projectnumber}"
	);

	my $handle = $source->staff_id_to_handle(
		id => $ds->{raw_metadata}{creator}
	);

	cmp_ok(
		$md->{creator}, 'eq', $handle,
		"creator = $handle = $md->{creator}"
	);

	$md->{description} =~ s/\s*$//g;


	cmp_ok(
		$md->{description}, 'eq', $fixtures->{description},
		"<description> content as expected"
	) || do {
		my $diff = diff \$fixtures->{description}, \$md->{description};
		print "DIFF: \n$diff\n";
	};

	cmp_ok(
		$md->{service}, 'eq', $fixtures->{service},
		"service = $fixtures->{service}"
	);
	
}

ok($ds->{datecreated}, "Dataset has datecreated '$ds->{datecreated}'");
	



