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
=item globalid       -> Source name + id
=item repositoryURL  -> The URL in Fedora
=item source         -> the datasource name
=item datecreated    -> experiment date from the source
=item dateconverted  -> date it was converted
=item datastreams    -> an arrayref of payloads (files or URLs)

=back

The standard metadata fields are as follows. 

=over 4

=item title
=item description
=item activity
=item service
=item creationdate
=item collectiondate
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
use Carp qw(cluck);
use Data::Dumper;
use Template;
use XML::Twig;
use XML::RegExp;
use Catmandu;
use Catmandu::Store::FedoraCommons;

our $MAX_DSID_LENGTH = 64;
our $MAX_DSID_SUFFIX = 1000000;

=head1 METHODS

=over 4

=item new(%params)

Create a new dataset object. All parameters apart from datastreams
are compulsory.

=over 4

=item source - the CoataGlue::Source

=item file - the metadata file - has to be unique for this dataset

=item raw_metadata - a hashref of the raw metadata as read by the converter
      Non-alphanumeric characters in keys are converted to underscores.
      
=item datastreams - an arrayref of payloads hashrefs which should have the following:

=over 4

=item file or xml or url

=item id - a unique string (first character must be [A-Za-z]) 

=item mimetype - optional

=back


=back

=cut

our @MANDATORY_PARAMS = qw(file raw_metadata source);

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{log} = Log::Log4perl->get_logger($class);

	$self->{file}   = $params{file};
	$self->{raw_metadata} = $params{raw_metadata};
	$self->{source}   = $params{source};
	$self->{dateconverted} = $self->{raw_metadata}{dateconverted};
	
	
	if( $params{datastreams} ) {
		$self->{datastreams} = $params{datastreams};
	}

	my $error = undef;
	for my $field ( @MANDATORY_PARAMS ) {
		if( !$self->{$field} ) {
			$self->{log}->error("Missing field $field in $class");
			$error = 1;
		}
	}
	
	$self->clean_metadata_keys();
	
	$self->get_status;
	

	if( $error ) {
		return undef;
	}
	if( $self->{datastreams} ) {
		$self->{log}->debug("Dataset $self $self->{file} has datastreams"); 
		$self->{log}->debug(Dumper({datastreams => $params{datastreams}}));
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

Sets this dataset's status to error

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
chesapeake bay bridge
=cut

sub header {
	my ( $self ) = @_;
	
	return {
		id => $self->{id},
		source => $self->{source}{name},
		file => $self->{file},
		location => $self->{location},
		repositoryURL => $self->repositoryURL,
		dateconverted => $self->{dateconverted}
	};
}


sub repositoryURL {
	my ( $self ) = @_;
	
	my $base = $self->{source}->conf('Repository', 'publishurl');
	
	if( $base !~ /\/$/ ) {
		return join('/', $base, $self->{repositoryid});
	} else {
		return join('', $base, $self->{repositoryid});
	}
}



=item xml(view => $view)

Apply the specified xml view to this dataset and return the
results.  The default view is 'metadata'

=cut

sub xml {
	my ( $self, %params ) = @_;
	
	my $view = $params{view};
	
	if( !$view ) {
		$self->{log}->info("Default view: metadata");
		$view = 'metadata'
	};
	
	return $self->{source}->render_view(
		view => $view,
		dataset => $self
	);
}

=item write_redbox

Writes the 'redbox' XML to the redbox directory, using the global_id
as the filename.

=cut


sub write_redbox {
	my ( $self ) = @_;
	
	my $xml = $self->xml;
	
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
	
	my $ext = $self->{source}->conf('Redbox', 'extension');
	my $dir = $self->{source}->conf('Redbox', 'directory');
	
	my $filename = join('/', $dir, $self->global_id . '.' . $ext);
	return $filename;
}

=item add_to_repository()

Create a digital object representing this dataset in the repository
(Fedora Commons for now although we should eventually make it
anything accessible via Catmandu::Store)

=cut

sub add_to_repository {
	my ( $self ) = @_;

	my $repo = $self->{source}->repository;
	
	if( !$repo ) {
		$self->{log}->error("Couldn't get repository");
		return 0;
	}
	
	if( !$repo->add_object(dataset => $self) ) {
		$self->{log}->error("Adding dataset failed");
		return 0
	} else {
		return $self->{repositoryid};
	}

}


=item add_datastream(%params)

Add a payload to the Fedora digital object.

The content can be a filename, a URL or a scalar containing XML.

Returns undef if it was unsuccessful.

The datastreams from the converter aren't used for this as 
the calling script may well do something with them (like copying
them to a web server directory and translating them into URLs)
before they are added as datastreams.

Parameters:

=over 4

=item xml|file|url
=item id
=item label
=item mimetype

=back

One of xml/file/url, and dsid, are compulsory. 

=cut

sub add_datastream {
	my ( $self, %params ) = @_;

	my $repo = $self->{source}->repository;
	
	if( !$repo ) {
		$self->{log}->error("Couldn't get repository");
		return undef;
	}
		
	if( !$params{id} ) {
		$self->{log}->error("Need a datastream id");
		return undef;
	}
	
	if( !$self->{repositoryid} ) {
		$self->{log}->error("Can't add datastream - dataset has no repositoryid");
		return undef;
	}
	
	if( $params{id} !~ /^$XML::RegExp::NCName$/ ) {
		$self->{log}->error("dsID '$params{id}' is invalid - must be an XML NCName (no colons, first char [A-Za-z])");
		return undef;
	}
	
	$self->{log}->debug("Adding datastream $params{dsid} to object $self->{repositoryid}");	
	my %p = (
		pid => $self->{repositoryid},
		dsid => $params{id}
	);
	
	if( $params{file} ) {
		$p{file} = $params{file}
	} elsif( $params{url} ) {
		$p{url} = $params{url}
	} elsif( $params{xml} ) {
		$p{xml} = $params{xml};
	} else {
		$self->{log}->error("add_datastream needs a file, url or xml");
		return undef;
	}
	
	if( $params{mimetype} ) {
		$p{mimetype} = $params{mimetype};
	}
	
	if( $params{label} ) {
		$p{dsLabel} = $params{label};
	}
	
	
	return $repo->add_datastream(%p);
}


=item fix_datastream_ids($datastream)

Goes through the $self->{datastreams} hash and ensures that all
of the IDs are compliant with Fedora's requirements (XML NCnames
no more than 64 chars)

Will throw an error if it can't generate unique IDs, otherwise
returns a hash of the datastreams by the new ids (with the original
ID stored in old_id)

=cut

sub fix_datastream_ids {
	my ( $self ) = @_;
	
	my $newids = {};
	
	for my $id ( sort keys %{$self->{datastreams}} ) {
		
		my $oid = $id;
		# first replace forbidden characters with '_'
		
		#$id =~ s/[ :$&\/+,;?]/_/g;
		$id =~ s/[^A-Za-z0-9_.]/_/g;
		
		# make sure first character is alphabetical
		if( $id !~ /^[A-Za-z]/ ) {
			$id = 'D' . $id;
		}

		if( $id !~ /^$XML::RegExp::NCName$/ ) {
			$self->{log}->error("Couldn't make NCName from $oid");
			return undef;
		}
		
		# truncate to 64 chars...
		if( length($id) > $MAX_DSID_LENGTH ) {
			$id = substr($id, 0, $MAX_DSID_LENGTH);
		}
		my $id1 = $id;
		my $inc = 1;
		
		# ...and if it's not unique, just keep appending integers
		# to it and truncating until we get to a ridiculously high
		# number.
		
		while( $newids->{$id} && $inc < $MAX_DSID_SUFFIX ) {
			$id = substr($id1, 0, $MAX_DSID_LENGTH - length($inc)) . $inc;
			$inc++;
		}
		if( $newids->{$id} ) {
			$self->{log}->error("Couldn't generate unique dataset ID");
			return undef;
		}
		$newids->{$id} = $self->{datastreams}{$oid};
		$newids->{$id}{id} = $id;
		$newids->{$id}{old_id} = $oid;
	}
	return $newids;
}



1;
