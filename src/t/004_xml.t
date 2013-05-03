#!/usr/bin/perl

=head1 NAME

003_xml.t

=head1 DESCRIPTION

Tests generating XML versions of a dataset's metadata

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

my $LOGGER = "CoataGlue.tests.004";

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

my $xml = $ds->xml(view => 'redbox');

ok($xml, "Generated some XML");

diag($xml);

my ( $title, $activity, $party, $description, $service ) = ( '', '', '', '', '', '' );

my $twig = XML::Twig->new(
	twig_handlers => {
		title => 		sub { $title = $_->text },
		activity => 	sub { $activity = $_->text },
		party =>		sub { $party = $_->text },
		description => 	sub { $description = $_->text },
		service => 		sub { $service = $_->text }
	}
); 

eval {
	$twig->parse($xml)
};

ok(!$@, "XML parsed OK");

cmp_ok(
	$title, 'eq', $ds->{metadata}{Experiment_Name},
	"<title> = Experiment_Name = $title"
);

cmp_ok(
	$activity, 'eq', $ds->{metadata}{Project_ID},
	"<activity> = Project_ID = $activity"
);

cmp_ok(
	$party, 'eq', $ds->{metadata}{Project_Creator_Staff_Student_ID},
	"<party> = Project_Creator_Staff_Student_ID = $party"
);

cmp_ok(
	$description, 'eq', $fixtures->{DESCRIPTION},
	"<description> content as expected"
) || do {
	my $diff = diff \$fixtures->{DESCRIPTION}, \$description;
	print "DIFF: \n$diff\n";
};

cmp_ok(
	$service, 'eq', $fixtures->{SERVICE},
	"<service> = $fixtures->{SERVICE}"
);



