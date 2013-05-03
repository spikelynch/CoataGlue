package CoataGlue::Dataset;



=head1 NAME

CoataGlue::Dataset

=head1 SYNOPSIS

CoataGlue's main job is creating metadata records in the RDC for
datasets from a variety of sources (data capture, mostly).  The
CoataGlue::Dataset class represents a single dataset and its
metadata, and has methods for the following useful operations:

=over 4

=item Writing out XML for ReDBox ingest
=item Writing out other XML representations, controlled by a fairly
flexible templating system
=item Adding an object to Fedora representing the dataset
=item Copying the payload to a Fedora-hosted file system when the
data object is published
=back 

Variables:

=over 4

=item file           -> the metadata file
=item location       -> dataset location
=item raw_metadata   -> a hashref of the raw metadata from the
                        Converter
=item metadata       -> the crosswalked metadata
=item id             -> a unique ID, unique to this datasource.
					    No special characters, as it's used to build
					    filename.
=item global_id      -> Source name + id
=item repository_id  -> The ID in Fedora
=item source         -> the datasource name
=item date_converted -> date it was converted

=back

The standard metadata fields are as follows. 

=over 4

=item title
=item description
=item activity
=item service
=item collection_date
=item group
=item creator
=item supervisor
=item share
=item access
=item spatial
=item temporal
=item location

=back


=cut

use strict;

use Log::Log4perl;
use Data::Dumper;
use Template;
use XML::Twig;
use Catmandu;
use Catmandu::Store::FedoraCommons;

=head1 METHODS

=over 4

=item new(%params)

Create a new dataset object. All parameters are compulsory:

=over 4

=item source - the CoataGlue::Source (a data capture source)

=item id - a unique ID within this Source.  Any character apart from ':'

=item location - the data itself - can be a filepath or URL

=item metadata - a hashref of the raw metadata as read by the converter  Non-alphanumeric characters in keys are
      converted to underscores.

=back

=cut

our @MANDATORY_PARAMS = qw(file raw_metadata source);

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{log} = Log::Log4perl->get_logger($class);

	$self->{file} 	  = $params{file};
	$self->{raw_metadata} = $params{raw_metadata};
	$self->{source}   = $params{source};

	my $error = undef;
	for my $field ( @MANDATORY_PARAMS ) {
		if( !$self->{$field} ) {
			$self->{log}->error("Missing field $field in $class");
			$error = 1;
		}
	}
	
	$self->clean_metadata_keys();
	
	$self->get_status;
	
	$self->{log}->debug("Dataset metadata = " . Dumper({metadata => $self->{metadata}}));
	
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

	if( ! $self->{id} ) {
		$self->{log}->error("Can't generate global_id without id");
		return undef;
	}

	if( $self->{id} =~ /\./ ) {
		$self->{log}->error("Dataset IDs can't contain '.'");
		return undef;
	}
	
	$self->{global_id} = join(
		'.', $self->{source}{name}, $self->{id}
	);
	
	$self->{log}->debug("Global ID for dataset $self->{file}: $self->{global_id}");

	
	return $self->{global_id};
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
	
	for my $key ( keys %{$self->{raw_metadata}} ) {
		my $value = $self->{raw_metadata}{$key};
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
	
	$self->{raw_metadata} = $new_metadata;
}


=item metadata()

Crosswalk the raw metadata into the basic metadata fields for FC
or ReDBox and return a hash.

=cut

sub metadata {
	my ( $self ) = @_;
	
	if ( $self->{source}->crosswalk(dataset => $self) ) {
		return $self->{metadata};
	} else {
		return undef;
	}
	
	
}

=item header()

This returns the source, id, repository_id etc.  Metadata about
metadata, which is why it's called 'header'

=cut

sub header {
	my ( $self ) = @_;
	
	return {
		id => $self->{id},
		source => $self->{source}{name},
		file => $self->{file},
		location => $self->{location},
		repositoryid => $self->{repositoryid},
		date_converted => $self->{dateconverted}
	};
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

=item write_redbox

Writes the 'redbox' XML to the redbox directory, using the global_id
as the filename.

=cut


sub write_redbox {
	my ( $self ) = @_;
	
	my $xml = $self->xml(view => 'redbox');
	
	if( !$xml ) {
		$self->{log}->error("Problem creating XML");
		return undef;
	}
	
	my $global_id = $self->global_id;
	if( !$global_id ) {
		$self->{log}->error("Dataset $self->{file} has not got a global_id");
		return undef;	
	}
	
	my $file = $self->xml_filename;
	
	if( -f $file ) {
		$self->{log}->warn("Ingest $file already exists");
		return undef;
	}
	
	open(XMLFILE, ">$file") || do {
		$self->{log}->error("Could not open $file for writing: $!");
		return undef;
	};
	
	print XMLFILE $xml;
	
	close XMLFILE;
	
	return $file;
}


=item xml_filename()

Returns the full path of the xml file built from the source's
ReDBox directory and the dataset's global ID.

=cut

sub xml_filename {
	my ( $self ) = @_;
	
	my $filename = join(
		'/',
		$self->{source}{settings}{redboxdir}, $self->global_id
	) . '.xml';
	
	return $filename;
}

=item add_to_repository()

Create a digital object representing this dataset in the repository
(Fedora Commons for now although we should eventually make it
anything accessible via Catmandu::Store)

=cut

sub add_to_repository {
	my ( $self ) = @_;
	
	
}



1;