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


use Test::More tests => 36;
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

for my $source ( @sources ) {
	my $sname = $source->{name};
	
	ok($source->open, "Opened source '$sname'");

	my @datasets = $source->scan;

	ok(@datasets, "Got at least one dataset");

	for my $ds ( @datasets ) {

		my $file = $ds->write_redbox;

		if( ok($file, "Wrote XML to file: $file") ) {	
			my (
				$title, $projectname,
				$creator, $description, $service
			) = ( '', '', '', '', '', '' );

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

			if( ok(!$@, "XML parsed OK") ) {

				my $md = $ds->metadata;
				my $mdfile = $ds->short_file;
				cmp_ok(
					$title, 'eq', $md->{title},
					"<title> = $title"
				);

				cmp_ok(
					$projectname, 'eq', $md->{projectname},
					"<projectname> = $projectname"
				);

				cmp_ok(
					$creator, 'eq', $md->{creator},
					"<creator> = $creator"
				);

				$description =~ s/\s*$//g;
    			$fixtures->{$sname}{$mdfile} =~ s/\s*$//g;

				cmp_ok(
					$description, 'eq', $fixtures->{$sname}{$mdfile},
					"<description> content as expected"
				) || do {
					my $diff = diff \$fixtures->{$sname}{$mdfile}, \$description;
					print "DIFF: \n$diff\n";
				};

			} else {
				diag("XML parse error: $@");
			}
		}
	}
}
	
