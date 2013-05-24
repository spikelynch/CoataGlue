#!/usr/bin/perl

use strict;

use Catmandu;
use Catmandu::Store::FedoraCommons;


my $fc = Catmandu::Store::FedoraCommons->new(
    baseurl => 'http://localhost:8080/fedora',
    username => 'fedoraAdmin',
    password => 'hce39alp',
    model => 'Catmandu::Store::FedoraCommons::DC'
    );

my $obj = {
    title => [ 'Test object title' ],
    creator => [ 'Mike' ]
};

$fc->bag->add($obj);

$fc->bag->each(sub {
    my ( $obj ) = @_;
    my $pid = $obj->{_id};
    
    printf "PID: %s\nTitle: %s\n", $pid, $obj->{title}->[0];

    my $ds = $fc->fedora->listDatastreams(pid => $pid);
    for( @{$ds->{datastream}} ) {
        printf "    %s\n", $_->{dsid};
    }
               });
