package UTSRDC::Test;

# Buildup routines for the tests

use parent Exporter;

our @EXPORT_OK = qw(setup_tests teardown);


use File::Path qw(remove_tree);
use File::Copy::Recursive qw(dircopy);
use Data::Dumper;
use strict;


my $SAMPLE_DESCRIPTION = "$ENV{RDC_TESTDIR}/Extras/description.txt";
my $SAMPLE_SERVICE = 'MIF.service.1';


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
		DATASETS => { MIF => 3 },
		DESCRIPTION => loadfile(file => $SAMPLE_DESCRIPTION),
		SERVICE => $SAMPLE_SERVICE
	};
}

sub loadfile {
	my ( %params ) = @_;
	
	my $file = $params{file};
	local $/ = undef;
	open(FILE, "<$file") || die("Can't open file $file: $!");
	my $contents = <FILE>;
	close FILE;
	return $contents;
}

sub teardown {

}

1;