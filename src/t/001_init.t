#!/usr/bin/perl

=head1 NAME

001_init.t

=head1 DESCRIPTION

Basic initialisation tests

=cut


use Test::More;

use UTSRDC;
use UTSRDC::Source;
use UTSRDC::Converter;
use UTSRDC::Dataset;

my $LOGGER = 'UTSRDC.test.001';



if( !$ENV{RDC_LOG4J} ) {
	die("Need to set RDC_LOG4J to point at a Log4j config file");
}

Log::Log4perl->init($ENV{RDC_LOG4J});

my $log = Log::Log4perl->get_logger($LOGGER);

if( !$ENV{RDC_CONFIG} ) {
	$log->error("Need to set RDC_CONFIG to a data source config file");
	die;
}


my $sources = UTSRDC->new(conf => $ENV{RDC_CONFIG});
















SOURCE: for my $source ( $sources->sources ) {
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
			# 
			
			
			
			
			
			$dataset->write_xml;
		};
		if( $@ ) {
			$log->error("Write XML $source->{name}: $dataset->{id} failed");
			$log->error("Error: $@");
		} else {
			$log->info("Wrote  XML for $source->{name}: $dataset->{id}");
		}
	}
}




