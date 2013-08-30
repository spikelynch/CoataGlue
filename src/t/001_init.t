#!/usr/bin/perl

=head1 NAME

001_init.t

=head1 DESCRIPTION

Basic initialisation: create a CoataGlue object and get
data sources from it.

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 12;
use Data::Dumper;
use JSON;

use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.001_init";

Log::Log4perl->init($LOG4J);
my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $cg = CoataGlue->new(%{$fixtures->{LOCATIONS}});

ok($cg, "Initialised CoataGlue object");

my @sources = $cg->sources;

ok(@sources, "Got sources");

my @fixtures = sort grep { $_ !~ /STAFF|LOCATIONS/ } keys %$fixtures;

cmp_ok(
	scalar(@sources),
	'==',
	scalar(@fixtures),
	"Got correct number of sources"
);

my @got_names = sort map { $_->{name} } @sources;

for my $got ( @got_names ) {
	my $expect = shift @fixtures;
	cmp_ok(
		$got, 'eq', $expect,
		"Got source name $expect"
	);
}

# Not checking the publish directory because it isn't inside the
# Coataglue home

my @confdirs = (
    [ 'Store', 'store', ],
#    [ 'Publish', 'directory' ],
    [ 'Redbox', 'directory' ]
);

my $home = $fixtures->{LOCATIONS}{home};

for my $conf ( @confdirs ) {
    my $value = $cg->conf(@$conf);
    like($value, qr/^$home/, "\$COATAGLUE expanded in $conf->[0].$conf->[1]");
}

for my $source ( @sources ) {
    my $value = $source->{converter}{basedir};
    like($value, qr/^$home/, "\$COATAGLUE expanded in source basedir");
}

my $jsonmap = join(
    '/',
    $cg->conf('Redbox', 'directory'),
    $cg->conf('Redbox', 'jsonmap')
    );

if( ok(-f $jsonmap, "Found JSON map $jsonmap") ) {
    local $/ = undef;
    open(my $fh, "<$jsonmap") || die("Couldn't read; $!");
    my $json = <$fh>;
    close $fh;

    my $j = JSON->new;
    my $data = undef;

    eval {
        $data = $j->decode($json);
    };

    ok(!$@, "JSON map parsed OK") || do {
        diag("JSON parse error: $@");
    };
    
    ok($data->{mappings}, "JSON has a 'mappings' value");
}
