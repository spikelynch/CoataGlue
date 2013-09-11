#!/usr/bin/perl

=head1 NAME

104_map_handler.t

=head1 DESCRIPTION

Test for the value-remapping handlers 

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 7;
use Data::Dumper;

use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my %MAP = (
    'open access' => 'public',
    'uts' => 'uts',
    'email' => 'email',
    'closed' => 'closed'

   );


my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.104_date_handler";
Log::Log4perl->init($LOG4J);
my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $CoataGlue = CoataGlue->new(%{$fixtures->{LOCATIONS}});

ok($CoataGlue, "Initialised CoataGlue object");

my @sources = $CoataGlue->sources;

ok(@sources, "Got sources");

my ( $source ) = grep { $_->{name} eq 'Labshare' } @sources;

my $handler = $source->{template_handlers}{metadata}{access};

if( cmp_ok(ref($handler), 'eq', 'CODE', "Got a CODE reference for handler") ) {
    for my $key ( keys %MAP ) {
        my $mapped = &$handler($key);
        cmp_ok($mapped, 'eq', $MAP{$key}, "Mapped $key => $MAP{$key}");
    }
}
