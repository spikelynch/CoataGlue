#!/usr/bin/perl

=head1 NAME

005_write_redbox_xml.t

=head1 DESCRIPTION

Tests writing ReDBox XML.

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

my $LOGGER = "CoataGlue.tests.005_write_redbox";

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

ok($source->open, "Opened source '$source->{name}'");

my @datasets = $source->scan;

ok(@datasets, "Got at least one dataset");

my $ds = shift @datasets;

my $file = $ds->write_redbox;

if( ok($file, "Wrote XML to file: $file") ) {
	
	my ( $title, $projectname, $creator, $description, $service ) = ( '', '', '', '', '', '' );

	my $twig = XML::Twig->new(
		twig_handlers => {
			title => 		sub { $title       = $_->text },
			projectname =>  sub { $projectname = $_->text },
			creator =>		sub { $creator     = $_->text },
			description => 	sub { $description = $_->text },
			service => 		sub { $service     = $_->text }
		}
	); 

	eval {
		$twig->parsefile($file)
	};

	ok(!$@, "XML parsed OK");

	my $raw = $ds->{raw_metadata};

	cmp_ok(
		$title, 'eq', $raw->{Experiment_Name},
		"<title> = Experiment_Name = $title"
	);

	cmp_ok(
		$projectname, 'eq', $raw->{Project_Name},
		"<projectname> = Project_ID = $projectname"
	);

	my $handle = $source->staff_id_to_handle(
		id => $raw->{Project_Creator_Staff_Student_ID}
	);

	cmp_ok(
		$creator, 'eq', $handle,
		"<creator> = handle = $creator"
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
} else {
	diag("XML parse error: $@");
}

	
