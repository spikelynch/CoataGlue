package CoataGlue::Test;

# Buildup routines for the tests

use parent Exporter;

our @EXPORT_OK = qw(setup_tests teardown is_fedora_up);

use Log::Log4perl;
use Test::More;
use File::Path qw(remove_tree);
use File::Copy::Recursive qw(dircopy);
use Data::Dumper;
use strict;


my $FIXTURES_DIR = "$ENV{COATAGLUE_TESTDIR}/Extras";
my $EXISTING_PID = 'RDC:1';


sub setup_tests {
	my %params = @_;
	
	my $log = $params{log};
	my $fixtures = $ENV{COATAGLUE_FIXTURES} || die("Need to set COATAGLUE_FIXTURES");
	my $test = $ENV{COATAGLUE_TESTDIR} || die("Need to set COATAGLUE_TESTDIR");

	if( !$ENV{COATAGLUE_CONFIG} ) {
		$log && $log->error("Need to set COATAGLUE_CONFIG to a data source config file");
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
	
	
	my $fhash = {
		MIF => {  datasets => 3	},
		Labshare => { datasets => 2 }
	};
	
	for my $source ( keys %$fhash ) {
		$fhash->{$source}{description} = loadfile(
			file => "$FIXTURES_DIR/$source.description.txt"
		);
		$fhash->{$source}{service} = loadfile(
			file => "$FIXTURES_DIR/$source.service.txt"
		);
		chomp $fhash->{$source}{description};
		chomp $fhash->{$source}{service};
	}
	
	return $fhash
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

sub is_fedora_up {
	my ( %params ) = @_;
	
	my $log = $params{log};
	my $repo = $params{repository};
	
	my $fc = $repo->repository;
	
	ok($fc, "Got a repository") || do {
		$log->fatal("Didn't get a repository connection");
		die;
	};
	
	my $result = $fc->getObjectProfile(pid => $EXISTING_PID);
	
	if( ok($result->is_ok, "Got an object profile") ) {
		return 1;
	} else {
		$log->fatal("No repository.  Make sure Fedora Commons is running.");
		die;
	}
	
}



1;