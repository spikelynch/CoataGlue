package CoataGlue::Test;

use strict;

=head1 NAME

CoataGlue::Test

=head1 SYNOPSIS

    use CoataGlue::Test qw(setup_tests is_fedora_up);

    my $LOG4J = "$Bin/log4j.properties";
    my $LOGGER = "CoataGlue.tests.006_fedora";
    Log::Log4perl->init($LOG4J);
    my $log = Log::Log4perl->get_logger($LOGGER);

    my $fixtures = setup_tests(log => $log);

    my $CoataGlue = CoataGlue->new(%{$fixtures->{LOCATIONS}});

    ok($CoataGlue, "Initialised CoataGlue object");

    my $repo = $CoataGlue->repository;

    ok($repo, "Connected to Fedora Commons");

    if( !is_fedora_up(log => $log, repository => $repo) ) {
        die("Fedora is down.\n");
    }

=head1 DESCRIPTION

Utility routines to build up test fixtures and confirm that Fedora is 
open for business.

Some explanation which I wish I'd written in 2013 when I set all this up:

=over 4

=item src/t/Fixtures is the version-controlled set of test fixtures and config files

=item At the start of each test script which needs them, src/t/Fixures is copied to src/t/Test

=item The fixtures contain metadata files in various formats, under /Capture.  Each Capture directory has a Test subdirectory (ie Capture/MIF/Test/) which holds the reference values which the tests expect the capture process to fetch.

=back

Note that the reference values have not been updated to reflect the
test fixtures, which is why a lot of the tests fail.


=cut

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
use CoataGlue::Dataset;

my $FIXTURES_DIR = "$Bin/Test";
my $COATAGLUE_HOME = abs_path("$Bin/../..");
my $CAPTURE_DIR = "$FIXTURES_DIR/Capture";
my $EXISTING_PID = 'RDC:1';


my $COUNTS = {};

=head1 METHODS

=over 4

=item setup_tests(log => $log)

Copies the test fixtures into the test directory.  Returns a data
structure containing the parsed fixture information so that it can be
used for comparisons in tests.

=cut


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
		
	SOURCE: for my $source ( readdir($dh) ) {
        $log->info("Scanning fixtures: $source");
		next SOURCE if $source =~ /^\./;
        next SOURCE if ! -d "$CAPTURE_DIR/$source";
		my $path = "$CAPTURE_DIR/$source/Test";
		if( !-d $path ) {
			$log && $log->warn("No fixture path $path for $source");
			next SOURCE;
		}
		$fhash->{$source} = {};
		if( opendir(my $sdh, $path)) {
			DATASET: while( my $ds = readdir($sdh) ) {
				next DATASET if $ds =~ /^\./;
				my $dspath = "$path/$ds";
				$log && $log->debug("path $path / $ds");
				$fhash->{$source}{$ds}{description} = load_file(
					file => "$dspath/description.txt"
				);
				$fhash->{$source}{$ds}{description} =~ s/\s+$//g;
                $fhash->{$source}{$ds}{datastreams} = load_datastreams(
                    file => "$dspath/datastreams.csv",
                    log => $log
                );
			}
		} else {
			$log && $log->warn("Couldn't open $path")
		}
        expand_home($log, "$CAPTURE_DIR/$source");
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

=item load_file(file => $file)

Load a text file and return the contents as a single scalar

=cut

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
    my $log = $params{log};

    open(FILE, "<$file") || do {
        $log->error("Couldn't find fixture datastream file: $file");
        return undef;
    };

    my @ids = ();

    while ( my $l = <FILE> ) {
        chomp $l;
        my ( $id, $file, $mimetype ) = split(/,/, $l);
        $streams->{$id} = {
            file => join('/', $COATAGLUE_HOME, $file), 
            id => $id,
            mimetype => $mimetype
        };
        push @ids, $id;
    }

    close FILE;
    
    # if the datastream ids have $COATAGLUE, use IDset to generate
    # a set of Fedora-compliant IDs from them

    if( $ids[0] =~ /^\$COATAGLUE/ ) {
        my $estreams = {};
        for my $id ( keys %$streams ) {
            my $nid = $id;
            $nid =~ s/^\$COATAGLUE/$COATAGLUE_HOME/;
            $estreams->{$nid} = $streams->{$id};
        }
        my $idset = CoataGlue::IDset->new(raw => $estreams);
        my $map = $idset->make_ids;
        if( !$map ) {
            $log->error("Couldn't map fixture ID streams");
            return undef;
        }
        my $nstreams = {};
        for my $dsid ( keys %$map ) {
            $nstreams->{$dsid} = $estreams->{$map->{$dsid}};
        }

        $streams = $nstreams;

    }

    return $streams;
}


sub expand_home {
    my ( $log, $path ) = @_;

    opendir(my $dh, $path) || die("Couldn't read $path: $!");

  FILE: while( my $file = readdir($dh) ) {
      next FILE if $file =~ /^\./;
      next FILE unless $file =~ /\.xml$/;
      $log->debug("Expanding homedir in $path/$file");

      my $xml = '';

      local $/ = undef;

      open(my $fh, "<$path/$file") || die("Couldn't open $path/$file: $!");

      my $xml = <$fh>;

      close $fh;
      
      if( my $n = ( $xml =~ s/\$COATAGLUE/$COATAGLUE_HOME/g ) ) {
          $log->debug("Expanded \$COATAGLUE $n times");
      }
      
      open(my $fh2, ">$path/$file") || die("Couldn't open $path/$file for writing: $!");
      
      print $fh2 $xml;
      
      close $fh2;

      $log->debug("Expanded XML:\n$xml");
  }
    closedir($dh);
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
        $list->{$id}{staffid} = $id;
    }

    return $list;
}
    


sub teardown {

}


=item is_fedora_up(log => $log, repository => $repo)

Tries to connect to the repository: returns 0 if it can't.

=cut

sub is_fedora_up {
	my ( %params ) = @_;
	
	my $log = $params{log};
	my $repo = $params{repository};
	
	my $fc = $repo->repository;
	
	ok($fc, "Got a repository") || do {
		$log->fatal("Didn't get a repository connection");
		die;
	};
	
#	my $result = $fc->getObjectProfile(pid => $EXISTING_PID);
#	
#	if( ok($result->is_ok, "Got an object profile") ) {
#		return 1;
#	} else {
#		$log->fatal("No repository.  Make sure Fedora Commons is running.");
#		die;
#	}
	
}


=back

=cut


1;
