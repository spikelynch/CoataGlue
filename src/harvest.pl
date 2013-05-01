#!/usr/bin/perl

=head1 NAME

harvest.pl

=head1 SYNOPSIS

    ./harvest.pl
    ./harvest.pl -s MIF
    ./harvest.pl -n

=head1 DESCRIPTION

A script which takes metadata from a number of sources
and writes out harvestable version into the ReDBox harvest
folders

=head1 CONFIGURATION

=head2 Environment variables

If any of these is missing, the script won't run:

=over 4

=item RDC_PERLLIB - location of CoataGlue::* perl libraries

=item RDC_LOG4J - location of the log4j.properties file

=back

=head2 Command-line switches

=over 4

=item -s DATASOURCE: only harvest one datasource

=item -n            

=item -h            - Print help

=back

=cut

use strict;

if( ! $ENV{RDC_PERLLIB} || ! $ENV{RDC_LOG4J}) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
}

use lib $ENV{RDC_PERLLIB};

use Data::Dumper;
use Getopt::Std;
use Config::Std;
use Log::Log4perl;


use UTSRDC;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;


my $LOGGER = 'UTSRDC.harvest';

if( !$ENV{RDC_LOG4J} ) {
	die("Need to set RDC_LOG4J to point at a Log4j config file");
}


Log::Log4perl->init($ENV{RDC_LOG4J});

my $log = Log::Log4perl->get_logger($LOGGER);

if( !$ENV{RDC_CONFIG} ) {
	$log->error("Need to set RDC_CONFIG to a data source config file");
	die;
}


my $utsrdc = UTSRDC->new(
	conf => $ENV{RDC_CONFIG},
	templates => $ENV{RDC_TEMPLATES}
);

if( !$utsrdc ) {
	$log->error("Couldn't initialise UTSRDC");
	die;
}

SOURCE: for my $source ( $utsrdc->sources ) {
	$source->lock;
	eval {
		run_harvest(source => $source);
	};
	if( $@ ) {
		$log->error("$source->{name} harvest problem: $@");
	}
	$source->release;
}



sub run_harvest {
	my %params = @_;
	
	my $source = $params{source};
	my @datasets;
	$log->info("Scanning data source $source->{name}");

	eval {
		@datasets = $source->scan;
	};
	
	if( $@ ) {
		$log->error("$source->{name} scan failed: $@")
	}
	$log->info("Found " . scalar(@datasets) . " datasets");
	for my $dataset ( @datasets ) {
		eval {



#			if( $dataset->{metadata}{publish} ) {
#				if( !$dataset->fc_publish() ) {
#					$log->error("Fedora publish failed")
#				}
#				$dataset->{metadata}{publish} = undef;
#			}
#			if( $dataset->write_xml ) {
#				$dataset->set_status_ingested;
#			} else {
#				$dataset->set_status_error()
#				$log->error("Write ingest XML failed");
#			}				
		};
		
		my $xml = $dataset->xml(view => 'Dataset');
		
		print $xml;
		
		if( $@ ) {
			$log->error("Write XML $source->{name}: $dataset->{id} failed");
			$log->error("Error: $@");
		} else {
			$log->info("Wrote  XML for $source->{name}: $dataset->{id}");
		}
	}
	
}


