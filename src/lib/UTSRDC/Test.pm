package UTSRDC::Test;

# Buildup routines for the tests

use parent Exporter;

our @EXPORT_OK = qw(buildup teardown);


use File::Path qw(remove_tree);
use File::Copy::Recursive qw(dircopy);
use Data::Dumper;
use strict;



sub buildup {
	my %params = @_;
	
	my $log = $params{log};
	my $fixtures = $ENV{RDC_FIXTURES} || die("Need to set RDC_FIXTURES");
	my $test = $ENV{RDC_TESTDIR} || die("Need to set RDC_TESTDIR");

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
	
	
	
}

sub teardown {

}

1;