#!/usr/bin/perl

=head1 NAME

coataglue.pl

=cut

=head1 SYNOPSIS

    ./coataglue.pl -g
    ./coataglue.pl -t
    ./coataglue.pl -s Labshare
    ./coataglue.pl -l
    ./coataglue.pl -l SOURCE
    ./coataglue.pl -d DATASET_ID -s SOURCE
    ./coataglue.pl -d METADATA_FILE

=head1 DESCRIPTION

A script which takes metadata from a number of sources
and writes out harvestable version into the ReDBox harvest
folders

=head1 COMMAND LINE OPTIONS

=over 4

=item -g

Run a complete harvest

=item -t 

Run in test mode.  Doesn't flag any of the datasets as 'scanned' in the
history, and writes the harvest file to Redbox.testdirectory rather than
Redbox.directory (as configured)

=item -l [SOURCE]

If a source name is given, list all datasets for that sourcename.
Otherwise, lists all sources by name.

=item -s SOURCE_NAME

Only scan a single data source.  Can be used with -t 

=item -d DATASET_ID

Force a scan of a single dataset, identified by its file or source and
id, regardless of its status in the history.  Can be used with -t: if
it is, the dataset's status will be reset to 'new'.

If using id, also needs the -s SOURCE argument

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
use POSIX qw(strftime);


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;


my $LOGGER = 'CoataGlue.coataglue_pl';

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

getopts('htgls:d:', \%opts) || do {
    $log->error("Invalid command line option");
    usage();
    exit;
};
        

if( $opts{h} || ! keys %opts ) {
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
    if( $opts{s} ) {
        $log->info("Listing datasets for $opts{s}");
        list_datasets(source => $opts{s});
    } else {
        $log->info("Listing datasets for all sources");
        list_datasets();
    }
} elsif( $opts{d} && $opts{s} ) {
    harvest_one_dataset(source => $opts{s}, dataset => $opts{d});
} elsif( $opts{s} ) {
    harvest_one_source(source => $opts{s});
} elsif( $opts{g} || $opts{t} ) {
    harvest_all_sources();
} else {
    print "Nothing to do.\n";
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

    my $sname = $params{source};
    my $ds = $params{dataset};
    my $id = undef;
    my $source;

    if( $ds =~ /^\d+$/ ) {
        if ( !$sname ) {
            $log->error("You need to specify a source to scan a dataset by its id");
            return undef;
        }
        if( !$sources{$sname} ) {
            $log->error("Source '$source' not found.");
            list_sources();
            exit;
        } 
        $source = $sources{$sname};
        $source->open;
        $id = $ds;
    } else {
        SOURCE: for my $source ( $CoataGlue->sources ) {
            my $history = $source->open;
            if( $history->{$ds} ) {
                $id = $history->{$ds}{id};
                last SOURCE;
            }
        }
        if( !$id ) {
            $log->error("Couldn't match $ds to a scanned dataset in any source");
            return undef;
        }
    }
        
    harvest_source(source => $source, id => $id);

}




sub list_sources {
    print "Available sources:\n";
    for my $name ( sort keys %sources ) {
        print "   $name\n";
    }
}
    

sub list_datasets {
    my %params = @_;

    my $tf = $CoataGlue->conf('General', 'timeformat');

    my $source = $params{source};
    my @sources;
    
    if( $source ) {
        if( $sources{$source} ) {
            @sources = ( $sources{$source} );
        } else {
            $log->error("Source '$source' not found.");
            list_sources();
            return;
        }
    } else {
        @sources = $CoataGlue->sources;
    }
    my $any = 0;

    for my $source ( @sources ) {
        if( my $history = $source->open ) {
            # order them by ID
            my @files = sort {
                $history->{$a}{id} <=> $history->{$a}{id}
            } keys %$history;
            for my $file ( @files ) {
                my $ds = $history->{$file};
                my @t = localtime($ds->{details}{timestamp});
                my $time = strftime($tf, @t);
                print join(',',
                           $source->{name}, $ds->{id},
                           $ds->{status}, $time, $file
                    ) . "\n";
                $any = 1;
            }
        } else {
            $log->error("Couldn't open source $source->{name}");
        }
    }
    if( !$any ) {
        print "No datasets found.\n";
    }
}


sub harvest_source {
    my %params = @_;

    my $source = $params{source};

	$log->debug("Scanning source $source->{name}");
	if( $source->open ) {
        my @datasets;
        if( $params{id} ) {
            @datasets = $source->scan(test => $opts{t}, id => $params{id});
            if( !@datasets ) {
                $log->error("Couldn't find any datasets to scan");
                return undef;
            }
        } else {
            @datasets = $source->scan(test => $opts{t});
        }

		DATASET: for my $dataset ( @datasets ) {
			$log->info("Dataset: $source->{name}/$dataset->{id}");
            if( ! $opts{t} ) {
                if( $dataset->add_to_repository ) {
                    $log->info("Added $dataset->{id} to repository: $dataset->{repository_id}");
                    
                    if( my $hdl = $dataset->handle_request ) {
                        $log->info("Wrote handle request: $hdl");
                    } else {
                        $log->warn("Couldn't write handle request");
                    }


                    if( $dataset->publish ) {
                        $log->info("Published to " . $dataset->access);
                    } else {
                        $log->warn("Dataset not published to " . $dataset->access);
                    }
                } else {
                    $log->error("Couldn't add $dataset->{global_id} to repository");
                    next DATASET;
                }
            } else {
                $log->info("Test mode, not adding to repository");
			}
			my $file = $dataset->write_redbox(test => $opts{t});
			
			if( $file ) {
				$log->info("Wrote $dataset->{global_id} as ReDBox alert $file");
                if( !$opts{t} ) {
                    $dataset->set_status_ingested;
                }
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
coataglue.pl [-t -l WHAT -s SOURCE -d DATASET -g]
        
-t            Test mode: doesn't update history store and writes metadata
              to the test Redbox directory
-l            List all sources
-l -s SOURCE  List all datasets (you have to specify the source)
-s SOURCE     Only scan a single source.  Can be used with -t
-d DATASET    Only scan a single dataset.  Can be used with -t.  Will
              reharvest even if the dataset has already been processed.
EOTXT
}




