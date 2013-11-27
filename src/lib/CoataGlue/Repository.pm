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

	$repo->set_datastream(
		id => $id,
		dsid => $dsid,
		file => $datafile
	);

	$repo->set_datastream(
		id => $id,
		dsid => $dsid,
		url => $dataurl
	);

	$repo->set_datastream(
		id => $id,
		dsid => $dsid,
		xml => $dataxml
	);

	
=cut


our @MANDATORY_PARAMS = qw(baseurl username password);


=head1 METHODS

=item new(baseurl => $url, username => $username, password => $password)

Create a new object; returns undef if any of the parameters are missing.

=cut


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


=item add_object(dataset => $dataset)

Creates a new Fedora object for the dataset, populates the dublin core
metadata and returns the repository id for the new object if succesful.

=cut



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
	
    $self->{log}->debug("About to add dataset to repository: " . Dumper({ dc => $dc}));

	eval {
		$rv = $store->bag->add($dc);
	};
	
	if( $@ ) {
		$self->{log}->error("Couldn't add object to repository: $@");
		return 0;
	}
	
	$dataset->{repository_id} = $rv->{_id};

	return $dataset->{repository_id};	
	
	
}


=item set_datastream(%params)

Add or rewrite a datastream on a Fedora object. Parameters are

=over 4

=item pid - the dataset's Fedora ID

=item dsid - the datastream ID, which has to conform to Fedora's rules

=back

The CoataGlue::IDset class is a utility for cleaning up sets of ids so that
they can be used as Fedora ids.


=cut


sub set_datastream {
	my ( $self, %params ) = @_;


	my $fc_params = {
		dsID => $params{dsid},
		pid => $params{pid}
	};
	
	if( $params{mimetype} ) {
		$fc_params->{mimeType} = $params{mimetype};
	} else {
		$self->{log}->warn("Datastream $params{pid}/$params{dsid} being written with no mimetype");
	}
	
	if( $params{label}) {
		$fc_params->{dsLabel} = $params{label};
	}

	if( $params{file} ) {
		if( -f $params{file} ) {
			$fc_params->{file} = $params{file};
			$self->{log}->debug("Loading datastream from file $params{file}");
		} else {
			$self->{log}->error("File $params{file} not found");
			return undef;
		}
	} elsif( $params{url} ) {
		$fc_params->{url} = $params{url};
		$self->{log}->debug("Loading datastream from url $params{url}");
	} elsif( $params{xml} ) {
		$fc_params->{xml} = $params{xml};
	} else {
		$self->{log}->error("set_datastream needs file, url or xml");
		return undef;
	}
	
	my $repo = $self->repository;
	
	return undef unless $repo;
	
	my $rv = undef;
	
	my $result = $repo->addDatastream(%$fc_params);		

	if( $result->is_ok ) {
		my $content = $result->parse_content;
		return 1;
	} else {
		$self->{log}->error("Error adding datastream: " . $result->error);
		return 0;
	}

}


=item store

Return a Catmandu::Store object for this repository.

=cut


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


=item repository

Return a Catmandu::FedoraCommons object for the repository

=cut


sub repository {
	my ( $self ) = @_;
	
	if( !$self->{repository} ) {
		$self->{repository} = Catmandu::FedoraCommons->new(
			$self->{baseurl},
			$self->{username},
			$self->{password}
		) || do {
			$self->{log}->fatal("Can't create Catmandu::FedoraCommons instance");
			die;
		};
	}
	
	return $self->{repository};
}

=back

=cut

1;
