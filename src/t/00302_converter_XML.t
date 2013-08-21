#!/usr/bin/perl

=head1 NAME

00301_converter_XML.t

=head1 DESCRIPTION

Test the crosswalk from raw to cooked metadata for an XML datasource

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 5 + 2 * 8 + ( 1 + 2 + 4 ) * 3;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.00302_converter_XML";
Log::Log4perl->init($LOG4J);
my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $CoataGlue = CoataGlue->new(%{$fixtures->{LOCATIONS}});

ok($CoataGlue, "Initialised CoataGlue object");


my @sources = $CoataGlue->sources;

ok(@sources, "Got sources");

my ( $source ) = grep { $_->{name} eq 'Labshare' } @sources;

if( !ok($source, "Got the Labshare XML source") ) {
	die("Can't continue");
}


ok($source->open, "Opened source $source->{name}") || die;

my @datasets = $source->scan;

my $n = scalar @datasets;
my $nf = scalar keys %{$fixtures->{Labshare}};

cmp_ok($n, '==', $nf, "Got $nf datasets") || die;

$source->close;

for my $ds ( @datasets ) {
	my $file = $ds->short_file;
	my $md = $ds->metadata;
   
    my $f = $fixtures->{Labshare}{$file};

	if( ok($md, "Got metadata for $file") ) {

		cmp_ok(
			$md->{title}, 'eq', $ds->{raw_metadata}{title},
			"title = $md->{title}"
		);

		cmp_ok(
			$md->{projectnumber}, 'eq', $ds->{raw_metadata}{activity},
			"projectnumber = activity = $md->{projectnumber}"
		);

		cmp_ok(
			$md->{service}, 'eq', $md->{service},
			"service = $md->{service}"
		);

        my $staff_id = $ds->{raw_metadata}{creator};

        my $staff = $fixtures->{STAFF}{$staff_id};

        for my $field ( qw(mintid name
            givenname familyname honorific jobtitle groupid) ) {
            cmp_ok(
                $md->{creator}{$field}, 'eq', $staff->{$field},
                "creator/$field = $staff->{$field}"
                );
        }



		$md->{description} =~ s/\s*$//g;


		cmp_ok(
			$md->{description}, 'eq', $f->{description},
			"<description> content as expected"
		) || do {
			my $diff = diff \$f->{description}, \$md->{description};
			print "DIFF: \n$diff\n";
		};
	}

    if( ok(my $datastreams = $ds->{datastreams}, "Got datastreams") ) {

        for my $dsid ( keys %$datastreams ) {
            my $ds = $datastreams->{$dsid};
            my $fds = $f->{datastreams}{$dsid};
            if( ok($fds, "Found datastream $dsid in fixtures") ) {
                cmp_ok($ds->{original}, 'eq', $fds->{file}, "File = $fds->{file}");
                cmp_ok($ds->{mimetype}, 'eq', $fds->{mimetype}, "MIME type = $fds->{mimetype}");
            }
        }

    }

	ok($ds->{datecreated}, "Dataset has datecreated '$ds->{datecreated}'");

}




