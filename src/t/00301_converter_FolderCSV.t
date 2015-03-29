#!/usr/bin/perl

=head1 NAME

00301_converter_FolderCSV.t

=head1 DESCRIPTION

Test the crosswalk from raw to cooked metadata for a FolderCSV
datasource

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More skip_all => "Fixtures are out of date";           # tests => 65;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.00301_converter_FolderCSV";
Log::Log4perl->init($LOG4J);
my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);


my $CoataGlue = CoataGlue->new(%{$fixtures->{LOCATIONS}});

ok($CoataGlue, "Initialised CoataGlue object");


my @sources = $CoataGlue->sources;

ok(@sources, "Got sources");

my ( $source ) = grep { $_->{name} eq 'MIF' } @sources;

if( !ok($source, "Got the MIF CSV source") ) {
	die("Can't continue");
}


ok($source->open, "Opened source $source->{name}") || die;

my @datasets = $source->scan;

my $n = scalar(@datasets);

my $nf = scalar keys %{$fixtures->{MIF}};

ok($n, "Got $nf datasets");

$source->close;

for my $ds ( @datasets ) {

	my $file = $ds->short_file;
	my $md = $ds->metadata;
    my $f = $fixtures->{MIF}{$file};

	if( ok($md, "Got metadata for $file") ) {

        my $raw = $ds->{raw_metadata};
        
        # like, because test titles have timestamps appended to them

		like(
			$md->{title}, qr/^$raw->{Experiment_Name}/,
			"title =~ /^$raw->{Experiment_Name}/"
		);

		cmp_ok(
			$md->{project}, 'eq', $raw->{Project_Name},
			"project = Project_Name = $raw->{Project_Name}"
		);

        my $staff_id = $raw->{Project_Creator_Staff_Student_ID};

        my $staff = $fixtures->{STAFF}{$staff_id};

        for my $field ( qw(mintid name 
            givenname familyname name jobtitle honorific groupid) ) {
            cmp_ok(
                $md->{creator}{$field}, 'eq', $staff->{$field},
                "creator/$field = $staff->{$field}"
                );
        }
		
		my $service = 'MIF.service.2';
		if( $raw->{Instrument_Name} eq "UTS Demo Microscope" ) {
			$service = 'MIF.service.1';
		}

		cmp_ok(
			$md->{service}, 'eq', $service,
			"service = $service"
		);
	

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

	



