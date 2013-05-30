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



sub add_datastream {
	my ( $self, %params ) = @_;


	my $fc_params = {
		dsID => $params{dsid},
		pid => $params{pid}
	};
	
	if( $params{mimetype} ) {
		$fc_params->{mimeType} = $params{mimetype};
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
		$self->{log}->error("add_datastream needs file, url or xml");
		return undef;
	}
	
	my $repo = $self->repository;
	
	return undef unless $repo;
	
	my $rv = undef;
	
	my $result = $repo->addDatastream(%$fc_params);		

	if( $result->is_ok ) {
		my $content = $result->parse_content;
		$self->{log}->debug("Datastream added");
		return 1;
	} else {
		$self->{log}->error("Error adding datastream: " . $result->error);
		return 0;
	}

#	if( $@ ) {
#		$self->{log}->error("Couldn't add datastream to repository: $@");
#		return 0;
#	} else {
#		$self->{log}->info("Added datastream $params{dsid} to object $self->{repositoryid}");
#	}
	






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


