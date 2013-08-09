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


use Test::More tests => 66;
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
					description => 	sub { $description = $_->text },
					service => 		sub { $service     = $_->text },
                    creator =>		sub {
                        $creator = {};
                        for my $f ( qw(mintid staffid givenname familyname
                                   honorific jobtitle groupid) ) {
                            $creator->{$f} = $_->first_child_text($f);
                        }
                    },
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

                for my $f ( sort keys %{$md->{creator}} ) {
                    cmp_ok(
                        $creator->{$f}, 'eq', $md->{creator}{$f},
                        "creator/$f = '$md->{creator}{$f}'"
                        );
                }

                my $fixture_id = fix_id($ds);

                my $fdesc = $fixtures->{$sname}{$fixture_id}{description};

				$description =~ s/\s*$//g;
    			$fdesc =~ s/\s*$//g;

				cmp_ok(
					$description, 'eq', $fdesc,
					"<description> content as expected"
				) || do {
					my $diff = diff \$fdesc, \$description;
					print "DIFF: \n$diff\n";
				};

			} else {
				diag("XML parse error: $@");
			}
		}
	}
}
	

sub fix_id {
    my ( $ds ) = @_;

    my $file = $ds->{file};

    if( $file =~ m#/([^/]+)$# ) {
        return $1;
    } else {
        die("Couldn't grep filename from $file");
    }
}
