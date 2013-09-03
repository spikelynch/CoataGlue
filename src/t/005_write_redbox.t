#!/usr/bin/perl

=head1 NAME

005_write_redbox_xml.t

=head1 DESCRIPTION

Tests writing ReDBox XML.

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 126;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.005_write_redbox";
Log::Log4perl->init($LOG4J);
my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my @CREATOR_FIELDS = qw(mintid staffid givenname familyname
                          honorific jobtitle groupid name);


my $CoataGlue = CoataGlue->new(%{$fixtures->{LOCATIONS}});

ok($CoataGlue, "Initialised CoataGlue object");

my @sources = $CoataGlue->sources;

ok(@sources, "Got sources");

for my $source ( @sources ) {
	my $sname = $source->{name};
	
	ok($source->open, "Opened source '$sname'");

	my @datasets = $source->scan;

	ok(@datasets, "Got at least one dataset");

	DATASET: for my $ds ( @datasets ) {

		my $datastreams = $ds->{datastreams};
		ok($datastreams && keys %$datastreams, 
			"Dataset has datastreams") || next DATASET;

		ok($ds->add_to_repository, "Added dataset to Fedora");

		ok($ds->{repository_id}, "Dataset has repostory_id: $ds->{repository_id}") || do {
            die("Check that Fedora is running.");
        };


		my $file = $ds->write_redbox;
        

		if( ok($file, "Wrote XML to file: $file") ) {	
			my (
				$title, $project,
				$description, $service
			) = ( '', '', '', '', '' );
            
            my ( $header, $creator, $links );

			my $twig = XML::Twig->new(
				twig_handlers => {
                    header =>       sub {
                        $header = {};
                        for my $f ( qw(id source file  access
                                       dateconverted) ) {
                            $header->{$f} = $_->first_child_text($f);
                        }
                    },
					title => 		sub { $title       = $_->text },
					project     =>  sub { $project      = $_->text },
					description => 	sub { $description = $_->text },
					service => 		sub { $service     = $_->text },
                    creator =>		sub {
                        $creator = {};
                        for my $f ( @CREATOR_FIELDS ) {
                            $creator->{$f} = $_->first_child_text($f);
                        }
                    },
                    links => sub {
                        $links = {};
                        for my $link ( $_->children('link') ) {
                            $links->{$link->atts->{type}} = $link->atts->{uri}
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

            # Titles have timestamps appended to them.  Because it's 
            # refreshed when the ->metadata method is called, we remove
            # the timestamp and use like(/^$title/) to compare it to the
            # parsed XML.
            
                my @title = split(/ /, $md->{title});
                pop @title;
                my $title_less_ts = join(' ', @title);

                like(
                    $title, qr/^$title_less_ts/,
                    "<title> =~ /^$title_less_ts/"
                    );
                

                cmp_ok(
                    $header->{id}, 'eq', $ds->{id},
                    "Header <id> = $ds->{id}"
                    );

                cmp_ok(
                    $header->{file}, 'eq', $ds->{file},
                    "Header <file> = $ds->{file}"
                    );

                cmp_ok(
                    $header->{source}, 'eq', $ds->{source}{name},
                    "Header <source> = $ds->{source}{name}"
                    );

                cmp_ok(
                    $links->{location}, 'eq', $ds->{location},
                    "Header <links type=\"location\"> = $ds->{location}"
                    );

                cmp_ok(
                    $links->{repositoryURL}, 'eq', $ds->url,
                    "Header <links type=\"repositoryURL\" > = " . $ds->url
                    );

                cmp_ok(
                    $header->{access}, 'eq', $md->{access},
                    "Header <access> = $md->{access}"
                    );

                cmp_ok(
                    $header->{dateconverted}, 'eq', $ds->{dateconverted},
                    "Header <dateconverted> = $ds->{dateconverted}"
                    );

				cmp_ok(
					$project, 'eq', $md->{project},
					"<project> = $project"
				);

                if( ok(my $staffid = $creator->{staffid}, "Got creator staffid") ) {
                    my $fixture = $fixtures->{STAFF}{$staffid};
                    
                    for my $f ( @CREATOR_FIELDS ) {
                        cmp_ok(
                            $creator->{$f}, 'eq', $fixture->{$f},
                            "creator/$f = '$fixture->{$f}'"
                            );
                    }
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
