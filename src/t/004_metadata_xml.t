#!/usr/bin/perl

=head1 NAME

004_xml.t

=head1 DESCRIPTION

Tests generating XML versions of a dataset's metadata


=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 81;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);


my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.004_xml";
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

	ok($source->open, "Opened source $sname") || die;

	my @datasets = $source->scan;

	ok(@datasets, "Got at least one dataset");

	$source->close;
	
	# fish out the standard metadata crosswalk so that we know
	# the names of the fields to compare XML values with
	
	my $md_map = $source->{template_cf}{metadata};

	for my $ds ( @datasets  ) {
		my $file = $ds->short_file;
        my $xml = $ds->xml;
        my $md = $ds->metadata;

        ok($xml, "Generated some XML");

        my ( $title, $project, $creator,
             $repositoryURL, $location,
             $description, $service );

        my $twig = XML::Twig->new(
            twig_handlers => {
                title => 		 sub { $title         = $_->text },
                project     =>   sub { $project       = $_->text },
                description => 	 sub { $description   = $_->text },
                service => 		 sub { $service       = $_->text },
                repositoryURL => sub { $repositoryURL = $_->text },
                location => 	 sub { $location      = $_->text },
                creator =>		 sub {
                    $creator = {};
                    for my $f ( @CREATOR_FIELDS ) {
                        $creator->{$f} = $_->first_child_text($f);
                    }
                }
            }
            ); 
        eval {
            $twig->parse($xml)
        };
        


        if( ok(!$@, "XML parsed OK") ) {

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
                $project, 'eq', $md->{project},
                "<project> = $md->{project}"
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

            my $fdesc = $fixtures->{$sname}{$file}{description};
            
            $description =~ s/\s*$//g;
            $fdesc =~ s/\s*$//g;

            
            cmp_ok(
                $description, 'eq', $fdesc,
                "<description> content as expected"
                ) || do {
                    my $diff = diff \$fdesc, \$description;
                    print "DIFF: \n$diff\n";
            };

            cmp_ok(
                $location, 'eq', $ds->{location},
                "Location link = $ds->{location}"
                );
            
        }
    }
}

