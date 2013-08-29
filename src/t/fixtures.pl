#!/usr/bin/perl

=head1 NAME

fixtures.pl

=head1 DESCRIPTION

Utility script to build test fixtures so that they can be used to run
harvest.pl (see src/harvest_test.sh)

=cut

use strict;


use FindBin qw($Bin);
use lib "$Bin/../lib";

use CoataGlue::Test qw(setup_tests);

my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.fixtures";
Log::Log4perl->init($LOG4J);
my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

if( $fixtures ) {
    $log->info("Fixtures built");
}
