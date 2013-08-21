#!/usr/bin/perl

=head1 NAME

008_people.t

=head1 DESCRIPTION

Test the CoataGlue::People->lookup( ) method

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";


use Test::More tests => 9;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Person;
use CoataGlue::Test qw(setup_tests);

my %RESEARCHER = (
    id => '040221',
    familyname => 'Leijdekkers',
    givenname => 'Peter',
    honorific => 'Doctor',
    jobtitle => 'Senior Lecturer',
    groupid => '927'
    );


my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.008_people";
Log::Log4perl->init($LOG4J);
my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $CoataGlue = CoataGlue->new(%{$fixtures->{LOCATIONS}});

ok($CoataGlue, "Initialised CoataGlue object");


my $solr = $CoataGlue->mint;

ok($solr, "Initialised Apache::Solr object");

my $key = $CoataGlue->conf('Redbox', 'cryptkey');
my $id = $RESEARCHER{id};

my $person = CoataGlue::Person->lookup(
    coataglue => $CoataGlue,
    id => $id
    );

if( ok($person, "Person lookup $id returned a result") ) {

    for my $field ( sort keys %RESEARCHER ) {
        cmp_ok(
            $person->{$field}, 'eq', $RESEARCHER{$field},
            "Got $field = $RESEARCHER{$field}"
            );
    }
} else {
    diag("Skipping field tests.");
}

