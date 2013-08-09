#!/usr/bin/perl

=head1 NAME

00301_converter_FolderCSV.t

=head1 DESCRIPTION

Test the crosswalk from raw to cooked metadata for a FolderCSV
datasource

=cut

use strict;

if( ! $ENV{COATAGLUE_PERLLIB} || ! $ENV{COATAGLUE_LOG4J}) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
}

use lib $ENV{COATAGLUE_PERLLIB};


use Test::More tests => 5 + 3 * 8 + ( 1 + 1 + 3 ) * 3;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $LOGGER = "CoataGlue.tests.00301_converter_FolderCSV";

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

		cmp_ok(
			$md->{title}, 'eq', $ds->{raw_metadata}{Experiment_Name},
			"title = Experiment_Name = $md->{title}"
		);

		cmp_ok(
			$md->{projectname}, 'eq', $ds->{raw_metadata}{Project_Name},
			"projectname = Project_Name = $md->{projectname}"
		);

		my $handle = $source->staff_id_to_handle(
			id => $ds->{raw_metadata}{Project_Creator_Staff_Student_ID}
		);

		cmp_ok(
			$md->{creator}, 'eq', $handle,
			"creator = $handle"
		);
		
		my $service = 'MIF.service.2';
		if( $ds->{raw_metadata}{Instrument_Name} eq "UTS Demo Microscope" ) {
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

	



