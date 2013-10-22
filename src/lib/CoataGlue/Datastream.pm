package CoataGlue::Datastream;



=head1 NAME

CoataGlue::Datastream

=head1 SYNOPSIS

An object to represent a datastream - an atomic object (file or
URL).  Datastream is Fedora Core terminology.  A Dataset can
have many datastreams

=over 4

=item original  - The original file (or URL maybe later)

=item id        - the Fedora datastream id - has to be an XML NCNAME
                  no greated than 64 characters
                  
=item label     - a user-friendly label

=item url       - the URL of the datastream as hosted on the web

=item dataset   - link back to the parent dataset

=back 4

When a dataset is created from an ingested object, as many datastreams
as needed are created from whatever the Converter class passes in, and
their IDs are corrected so that they can be used as Fedora dsids.

=cut

use strict;

use Log::Log4perl;
use Carp qw(cluck);
use Data::Dumper;
use File::Path qw(make_path);
use File::Copy;


=head1 METHODS

=over 4

=item new(%params)

Create a new datastream object.

=over 4

=item dataset  - the dataset that owns it

=item original - the original file - has to be unique for this dataset

=item id       - a unique token (within the dataset)

=item oid      - the original id as passed to the Dataset object

=item mimetype - MIME type

=back

=cut

our @MANDATORY_PARAMS = qw(dataset original id mimetype);

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{log} = Log::Log4perl->get_logger($class);

	$self->{log}->debug("New datastream $params{id} mime = $params{mimetype}");

	my $error = undef;
	for my $field ( @MANDATORY_PARAMS ) {
		if( !$params{$field} ) {
			$self->{log}->error("Missing field $field in $class");
			$error = 1;
		}
	}
		
	if( $error ) {
		return undef;
	}

	$self->{dataset}   	= $params{dataset};
	$self->{original} 	= $params{original};
	$self->{mimetype}   = $params{mimetype};
	$self->{id}   		= $params{id};
	$self->{oid}		= $params{oid};

	
	return $self;
}



=item conf

Get config values from the Coataglue object

=cut

sub conf {
	my ( $self, $section, $field ) = @_;
	
	return $self->{dataset}{source}{coataglue}->conf($section, $field);
}



=item url()

Returns this datastream's public URL.  Datastreams have to be in 
a 'section' (public/local/etc) which they always inherit from their
parent dataset

=cut

sub url {
	my ( $self ) = @_;
	
	if( !$self->{dataset}->safe_repository_id ) {
		$self->{log}->error("Can't build a URL - parent dataset has no repository id");
		return undef;
	}
	
	if( !$self->{dataset}->access ) {
		$self->{log}->error("Can't build a URL - dataset has no access setting");
		return undef;
	}
	 
	 
	my $base_url = $self->conf('Publish', 'datastreamurl');

    $self->{log}->debug("Datastream base URL = $base_url");
	
	if( $base_url !~ /\/$/ ) {
		$base_url .= '/';
	}
	
	$self->{url} = $base_url .= join(
		'/',
		$self->{dataset}->access,
		$self->{dataset}->safe_repository_id,
		$self->{id}
	);

    $self->{log}->debug("Full URL = $self->{url}");
	
	return $self->{url};
	
	
}



=item write(%params)

Write the datastream to Fedora, updating any params that 
are passed in. Parameters (all optional)

=over 4

=item xml|file|url
=item label
=item mimetype

=back

=cut

sub write {
	my ( $self, %params ) = @_;

	my $repo = $self->{dataset}{source}->repository;
	
	if( !$repo ) {
		$self->{log}->error("Couldn't get repository");
		return undef;
	}
		
	my $pid = $self->{dataset}{repository_id}; 
	if( !$pid ) {
		$self->{log}->error("Can't add datastream - dataset has no repository_id");
		return undef;
	} 
		
	$self->{log}->debug("Writing datastream $self->{id} to object $pid");	

	my %p = (
		pid => $pid,
		dsid => $self->{id},
		mimetype => $self->{mimetype}
	);
	
	if( $params{file} ) {
		delete $self->{url};
		delete $self->{xml};
		$self->{file} = $params{file}
	} elsif( $params{url} ) {
		delete $self->{file};
		delete $self->{xml};
		$self->{url} = $params{url}
	} elsif( $params{xml} ) {
		delete $self->{file};
		delete $self->{url};
		$self->{xml} = $params{xml};
	}

	
	if( $params{label} ) {
		$self->{label} = $params{label};
	}
	
	$p{label} = $self->{label};
	
	if( $self->{file} ) {
		$p{file} = $self->{file};
	} elsif( $self->{url} ) {
		$p{url} = $self->{url};
	} elsif( $self->{xml} ) {
		$p{xml} = $self->{xml};
	} else {
		$self->{log}->warn("Datastream has no file, url or xml");
		$p{file} = $self->{original};
	}

	return $repo->set_datastream(%p);
}

=item size()

Return the size of this datastream in raw bytes.  Use
Number::Bytes::Human::format_bytes downstream if you need to - it's
not used here so that the sizes can be added for the Dataset manifest

=cut

sub size {
    my ( $self ) = @_;
    
    my $ofile = $self->{original};

    if( ! -f $ofile ) {
        $self->{log}->warn("Couldn't find original file $ofile");
        return 0;
    }

    return -s $ofile;

}


=item format

Returns the file extension (not the MIME-type, which is less useful for
human-readability purposes

=cut

sub format {
    my ( $self ) = @_;

    if( $self->{original} =~ /\.([A-Za-z]+)$/ ) {
        my $format = lc($1);
        return $format;
    } else {
        return 'unknown';
    }
}



1;
