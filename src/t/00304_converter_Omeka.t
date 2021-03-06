#!/usr/bin/perl

=head1 NAME

00304_converter_Omeka.t

=head1 DESCRIPTION

Test of a converter which reads the OAIPMH feed from Omeka as a data and
metadata source

TODO: this needs a mock OAI-PMH interface so that it can run without
an Omeka to point to

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 11;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Test qw(setup_tests);

my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.00304_converter_Omeka.t";

Log::Log4perl->init($LOG4J);

my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $CoataGlue = CoataGlue->new(%{$fixtures->{LOCATIONS}});

ok($CoataGlue, "Initialised CoataGlue object");

my @sources = $CoataGlue->sources;

ok(@sources, "Got sources");

my ( $source ) = grep { $_->{name} eq 'Omeka' } @sources;



if( !ok($source, "Got the Omeka source") ) {
#    diag(Dumper ( { sources => \@sources }));
    die("Can't continue");
}

SKIP: {
    skip "Omeka not active", 10 if $source->skip;

    ok($source->open, "Opened source $source->{name}") || die;

    my @datasets = $source->scan;

    for my $ds ( @datasets ) {
        print "Dataset $ds->{file}\n";
        for my $dsid ( keys %{$ds->{datastreams}} ) {
            print "   $dsid,$ds->{datastreams}{$dsid}{file}\n";
        }
    }


    my $n = scalar @datasets;

    cmp_ok($n, '>', 0, "Got $n datasets") || die;

    $source->close;

    for my $dataset ( @datasets ) {
        my $id = $dataset->{id};
        my $file = $dataset->{location};
        my $metadata = $dataset->metadata;
    }



}
    
# my $access_map = $source->{template_handlers}{metadata}{access};

# my $osf = $fixtures->{Osiris};

# DATASET: for my $ds ( @datasets ) {

#     my $path = $ds->{file};

#     # the short_file is not unique so get the last three elements
#     # of the split path.

#     my @bits = split('/', $path);
#     my $file = join('_', splice(@bits, -3));
# 	ok($file , "Got file $file");

#     my $f = $fixtures->{Osiris}{$file};

#     my $md = $ds->metadata;
# 	if( ok($md, "Got metadata") ) {
#         my $f = $fixtures->{Osiris}{$file};

#         my $raw = $ds->{raw_metadata};

# 		like(
# 			$md->{title}, qr/^$raw->{title}/,
# 			"title =~ /^$raw->{title}/"
# 		);

# 		cmp_ok(
# 			$md->{project}, 'eq', $raw->{activity},
# 			"project = activity = $raw->{activity}"
# 		);

#         cmp_ok(
#             $md->{access}, 'eq', $raw->{access},
#             "access = $raw->{access}"
#             );

# 		cmp_ok(
# 			$md->{service}, 'eq', $md->{service},
# 			"service = $raw->{service}"
# 		);

#         my $staff_id = $raw->{creator};

#         my $staff = $fixtures->{STAFF}{$staff_id};

#         for my $field ( qw(staffid mintid name
#             givenname familyname honorific jobtitle groupid) ) {
#             cmp_ok(
#                 $md->{creator}{$field}, 'eq', $staff->{$field},
#                 "creator/$field = $staff->{$field}"
#                 );
#         }



# 		$md->{description} =~ s/\s*$//g;


# 		cmp_ok(
# 			$md->{description}, 'eq', $f->{description},
# 			"<description> content as expected"
#             ) || do {
#                 my $diff = diff \$f->{description}, \$md->{description};
#                 print "DIFF: \n$diff\n";
# 		};
# 	}
    
#     if( ok(my $datastreams = $ds->{datastreams}, "Got datastreams") ) {

#         my $n = scalar keys %$datastreams;
#         my $nf = scalar keys %{$f->{datastreams}};

#         cmp_ok($n, '==', $nf, "Got expected number of datastreams ($nf)");

#         for my $dsid ( keys %$datastreams ) {
#             my $ds = $datastreams->{$dsid};
#             my $fds = $f->{datastreams}{$dsid};
#             if( ok($fds, "Found datastream $dsid in fixtures") ) {
#                 cmp_ok($ds->{original}, 'eq', $fds->{file}, "File = $fds->{file}");
#                 cmp_ok($ds->{mimetype}, 'eq', $fds->{mimetype}, "MIME type = $fds->{mimetype}");
#             }
#         }
        
#     }
    
# 	ok($ds->{datecreated}, "Dataset has datecreated '$ds->{datecreated}'");
    
    
# }


# }


