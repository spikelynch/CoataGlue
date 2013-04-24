package UTSRDC::Dataset;

=head1 NAME

UTSRDC::Dataset

=head1 SYNOPSIS

An object for datasets.  As simple as it can be.

Variables:

=over 4

=item location -> where the data is: a directory, a file, a URL, a physical location
=item metadata -> a hashref of metadata
=item id       -> unique to this datasource.  No colons.
=item source   -> the datasource

=back

=cut

use strict;

use Log::Log4perl;
use Data::Dumper;
use Template;
use XML::Twig;

=head1 METHODS

=over 4

=item new(%params)

Create a new dataset object. All parameters are compulsory:

=over 4

=item source - the UTSRDC::Source (a data capture source)

=item id - a unique ID within this Source.  Any character apart from ':'

=item location - the data itself - can be a filepath or URL

=item metadata - a hashref.  Non-alphanumeric characters in keys are
      converted to underscores.

=back

=cut

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{log} = Log::Log4perl->get_logger($class);
	
	$self->{id}       = $params{id};
	$self->{location} = $params{location};
	$self->{metadata} = $params{metadata};
	$self->{source}   = $params{source};

	my $error = undef;
	for my $field ( qw(id location metadata source) ) {
		if( !$self->{$field} ) {
			$self->{log}->error("Missing field $field in $class");
			$error = 1;
		}
	}
	
	$self->clean_metadata_keys();
	
	if( $self->{id} =~ /:/ ) {
		$self->{log}->error("Dataset IDs can't contain ':'");
		$error = 1;
	}
	
	$self->{global_id} = join(
		':', $self->{source}{name}, $self->{id}
	);
	
	$self->get_status;
	
	if( $error ) {
		return undef;
	}
	
	return $self;
}

=item global_id()

Returns the dataset's global unique ID:

$SOURCE->{name}:$self->{id}

=cut

sub global_id {
	my ( $self ) = @_;
	
	return $self->{global_id};
}


=item clean_metadata_keys()

CLean up the metadata keys so that they can be used as
variables in Template::Toolkit.  Any non-alphanumeric
characters at the end are truncated; all other non-alphanumeric
characters are replaced with underscores.

Throws an error if two keys convert down to the same string.

=cut

sub clean_metadata_keys {
	my ( $self ) = @_;
	
	my $new_metadata = {};
	
	for my $key ( keys %{$self->{metadata}} ) {
		my $value = $self->{metadata}{$key};
		$key =~ s/[^A-Za-z0-9]+$//;
		$key =~ s/[^A-Za-z0-9]/_/g;
		if( exists $new_metadata->{$key} ) {
			$self->{log}->fatal(
				"$self->{id} key collision when cleaning metadata: $key"
			);
			die;
		}
		$new_metadata->{$key} = $value;
	}
	
	$self->{metadata} = $new_metadata;
}


=item xml(view => $view)

Apply the specified xml view to this dataset and return the
results.

=cut

sub xml {
	my ( $self, %params ) = @_;
	
	if( !$params{view} ) {
		$self->{log}->error("xml needs a 'view' parameter");
		return undef;
	}
	
	return $self->{source}->render_view(
		view => $params{view},
		dataset => $self
	);
}





=item get_status()

Returns this dataset's status as a hash:

{
	status => 'new', 'ingested', 'error',
	err_msg => error message if status = 'error'	
}

=cut


sub get_status {
	my ( $self ) = @_;

	$self->{status} = $self->{source}->get_status(dataset => $self);
	
	return $self->{status};
}


=item set_status_ingested

Sets this dataset's status to ingested

=cut

sub set_status_ingested {
	my ( $self ) = @_;
	
	$self->{source}->set_status(
		dataset => $self,
		status => 'ingested',
		details => {
			timestamp => time
		}
	);
}


=item set_status_error

Sets this dataset's status to ingested

=cut

sub set_status_error {
	my ( $self, %params ) = @_;
		
	$self->{source}->set_status(
		dataset => $self,
		status => 'error',
		details => {
			timestamp => time,
			%params
		}
	);
}



1;