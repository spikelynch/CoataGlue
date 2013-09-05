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
=item access         -> who can access it / where it's published

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
use File::Path qw(make_path remove_tree);
use File::Copy;
use Catmandu;
use Catmandu::Store::FedoraCommons;

use CoataGlue::Datastream;
use CoataGlue::IDset;

=head1 METHODS

=over 4

=item new(%params)

Create a new dataset object. All parameters apart from datastreams
are compulsory.

=over 4

=item source - the CoataGlue::Source

=item file - the metadata file - has to be unique for this dataset

=item location - the directory of the dataset (usually contains file)

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
	
	$self->clean_metadata_keys;
	
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
		access => $self->access,
		dateconverted => $self->{dateconverted}
	};
}


sub url {
	my ( $self ) = @_;
	
	my $base = $self->conf('Publish', 'dataseturl');
	
	if( !$self->safe_repository_id ) {
		$self->{log}->warn(
			"repositoryURL failed: no repository_id.  Need to add it to the repository first."
		);
		return undef;
	}
    my $repo = $self->safe_repository_id;
	
	if( $base !~ /\/$/ ) {
		return join('/', $base, $repo);
	} else {
		return join('', $base, $repo);
	}
}


=item safe_repository_id()

This removes the colon from the dataset's repository ID.  Some day we'll
implement a 'get this dataset as a zip' feature and the filenames will
break on Windows if they have colons.  Thanks, Paul.

=cut

sub safe_repository_id {
    my ( $self ) = @_;

    return undef unless $self->{repository_id};

    my $repoid = $self->{repository_id};

    $repoid =~ s/://g;

    return $repoid;
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

    $self->{log}->info("Writing redbox metadata to $file");
	
	open(XMLFILE, ">$file") || do {
		$self->{log}->error("Could not open $file for writing: $!");
		return undef;
	};
	
	print XMLFILE $xml;
	
	close XMLFILE;
	
	return $file;
}



=item publish_urls([to => $audience])

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

If no audience is passed in, the datastream's metadata.access value
is used.

This method also updates the datastreams in the Fedora object
so that they point to the new URLs.

=cut

sub publish {
	my ( $self, %params ) = @_;
	
	if( !$self->{repository_id} ) {
		$self->{log}->error("Can't publish dataset $self->{global_id} - no repository ID")
	}
	
    my $publish_to = $params{to};
    

    if( $publish_to ) {
        if( $publish_to eq $self->access ) {
            $self->{log}->debug("Dataset already published to $params{to}");
        }
    } else {
        $publish_to = $self->access;
    }

    if( !$self->is_publish_target(to => $publish_to) ) {
        $self->{log}->error("Publication target '$publish_to' not found");
        return undef;
    }

	if( !keys %{$self->{datastreams}} ) {
		$self->{log}->error("Dataset $self->{global_id} has no datastreams");
		return undef;
	}
	
	my $old_section = undef;
	
	if( $self->access && $self->access ne $publish_to) {
		$old_section = $self->access;
	}
	
	my $base = $self->conf('Publish', 'directory');
	
	$self->{metadata}{access} = $publish_to;
	
	my $id = $self->safe_repository_id;
	
	my $dir = join('/', $base, $self->{metadata}{access}, $id);
	
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
                return undef;
			}
		}
	}
	
	my @bad_ds = ();

	for my $dsid ( keys %{$self->{datastreams}} ) {
		my $ds = $self->{datastreams}{$dsid};
		my $url = $ds->url;  # this inherits from the dataset's publish
		$ds->write(url => $url) || do {
			$self->{log}->error("Couldn't update datastream $dsid");
            push @bad_ds, $dsid;
		}
	}

    if( @bad_ds ) {
        $self->{log}->error("One or more datastreams not updated");
        return undef;
    }


	return 1;
}



=item access()

Returns the access category of the dateset: basically, who can see
it.  Corresponds to a directory in the web hosting setup.

=cut

sub access {
    my ( $self ) = @_;

    return $self->{metadata}{access}
}


=item is_publish_target(to => $to) 

Returns true if $to is a valid publication target (as defined by
Publish.targets in the global config).


=cut

sub is_publish_target {
    my ( $self, %params ) = @_;

    my $to = $params{to} || return undef;

    for my $target ( split(/ /, $self->{source}->conf('Publish', 'targets') ) ) {
        if( $to eq $target ) {
            return $to
        } 
    }

    return undef;
}




=item xml_filename()

Returns the full path of the xml file built from the source's
ReDBox directory and the dataset's global ID.

=cut

sub xml_filename {
	my ( $self ) = @_;
	
	my $ext = $self->conf('Redbox', 'extension');
	my $dir = $self->conf('Redbox', 'directory');
	
    if( ref($dir) eq 'ARRAY' ) {
        $self->{log}->debug("Dir is array: " . join(', ', @$dir));
    }

	my $filename = join('/', $dir, $self->global_id . '.' . $ext);
    $self->{log}->debug("xml_filename = $filename");
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

Takes a hashref of raw datastreams and uses Dataset::IDset to 
convert the raw keys to values which Fedora Commons will accept.

Then adds Datastream objects with the new ids.

See Dataset::IDset for the details of how IDs are converted.

=cut

sub create_datastreams {
	my ( $self, %params ) = @_;
	
	my $raw = $params{raw} || return undef;
	
	$self->{datastreams} = {};

    my $idset = CoataGlue::IDset->new(raw => $raw);

    my $cooked = $idset->make_ids;

    if( !$cooked ) {
        $self->{log}->debug("Couldn't create unique datastream IDs");
        return undef;
    }
	
    for my $dsid ( sort keys %$cooked ) {
        my $oid = $cooked->{$dsid};
        $self->{datastreams}{$dsid} = CoataGlue::Datastream->new(
            dataset => 	$self,
            id => 		$dsid,
            oid => 		$oid,
            original => $raw->{$oid}{original},
            mimetype => $raw->{$oid}{mimetype},
            label => 	$raw->{$oid}{label}
        ) || do {
            $self->{log}->error("Create datastream failed");
            return undef;
        }
    }

	return $self->{datastreams};
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
