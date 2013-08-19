package CoataGlue::Person;

=head1 NAME

CoataGlue::Person

=head1 SYNOPSIS

Class representing researchers.  Has code to encrypt staff IDs to form
safe handles, and a method to look up researchers by handle in Mint's solr
index.

=cut

use strict;

use Log::Log4perl;
use Data::Dumper;
use Crypt::Skip32;



=head1 METHODS

=over 4

=item new(%params)

New is used to create stub Person objects for encrypting IDs.  It is
also used as a kind of mock method to run tests without needing an
operational Mint server.


=cut

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{log} = Log::Log4perl->get_logger($class);

    for my $key ( %params ) {
        $self->{$key} = $params{$key};
    }

	if( !$self->{id} ) {
		$self->{log}->error("$class requires an id");
		return undef;
	}
	
	return $self;
}


=item lookup(solr => $solr, id => $id)

Works like 'new' but looks up the details by encrypted staff id in Mint.

=cut


sub lookup {
    my ( $class, %params ) = @_;

    my $self = $class->new(%params);

    my $cg = $params{coataglue} || do {
        $self->{log}->error("Person::lookup needs the CoataGlue object");
        return undef;
    };

    my $solr = $cg->mint;

    my $key = $cg->conf('Redbox', 'cryptkey');
    my $prefix = $cg->conf('Redbox', 'handleprefix');
    my $crosswalk = $cg->conf('PersonCrosswalk');

    $self->{coataglue} = $cg;

    $self->encrypt_id(key => $key);

    my $handle;

    # If prefix = 'none', don't use it -  a hack for testing purposes
    
    if( $prefix eq 'none' ) {
        $handle = $self->{encrypted_id};
    } else {
        $handle = $prefix . $self->{encrypted_id};
    }

    # colons need to be escaped in solr queries

	$handle =~ s/:/\\:/g;

    my $query = join(':', 'dc_identifier', $handle);
	my $results = $solr->select(q => $query);
    my $n = undef;
    eval {
        $n = $results->nrSelected;
    };

    if( $@ ) {
        $self->{log}->error("Apache::Solr lookup failed: check that Mint is running.");
        return undef;
    };
    	
	if( !$n ) {
		$self->{log}->warn("Staff handle $handle not found");
		return undef;
	}

	if( $n > 1 ) {
		$self->{log}->warn("More than one Solr index with handle $handle");
	} else {
		$self->{log}->debug("Found a result for $handle");
	}
	
	my $doc = $results->selected(0);


	for my $field ( sort keys %$crosswalk ) {
        my $solrf = $doc->field($crosswalk->{$field});
        $self->{$field} = $solrf->{content} || '';
	}
	
    $self->{log}->debug(">>> encryptedid = $self->{encrypted_id}");
    return $self;
}





=item creator()

Return a $hashref of fields for the <creator> tag in the metadata interchange
format, as follows:

=over 4

=item staffid

=item mintid

=item name

=item givenname

=item familyname

=item honorific

=item name

=cut

sub creator {
    my ( $self ) = @_;

    my $creator = {
        staffid => $self->{staffid},
        mintid => $self->{encrypted_id},
        groupid => $self->{groupid},
        givenname => $self->{givenname},
        familyname => $self->{familyname},
        honorific => $self->{honorific},
        jobtitle => $self->{jobtitle},
        name => join(
            ' ', 
            $self->{honorific}, $self->{givenname}, $self->{familyname}
            )
    };

    $self->{log}->debug(Dumper({creator => $creator}));

    return $creator;
}







=item encrypt_id()

Encrypt a staff ID to put in a handle

=cut


sub encrypt_id {
	my ( $self, %params ) = @_;
	
	my $key = $params{key} || do {
		$self->{log}->error("encrypt_id requires a key");
		return undef;
	};

	if( $key !~ /^[0-9A-F]{20}$/ ) {
		$self->{log}->error("cryptKey must be a 20-digit hexadecimal number.");
		die("Invalid cryptKey - must be 20-digit hex");
	}

	my $id = $self->{id};	
	
	my $keybytes = pack("H20", $key);
	
	my $cypher = Crypt::Skip32->new($keybytes);
	
	my $plaintext = pack("N", $id);
	my $encrypted = $cypher->encrypt($plaintext);
	$self->{encrypted_id} = unpack("H8", $encrypted);
	$self->{log}->debug("Encrypted $id to $self->{encrypted_id}");
	return $self->{encrypted_id};
}	


1;
