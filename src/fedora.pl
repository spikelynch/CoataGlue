#!/usr/bin/perl

=head1 NAME

fedora.pl

=cut

=head1 SYNOPSIS

    ./fedora.pl -i PID
    ./fedora.pl -i PID -u DID file
    ./fedora.pl -i PID -d DID

=head1 DESCRIPTION

CLI utility for doing things to Fedora Commons digital objects


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


my $LOGGER = 'CoataGlue.fedora_pl';

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

getopts('hp:d:x', \%opts) || do {
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

$log->info("CoataGlue = $CoataGlue");

my $repo = $CoataGlue->repository() || do {
    $log->error("Couldn't connect to repository");
    die;
};

my $pid = $opts{p} || do {
    $log->error("No PID");
    die;
};


my $ds = $repo->get_object(pid => $pid);

if( $ds ) {
    print Dumper({ds => $ds}) . "\n";
    if( $opts{d} ) {
        my $dsid = $opts{d};
        if( $dsid eq 'DC' ) {
            $log->error("Won't remove the DC metadata stream");
        } elsif( !$ds->{$dsid} ) {
            $log->error("Datastream $dsid not found");
        } else {
            $repo->purge_datastream(pid => $pid, dsid => $dsid);
        }
    }
}





sub usage {
    print<<EOTXT;
fedora.pl -p PID
fedora.pl -p PID -d DSID  : delete a datastream
        
EOTXT
}




        
