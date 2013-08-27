package CoataGlue::Test;

use strict;

# Buildup routines for the tests

use parent qw(Exporter);

our @EXPORT_OK = qw(setup_tests teardown is_fedora_up);

use Config::Std;
use Log::Log4perl;
use Test::More;
use File::Path qw(remove_tree);
use File::Copy::Recursive qw(dircopy);
use Data::Dumper;
use Cwd qw(abs_path);
use FindBin qw($Bin);

use lib "$Bin/../lib";


use CoataGlue::Person;


my $FIXTURES_DIR = "$Bin/Test";
my $COATAGLUE_HOME = abs_path("$Bin/../..");
my $CAPTURE_DIR = "$FIXTURES_DIR/Capture";
my $EXISTING_PID = 'RDC:1';


my $COUNTS = {};


sub setup_tests {
	my %params = @_;
	
	my $log = $params{log};
	my $fixtures = "$Bin/Fixtures";
	my $test = "$Bin/Test";


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
		
	my $fhash = {};
	my $dh;
		

	opendir(my $dh, $CAPTURE_DIR) || do {
		die("Couldn't scan $CAPTURE_DIR");
	};
		
	SOURCE: for my $item ( readdir($dh) ) {
		next SOURCE if $item =~ /^\./;
        next SOURCE if ! -d "$CAPTURE_DIR/$item";
		my $path = "$CAPTURE_DIR/$item/Test";
		if( !-d $path ) {
			$log && $log->warn("No fixture path $path for $item");
			next SOURCE;
		}
		$fhash->{$item} = {};
		if( opendir(my $sdh, $path)) {
			DATASET: while( my $ds = readdir($sdh) ) {
				next DATASET if $ds =~ /^\./;
				my $dspath = "$path/$ds";
				$log && $log->debug("path $path / $ds");
				$fhash->{$item}{$ds}{description} = load_file(
					file => "$dspath/description.txt"
				);
				$fhash->{$item}{$ds}{description} =~ s/\s+$//g;
                $fhash->{$item}{$ds}{datastreams} = load_datastreams(
                    file => "$dspath/datastreams.csv"
                );
			}
		} else {
			$log && $log->warn("Couldn't open $path")
		}
	}

    $fhash->{STAFF} = read_staff();
    $fhash->{LOCATIONS} = {
        global => "$FIXTURES_DIR/Config/CoataGlue.cf",
        sources => "$FIXTURES_DIR/Config/DataSources.cf",
        templates => "$FIXTURES_DIR/Config/Templates",
        home => $COATAGLUE_HOME
    };
       
	return $fhash
}

sub load_file {
	my ( %params ) = @_;
	
	my $file = $params{file};
	local $/ = undef;
	open(FILE, "<$file") || die("Can't open file $file: $!");
	my $contents = <FILE>;
	close FILE;
	return $contents;
}

sub load_datastreams {
    my ( %params ) = @_;

    my $streams = {};

    my $file = $params{file};

    open(FILE, "<$file") || do {
        warn("No datastreams.csv in dataset fixtures");
        return undef;
    };

    while ( my $l = <FILE> ) {
        chomp $l;
        my ( $id, $file, $mimetype ) = split(/,/, $l);
        $streams->{$id} = {
            file => join('/', $COATAGLUE_HOME, $file), 
            id => $id,
            mimetype => $mimetype
        };
    }

    close FILE;
    return $streams;
}


sub read_staff {
    my $file = $CAPTURE_DIR . '/staff.cf';

    my $list;
    
    read_config($file => $list);

    for my $id ( keys %$list ) {
        $list->{$id}{name} = join(
            ' ',
            $list->{$id}{honorific}, $list->{$id}{givenname},
            $list->{$id}{familyname}
            );
    }
    return $list;
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
