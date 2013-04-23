#!/usr/bin/perl

=head1 NAME

003_harvest.t

=head1 DESCRIPTION

Tests generating XML versions of a dataset's metadata

=cut

use strict;

if( ! $ENV{RDC_PERLLIB} || ! $ENV{RDC_LOG4J}) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
}

use lib $ENV{RDC_PERLLIB};


use Test::More tests => 8;
use Data::Dumper;
use XML::Twig;

use UTSRDC;
use UTSRDC::Source;
use UTSRDC::Converter;
use UTSRDC::Dataset;
use UTSRDC::Test qw(setup_tests);

my $LOGGER = 'UTSRDC.tests.003_xml';

if( !$ENV{RDC_LOG4J} ) {
	die("Need to set RDC_LOG4J to point at a Log4j config file");
}

Log::Log4perl->init($ENV{RDC_LOG4J});

my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $utsrdc = UTSRDC->new(
	config => $ENV{RDC_CONFIG},
	templates => $ENV{RDC_TEMPLATES}
);

ok($utsrdc, "Initialised UTSRDC object");

my @sources = $utsrdc->sources;

ok(@sources, "Got sources");

my $source = $sources[0];

my @datasets = $source->scan;

ok(@datasets, "Got at least one dataset");

my $ds = shift @datasets;

my $xml = $ds->xml(view => 'Dataset');

ok($xml, "Generated some XML");

my ( $title, $activity, $party ) = ( '', '', '' );

my $twig = XML::Twig->new(
	twig_handlers => {
		title => 	sub { $title = $_->text },
		activity => sub { $activity = $_->text },
		party =>	sub { $party = $_->text }
	}
); 

eval {
	$twig->parse($xml)
};

ok(!$@, "XML parsed OK");

cmp_ok(
	$title, 'eq', $ds->{metadata}{Experiment_Name},
	"<title> = Experiment_Name"
);

cmp_ok(
	$activity, 'eq', $ds->{metadata}{Project_ID},
	"<activity> = Project_ID"
);

cmp_ok(
	$party, 'eq', $ds->{metadata}{Project_Creator_Staff_Student_ID},
	"<party> = Project_Creator_Staff_Student_ID"
);
