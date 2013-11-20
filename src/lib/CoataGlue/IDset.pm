package CoataGlue::IDset;

=head NAME

CoataGlue::IDset

=head DESCRIPTION


A class to convert a set of raw ids into a set of ids which can be
used as datastream IDs in Fedora, and which are still all unique.

Fedora requires that ids be XML NCnames no more than 64 chars.  This
tries to come up with a set of IDs which conform to that rule, which
are still all unique, and which preserve anything that looks like a 
file extension (since this is used to deduce MIME types).

The raw ids are passed in as a hashref with the ids as keys.  The values
of this hashref are ignored.

The make_ids method returns a hashref of newid => oldid (or undef in
the unlikely event that you tried this with 10^64 ids and there was a
collision).

=cut


use XML::RegExp;

our $MAX_DSID_LENGTH = 64;
our $MAX_DSID_EXTENSION = 4;
our $MAX_DSID_SUFFIX = 1000000;

sub new {
    my ( $class, %params ) = @_;

    my $self = {};
    bless $self, $class;

	$self->{log} = Log::Log4perl->get_logger($class);

    $self->{raw} = $params{raw};

    return $self;
}




=item make_ids()

Return a set of clean, unique IDs, or undef if this failed.

=cut

sub make_ids {
    my ( $self ) = @_;

    $self->{ids} = {};

    for my $id ( sort keys %{$self->{raw}} ) {
        $self->add_id(id => $id) || return undef;
    }

    return $self->{ids};
}
    



=item add_id(id => $id)

Adds a raw id to the hash, returns undef if this failed.

=cut

sub add_id {
	my ( $self, %params ) = @_;

	my $id = $params{id};

	$self->{log}->debug("Adding id $id");
	
	my $oid = $id;
    
	# remove and keep the extension, if it exists

	my $ext = undef;
	my $length = $MAX_DSID_LENGTH;
	if( $id =~ /^(.*)\.([^.]*)$/ ) {
		( $id, $ext ) = ( $1, $2 );
		$self->{log}->debug("Split extension $ext");
		$length = $MAX_DSID_LENGTH - (length($ext) + 1);
	} else {
		$self->{log}->debug("Extension not found");
	}
		
	# Replace forbidden characters with '_'
		
	$id =~ s/[^A-Za-z0-9_.]/_/g;
				
	# truncate to the maximum length (allows for extension)
    # this used to truncate from the right, but I'm changing it to
    # truncate from the left: if the datastreams are filenames in a 
    # deep hierarchy or one with very long directory names, truncating
    # the right leads to boring and unhelpful ids.

	if( length($id) > $length ) {
		$id = substr($id, -$length);
	}

	# make sure first character is alphabetical

	if( $id !~ /^[A-Za-z]/ ) {
		$id = 'D' . $id;
	}

    # make sure that it's an NCName

	if( $id !~ /^$XML::RegExp::NCName$/ ) {
		$self->{log}->error("Couldn't make NCName from $oid");
		return undef;
	}


	my $id1 = $id;
	my $inc = 1;
		
	# ...and if it's not unique, just keep appending integers
	# to it and truncating until we get to a ridiculously high
	# number.
		
	while( $self->has_dsid(id => $id, ext => $ext) && $inc < $MAX_DSID_SUFFIX ) {
        $self->{log}->trace("++ $inc");
		$id = substr($id1, 0, $length - length($inc)) . $inc;
		$inc++;
	}
		
	if( $self->has_dsid(id => $id, ext => $ext) ) {
		$self->{log}->error("Couldn't generate unique dataset ID");
		return undef;
	}

    # success - add the new clean id to the {ids} hash, mapping
    # to the original

	my $dsid = $self->dsid(id => $id, ext => $ext);

    $self->{log}->debug("Mapped $oid => $dsid");
    $self->{ids}{$dsid} = $oid;

}

=item has_dsid(id => $id, ext => $ext)

Reassemble the id with dsid and checks if it's already in 
the datastreams hash.

=cut

sub has_dsid {
	my ( $self, %params ) = @_;
	
	my $dsid = $self->dsid(%params);
	
	return exists $self->{ids}{$dsid};
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
	return $dsid;
}

