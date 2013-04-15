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

=item RDC_PERLLIB - location of UTSRDC::* perl libraries

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

use UTSRDC::DataSource;

my $LOGGER = 'UTSRDC.harvest';

if( !$ENV{RDC_LOG4J} ) {
	die("Need to set RDC_LOG4J to point at a Log4j config file");
}
Log::Log4perl->init($ENV{RDC_LOG4J});

my $log = Log::Log4perl->get_logger($LOGGER);

my $sources = UTSRDC::DataSource->new();

$sources->scan();


#
#my $rdc = UTSRDC->new();
#
#for my $source ( $rdc->sources ) {
#	eval {
#		my $datasets = $source->get_new_datasets;
#		for my $dataset ( @$datasets ) {
#			$dataset->write_metadata;
#		}
#	};
#	if( $@ ) {
#		$rdc->error("Error harvesting from " . $source->name());
#	}
#}
