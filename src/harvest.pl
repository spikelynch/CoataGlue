#!/usr/bin/perl

=head1 NAME

harvest.pl

=head1 SYNOPSIS

    ./harvest.pl
    ./harvest.pl -t

=head1 DESCRIPTION

A script which takes metadata from a number of sources
and writes out harvestable version into the ReDBox harvest
folders

=head1 CONFIGURATION

=head2 Environment variables

If any of these is missing, the script won't run:

=over 4

=item COATAGLUE_HOME - the root of the CoataGlue installation

=item COATAGLUE_PERLLIB - location of CoataGlue::* perl libraries

=item COATAGLUE_LOG4J - location of the log4j.properties file

=item COATAGLUE_CONFIG - main config file 

=item COATAGLUE_SOURCES - sources config file

=item COATAGLUE_TEMPLATES - templates directory

=back


=cut

use strict;


my $missing = 0;

for my $ev ( qw(HOME PERLLIB LOG4J CONFIG SOURCES TEMPLATES) ) {
	my $full_ev = "COATAGLUE_$ev"; 
	if( !$ENV{$full_ev} ) {
		warn("Missing environment variable $full_ev\n");
		$missing = 1;
	}
}

if( $missing ) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
	
}

use lib $ENV{COATAGLUE_PERLLIB};

use Data::Dumper;
use Getopt::Std;
use Config::Std;
use Log::Log4perl;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;


my $LOGGER = 'CoataGlue.harvest';

if( !$ENV{COATAGLUE_LOG4J} ) {
	die("Need to set COATAGLUE_LOG4J to point at a Log4j config file");
}


Log::Log4perl->init($ENV{COATAGLUE_LOG4J});

my $log = Log::Log4perl->get_logger($LOGGER);

if( !$ENV{COATAGLUE_CONFIG} ) {
	$log->error("Need to set COATAGLUE_CONFIG to a data source config file");
	die;
}

my %opts;

getopts('t', \%opts) || die;


my $CoataGlue = CoataGlue->new(
    home => $ENV{COATAGLUE_HOME},
	global => $ENV{COATAGLUE_CONFIG},
	sources => $ENV{COATAGLUE_SOURCES},
	templates => $ENV{COATAGLUE_TEMPLATES}
);

if( !$CoataGlue ) {
	$log->error("Couldn't initialise CoataGlue");
	die;
}


SOURCE: for my $source ( $CoataGlue->sources ) {
	$log->debug("Scanning source $source->{name}");
	if( $source->open ) {
		for my $dataset ( $source->scan(test => $opts{t}) ) {
			$log->debug("Dataset: $dataset->{global_id}");
			
			if( $dataset->add_to_repository ) {
				$log->info("Added $dataset->{global_id} to repository: $dataset->{repository_id}");
			} else {
				$log->error("Couldn't add $dataset->{global_id} to repository");
			}
			
			my $file = $dataset->write_redbox;
			
			if( $file ) {
				$log->info("Wrote $dataset->{global_id} as ReDBox alert $file");
				$dataset->set_status_ingested;
			} else {
				$log->error("Coudn't write $dataset->{global_id} to ReDBox");
				$dataset->set_status_error;
			}
		}
		$source->close;
	}
}
	

