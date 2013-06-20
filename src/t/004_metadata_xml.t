#!/usr/bin/perl

=head1 NAME

004_xml.t

=head1 DESCRIPTION

Tests generating XML versions of a dataset's metadata

TODO: this should test the contents of the <header> element.

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

my $LOGGER = "CoataGlue.tests.004_xml";

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

	ok($source->open, "Opened source $sname") || die;

	my @datasets = $source->scan;

	ok(@datasets, "Got at least one dataset");

	$source->close;
	
	# fish out the standard metadata crosswalk so that we know
	# the names of the fields to compare XML values with
	
	my $md_map = $source->{template_cf}{metadata};

	for my $ds ( @datasets  ) {

        my $xml = $ds->xml();

        ok($xml, "Generated some XML");

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
            $twig->parse($xml)
        };
        
        if( ok(!$@, "XML parsed OK") ) {
            my $raw = $ds->{raw_metadata};
            
            cmp_ok(
                $title, 'eq', $raw->{$md_map->{title}},
                "<title> = $md_map->{title} = $title"
                );
            
            cmp_ok(
                $projectname, 'eq', $raw->{$md_map->{projectname}},
                "<projectname> = $md_map->{projectname} = $projectname"
                );
            
            my $handle = $source->staff_id_to_handle(
                id => $raw->{$md_map->{creator}}
            );
            
            cmp_ok(
                $creator, 'eq', $handle,
                "<creator> = handle = $creator"
                );
            
            $description =~ s/\s*^//g;
            $fixtures->{$sname}{description} =~ s/\s*^//g;
            
            cmp_ok(
                $description, 'eq', $fixtures->{$sname}{description},
                "<description> content as expected"
                ) || do {
                    my $diff = diff \$fixtures->{$sname}{description}, \$description;
                    print "DIFF: \n$diff\n";
            };
            
            cmp_ok(
                $service, 'eq', $fixtures->{$sname}{service},
                "<service> = $fixtures->{$sname}{service}"
                );
        }
	}
}

