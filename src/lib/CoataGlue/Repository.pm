package CoataGlue::Repository;

use strict;

use Log::Log4perl;
use Data::Dumper;
use Catmandu::Store::FedoraCommons;
use Catmandu::FedoraCommons;


=head1 NAME

CoataGlue::Repository

=head1 DESCRIPTION

Wrapper around the interface to Fedora, which is kind of messy
because it needs two different Catmandu classes. In the future
this could be the basis of a plugin/adapter setup which allows
other kinds of repositories.

May one day be used by Damyata to look things up.

=head1 SYNOPSIS

    my $repo = CoataGlue::Repository->new(
	    baseurl => $url,
	    usename => $username,
	    password => $password
    );
    
    my $id = $repo->add_object(dataset => $dataset);

	$repo->add_datastream(
		id => $id,
		dsid => $dsid,
		file => $datafile
	);

	$repo->add_datastream(
		id => $id,
		dsid => $dsid,
		url => $dataurl
	);

	$repo->add_datastream(
		id => $id,
		dsid => $dsid,
		xml => $dataxml
	);

	
=cut


our @MANDATORY_PARAMS = qw(baseurl username password);




sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	
	bless $self, $class;
	
	$self->{log} = Log::Log4perl->get_logger($class);
	
	my $missing = 0;
	
	for my $field ( @MANDATORY_PARAMS ) {
		if( !$params{$field} ) {
			$self->{log}->error("Missing $class param $field");
			$missing = 1;
		}
		$self->{$field} = $params{$field};
	}
	
	return $self;
}


sub add_object {
	my ( $self, %params ) = @_;
	
	my $dataset = $params{dataset} || do {
		$self->{log}->error("add_object requires a dataset");
		return undef;
	};
	
	my $store = $self->store || do {
		$self->{log}->error("Couldn't connect to store");
		return undef;
	};
	
	my $metadata = $dataset->metadata;
	
	my $dc = $dataset->{source}->repository_crosswalk(
		metadata => $metadata
	);
	
	# Catmandu::Bag::add expects values to be arrayrefs, and
	# complains if it gets an undef rather than an empty string
	
	for my $field ( keys %$dc ) {
		if( $dc->{$field} ) {
			$dc->{$field} = [ $dc->{$field} ];
		} else {
			$dc->{$field} = [ '' ];
		}
	}

	my $rv;
	
	eval {
		$rv = $store->bag->add($dc);
	};
	
	if( $@ ) {
		$self->{log}->error("Couldn't add object to repository: $@");
		$self->{log}->debug(Dumper({dc => $dc}));
		return 0;
	}
	
	$dataset->{repositoryid} = $rv->{_id};

	return $dataset->{repositoryid};	
	
	
}



sub store {
	my ( $self ) = @_;
	
	if( !$self->{store} ) {
		$self->{store} = Catmandu::Store::FedoraCommons->new(
			baseurl => $self->{baseurl},
			username => $self->{username},
			password => $self->{password},
			model => 'Catmandu::Store::FedoraCommons::DC'
		) || do {
			$self->{log}->fatal("Can't create Catmandu::Store::FedoraCommons instance");
			die;
		};
	}
	
	return $self->{store};
}




sub repository {
	my ( $self ) = @_;
	
	if( !$self->{repository} ) {
		$self->{repository} = Catmandu::FedoraCommons->new(
			baseurl => $self->{baseurl},
			username => $self->{username},
			password => $self->{password},
		) || do {
			$self->{log}->fatal("Can't create Catmandu::FedoraCommons instance");
			die;
		};
	}
	
	return $self->{repository};
}


