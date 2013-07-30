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
=item location       -> dataset location (a directory in a filesystem)
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
=item published      -> which section the dataset has been published to 

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
use File::Path qw(make_path);
use File::Copy;
use XML::RegExp;
use Catmandu;
use Catmandu::Store::FedoraCommons;

use CoataGlue::Datastream;

our $MAX_DSID_LENGTH = 64;
our $MAX_DSID_EXTENSION = 4;
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

our @MANDATORY_PARAMS = qw(file location raw_metadata source);

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{log} = Log::Log4perl->get_logger($class);

	$self->{file}   = $params{file};
	$self->{location} = $params{location};
	$self->{raw_metadata} = $params{raw_metadata};
	$self->{source}   = $params{source};
	$self->{dateconverted} = $self->{raw_metadata}{dateconverted};
	
	
	if( $params{datastreams} ) {
		$self->create_datastreams(raw => $params{datastreams}) || do {
			$self->{log}->error("Error creating datastreams");
			return undef;
		}
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




=item short_file()

Returns the filename relative to the capture directory

=cut

sub short_file {
	my ( $self ) = @_;
	
	my @parts = reverse split(/\//, $self->{file});
	return $parts[0];
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
=cut

sub header {
	my ( $self ) = @_;
	
	return {
		id => $self->{id},
		source => $self->{source}{name},
		file => $self->{file},
		location => $self->{location},
		repositoryURL => $self->url,
		publish => $self->{publish},
		dateconverted => $self->{dateconverted}
	};
}


sub url {
	my ( $self ) = @_;
	
	my $base = $self->conf('Publish', 'dataseturl');
	
	if( !$self->{repository_id} ) {
		$self->{log}->warn(
			"repositoryURL failed: no repository_id.  Need to add it to the repository first."
		);
		return undef;
	}
	
	if( $base !~ /\/$/ ) {
		return join('/', $base, $self->{repository_id});
	} else {
		return join('', $base, $self->{repository_id});
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
	
	if( !$self->{repository_id} ) {
		$self->{log}->warn("The dataset needs to be added to Fedora before writing XML to ReDBox.");;
	}
	
	my $xml = $self->xml;
	
	if( !$xml ) {
		$self->{log}->error("Problem creating XML");
		return undef;
	}
	
	my $global_id = $self->global_id;
	if( !$global_id ) {
		$self->{log}->error("Dataset $self->{file} doesn't have a global_id");
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



=item publish_urls(to => [$audience])

Version of the publish method where hosted datastreams are stored
in a filesystem and pushed into Fedora as URLs.  For this to work,
the datastreams need to be available on the web as served by 
Damyata before they are pushed into Fedora.

Copies this dataset to the requested 'audience'.  An audience 
is a directory in the base web publishing director with one
set of authentication rules (ie UTS only, AAF, public etc):

    ...dancer app/public/data/$audience/$pid/$dsid.$ext
    
A dataset can only be in one of these folders, so if the 
publication status changes, it's deleted from the current
one after it's been successfully added to the new one.

This method also updates the datastreams in the Fedora object
so that they point to the new URLs.

We need to add the extension $ext so that Damyata can set the 
mime type when serving the file.

=cut

sub publish {
	my ( $self, %params ) = @_;
	
	if( !$self->{repository_id} ) {
		$self->{log}->error("Can't publish dataset $self->{global_id} - no repository ID")
	}
	
	my $publish_to = $params{to} || do {
		$self->{log}->error("Publish needs a 'to' param");
		return undef;
	};
	
	if( !keys %{$self->{datastreams}} ) {
		$self->{log}->error("Dataset $self->{global_id} has no datastreams");
		return undef;
	}
	
	my $old_section = undef;
	
	if( $self->{publish} ) {
		$old_section = $self->{publish};
	}
	
	my $base = $self->conf('Publish', 'directory');
	
	$self->{publish} = $publish_to;
	
	my $id = $self->{repository_id};
	
	my $dir = join('/', $base, $self->{publish}, $id);
	
	eval {
		make_path($dir);
	};
	
	if( $@ ) {
		$self->{log}->error("Couldn't make path $dir: $@");
		return undef;
	}
	
	my $error = 0;
	
	for my $dsid ( keys %{$self->{datastreams}} ) {
		my $ds = $self->{datastreams}{$dsid};
		my $dest = "$dir/$dsid";
		copy($ds->{original}, $dest) || do {
			$self->{log}->error("Couldn't copy $ds->{file} to $dest: $!");
			$error = 1;
		}
	}
	if ( $error ) {
		$self->{log}->warn("Incomplete copy of $self->{global_id} to $dir");
		if( $old_section ) {
			$self->{log}->warn("Copy of datastreams may still be in $old_section");
		}
		return undef;
	}
	
	if( $old_section ) {
		my $old_dir = join('/', $base, $old_section, $id);
		if( -d $old_dir ) {
			eval {
				remove_tree($old_dir);
			};
			if( $@ ) {
				$self->{log}->error("Removing $old_dir failed: $@");
			}
		}
	}
	
	
#	my $base_url = $self->conf('Repository', 'publishurl');
#	$base_url = join('/', $base_url, $section, $id);
#	
#	for my $dsid ( keys %{$self->{datastreams}} ) {
#		$self->{datastreams}{$dsid}->write(
#			section => $section
#		)
#		$self->{datastreams}{$dsid}->write(
#			url => "$base_url/$dsid"
#		) || do {
#			$self->{log}->error("Couldn't update datastream $dsid");
#		}
#	}

	for my $dsid ( keys %{$self->{datastreams}} ) {
		my $ds = $self->{datastreams}{$dsid};
		my $url = $ds->url;  # this inherits from the dataset's publish
		$ds->write(url => $url) || do {
			$self->{log}->error("Couldn't update datastream $dsid")
		}
	}


	return 1;
}









=item xml_filename()

Returns the full path of the xml file built from the source's
ReDBox directory and the dataset's global ID.

=cut

sub xml_filename {
	my ( $self ) = @_;
	
	my $ext = $self->conf('Redbox', 'extension');
	my $dir = $self->conf('Redbox', 'directory');
	
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
		return $self->{repository_id};
	}

}




=item create_datastreams(raw => $hashref)

Goes through the $self->{datastreams} hash and ensures that all
of the IDs are compliant with Fedora's requirements (XML NCnames
no more than 64 chars), then creates CoataGlue::Datastream objects
for them.

Will throw an error if it can't generate unique IDs, otherwise
returns a hash of the datastreams by the new ids (with the original
ID stored in old_id)

Modified so that it preserves file extensions.

=cut

sub create_datastreams {
	my ( $self, %params ) = @_;
	
	my $raw = $params{raw} || return undef;
	
	$self->{datastreams} = {};
	
	for my $id ( sort keys %$raw ) {
		if( !$self->add_datastream(id => $id, datastream => $raw->{$id} ) ) {
			return undef;
		}
	}
	return $self->{datastreams};
}


=item add_datastream(id => $id, datastream => $ds)

Tries to add a datastream to the hash, fixing the id if required.
Returns undef if it couldn't be truncated andd uniquified.

=cut


sub add_datastream {
	my ( $self, %params ) = @_;

	my $id = $params{id};
	my $raw = $params{datastream};	

	$self->{log}->debug("Adding datastream $id");
	
	my $oid = $id;

	# remove and keep the extension, if it exists

	my $ext = undef;
	my $length = $MAX_DSID_LENGTH;
	if( $id =~ /^(.*)\.([^.]*)$/ ) {
		( $id, $ext ) = ( $1, $2 );
		#$self->{log}->debug("Split extension $ext");
		$length = $MAX_DSID_LENGTH - (length($ext) + 1);
	} else {
		$self->{log}->debug("Extension not found");
	}
		
	# Replace forbidden characters with '_'
		
	$id =~ s/[^A-Za-z0-9_.]/_/g;
		
	# make sure first character is alphabetical
	if( $id !~ /^[A-Za-z]/ ) {
		$id = 'D' . $id;
	}

	if( $id !~ /^$XML::RegExp::NCName$/ ) {
		$self->{log}->error("Couldn't make NCName from $oid");
		return undef;
	}
		
	# truncate to the maximum length (allows for extension)
	if( length($id) > $length ) {
		$id = substr($id, 0, $length);
	}
	my $id1 = $id;
	my $inc = 1;
		
	# ...and if it's not unique, just keep appending integers
	# to it and truncating until we get to a ridiculously high
	# number.
		
	while( $self->has_dsid(id => $id, ext => $ext) && $inc < $MAX_DSID_SUFFIX ) {
		$id = substr($id1, 0, $length - length($inc)) . $inc;
		$inc++;
	}
		
	if( $self->has_dsid(id => $id, ext => $ext) ) {
		$self->{log}->error("Couldn't generate unique dataset ID");
		return undef;
	}
	my $dsid = $self->dsid(id => $id, ext => $ext);
	$self->{log}->debug("Adding datastream $dsid");
	$self->{log}->debug("raw datastream:"  . Dumper($raw));
	$self->{datastreams}{$dsid} = CoataGlue::Datastream->new(
		dataset => 	$self,
		id => 		$dsid,
		oid => 		$oid,
		original => $raw->{original},
		mimetype => $raw->{mimetype},
		label => 	$raw->{label}
	) || do {
		$self->{log}->error("Create datastream failed");
		return undef;
	};
	return 1;
}


=item has_dsid(id => $id, ext => $ext)

Reassemble the id with dsid and checks if it's already in 
the datastreams hash.

=cut

sub has_dsid {
	my ( $self, %params ) = @_;
	
	my $dsid = $self->dsid(%params);
	
	return exists $self->{datastreams}{$dsid};
}


=item dsid(id => $id, ext => $ext)

Utility to reassemble an id and the file extension. Returns
"$id.$ext" if $ext is defined, otherwise just returns $id

=cut

sub dsid {
	my ( $self, %params ) = @_;
	
	my $dsid = $params{id};
	if( $params{ext} ) {
		 $dsid .= '.' . $params{ext};
	}
	#$self->{log}->debug("dsid: $params{id}/$params{ext} = $dsid");
	return $dsid;
}



=item datastreams

Returns a hash of datastreams by id - the ids are not the original
ids but the cleaned-up, Fedora-safe ones.

=cut

sub datastreams {
	my ( $self ) = @_;
	
	return $self->{datastreams};
	
}



=item conf

Get config values from the Coataglue object

=cut

sub conf {
	my ( $self, $section, $field ) = @_;
	
	return $self->{source}{coataglue}->conf($section, $field);
}




1;
