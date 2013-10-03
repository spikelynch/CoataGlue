#!/usr/bin/perl

=head1 NAME

harvest.pl

=cut

=head1 SYNOPSIS

    ./harvest.pl
    ./harvest.pl -t
    ./harvest.pl -s 
    ./harvest.pl -s SOURCE_NAME
    ./harvest.pl -l datasets
    ./harvest.pl -d DATASET_ID

=head1 DESCRIPTION

A script which takes metadata from a number of sources
and writes out harvestable version into the ReDBox harvest
folders

=head1 COMMAND LINE OPTIONS

=over 4

=item -t 

Run in test mode.  Doesn't flag any of the datasets as 'scanned' in the
history, and writes the harvest file to Redbox.testdirectory rather than
Redbox.directory (as configured)

=item -l OBJECTS

List all OBJECTS, where OBJECTS = 'sources' or 'datasets'

=item -s SOURCE_NAME

Only scan a single data source.  Can be used with -t 

=item -d DATASET_ID

Force a re-scan of a single dataset, identified by its global ID, regardless
of its status in the history.  Can be used with -t: if it is, the dataset's
status will be reset to 'new'.

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

getopts('htl:s:d:', \%opts) || do {
    $log->error("Invalid command line option");
    usage();
    exit;
};
        

if( $opts{h} ) {
    usage();
    exit;
}

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


if( $opts{t} ) {
     
    if( my $testdir = $CoataGlue->conf('Redbox', 'testdirectory') ) {
        $log->info("Running in test mode.");
        $log->info("Metadata files written to $testdir");
    } else {
        $log->error("Cannot run in test mode - no test directory.");
        $log->error("You need to set Redbox.testdirectory in $ENV{COATAGLUE_CONFIG}");
        die;
    }
}

my %sources = map { $_->{name} =>  $_ } $CoataGlue->sources;

if( $opts{l} ) {
    if( lc($opts{l}) eq 'sources' ) {
        list_sources();
    } elsif ( lc($opts{l}) eq 'datasets' ) {
        if( !$opts{s} ) {
            $log->error("Must have -s SOURCE to list datasets");
            list_sources();
            exit;
        } else {
            list_datasets(source => $opts{s});
        }
    }
} elsif( $opts{s} ) {
    harvest_one_source(source => $opts{s});
} elsif( $opts{d} ) {
    harvest_one_dataset(dataset => $opts{d});
} else {
    harvest_all_sources();
}



sub harvest_all_sources {
  SOURCE: for my $source ( $CoataGlue->sources ) {
      harvest_source(source => $source);
  }
}


sub harvest_one_source {
    my %params = @_;

    if( my $source = $sources{$opts{s}} ) {
        harvest_source(source => $source);
    } else {
        $log->error("Source '$opts{s}' not found.");
        list_sources();
        die;
    }
}



sub harvest_one_dataset {
    my %params = @_;

    # todo


}




sub list_sources {
    print "Available sources:\n";
    for my $name ( sort keys %sources ) {
        print "   $name\n";
    }
}
    

sub list_datasets {
    my %params = @_;

    if( my $source = $sources{$opts{s}} ) {
        if( my $history = $source->open ) {
            print Dumper({history => $history});
        }
    } else {
        $log->error("Source '$opts{s}' not found.");
        list_sources();
        die;
    }
}


sub harvest_source {
    my %params = @_;

    my $source = $params{source};

	$log->debug("Scanning source $source->{name}");
	if( $source->open ) {
		for my $dataset ( $source->scan(test => $opts{t}) ) {
			$log->debug("Dataset: $dataset->{global_id}");
			
			if( $dataset->add_to_repository ) {
				$log->info("Added $dataset->{global_id} to repository: $dataset->{repository_id}");
                if( $dataset->publish ) {
                    $log->info("Published to " . $dataset->access);
                } else {
                    $log->warn("Dataset not published to " . $dataset->access);
                }

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




sub usage {
    print<<EOTXT;
harvest.pl [-t -l -s SOURCE d DATASET]
        
-t      Test mode: doesn't update history store and writes metadata
        to the test Redbox directory
-l      List available sources
-s      Only scan a single source.  Can be used with -t
-d      Only scan a single dataset.  Can be used with -t.  Will
        reharvest even if the dataset has already been processed.


EOTXT
}




