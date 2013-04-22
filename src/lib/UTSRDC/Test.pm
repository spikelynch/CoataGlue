package UTSRDC::Test;

# Buildup routines for the tests

use parent Exporter;

our @EXPORT_OK = qw(setup_tests teardown);


use File::Path qw(remove_tree);
use File::Copy::Recursive qw(dircopy);
use Data::Dumper;
use strict;



sub setup_tests {
	my %params = @_;
	
	my $log = $params{log};
	my $fixtures = $ENV{RDC_FIXTURES} || die("Need to set RDC_FIXTURES");
	my $test = $ENV{RDC_TESTDIR} || die("Need to set RDC_TESTDIR");

	if( !$ENV{RDC_CONFIG} ) {
		$log && $log->error("Need to set RDC_CONFIG to a data source config file");
		die;
	}


	if( ! -d $fixtures ) {
		die("'$fixtures' is not a directory");
	}
	
	
	if( -d $test ) {
		$log && $log->info("Fixtures: remove $test");
		remove_tree($test, { keep_root => 1 }) || die(
			"remove_tree $test failed: $!"
		);
	} else {
		mkdir($test) || die("Couldn't mkdir $test: $!");
	}

	$log && $log->info("Fixtures: copy $fixtures/* => $test");
	
	my @results = dircopy($fixtures, $test) || die("Copy failed $!");
	
	
	return {
		SOURCES => [ 'MIF' ],
		DATASETS => { MIF => 2 }
	};
}

sub teardown {

}

1;