#!/usr/bin/perl

=head1 NAME

008_people.t

=head1 DESCRIPTION

Test the CoataGlue::People->lookup( ) method

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";


use Test::More tests => 3 + 5 * 9;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Person;
use CoataGlue::Test qw(setup_tests);


my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.008_people";
Log::Log4perl->init($LOG4J);
my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $CoataGlue = CoataGlue->new(%{$fixtures->{LOCATIONS}});

ok($CoataGlue, "Initialised CoataGlue object");

my ( $source ) = $CoataGlue->sources;

ok($source, "Got a source");

my $solr = $CoataGlue->mint;

ok($solr, "Initialised Apache::Solr object");

# loop over all staff in the fixtures.

my $staff = $fixtures->{STAFF};

for my $id ( sort keys %$staff ) {

    my $person = CoataGlue::Person->lookup(
        source => $source,
        id => $id
        );
    
    if( ok($person, "Person lookup $id returned a result") ) {
        my $creator = $person->creator;
        for my $field ( sort keys %{$staff->{$id}} ) {
            cmp_ok(
                $creator->{$field}, 'eq', $staff->{$id}{$field},
                "Got $field = $staff->{$id}{$field}"
                );
        }
    } else {
        diag("#### Person lookup failed, skipped 6 field tests");
    }
}

