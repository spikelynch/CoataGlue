#!/usr/bin/perl

=head1 NAME

000_load.t

=head1 DESCRIPTION

Tries to load all the Perl dependencies and CoataGlue modules.

=cut

use strict;

my @MODULES = qw(
        Catmandu
        Catmandu::Store::FedoraCommons
        Crypt::Skip32
        Data::Dumper
        File::Copy::Recursive
        File::MimeInfo
        File::Path
        Getopt::Std
        Log::Log4perl
        Module::Pluggable
        POSIX
        Text::CSV
        Text::Diff
        Test::WWW::Mechanize
        XML::RegExp
        XML::Twig
        XML::Writer

        CoataGlue
        CoataGlue::Source
        CoataGlue::Converter
        CoataGlue::Dataset
        CoataGlue::Test
    );


BEGIN: {

       
    if( ! $ENV{COATAGLUE_PERLLIB} ) {
        die("Needs environment COATAGLUE_PERLLIB");
    }

    use lib $ENV{COATAGLUE_PERLLIB};

    use Test::More tests => 22;
    
    for my $module ( @MODULES ) {
        use_ok($module);
    }
};