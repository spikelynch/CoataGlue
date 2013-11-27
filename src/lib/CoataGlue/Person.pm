package CoataGlue::Person;

=head1 NAME

CoataGlue::Person

=head1 DESCRIPTION

Class representing researchers.  Has code to encrypt staff IDs to form
safe handles, and a method to look up researchers by handle in Mint's solr
index.

=cut

use strict;

use Log::Log4perl;
use Data::Dumper;
use Crypt::Skip32;


our @MANDATORY_PARAMS = qw(source id);



=head1 METHODS

=over 4

=item new(id => $ID, source => $SOURCE, [ %details ])

New is used to create stub Person objects for encrypting IDs.  It is
also used as a kind of mock method to run tests without needing an
operational Mint server.

It needs a staff ID and a CoataGlue::Source, at least.


=cut

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{log} = Log::Log4perl->get_logger($class);

    for my $key ( %params ) {
        $self->{$key} = $params{$key};
    }

    my $error = undef;

    for my $field ( @MANDATORY_PARAMS ) {
        if( !$self->{$field} ) {
            $self->{log}->error("$class requires an id");
            $self->{log}->error("Miscreant responsible: " . join(' ', caller));
            $error = 1;
        }
	}

    if( $error ) {
        return undef;
    }

    my $cg = $self->{source}{coataglue};

    $self->{key} = $cg->conf('Redbox', 'cryptkey');
    $self->{prefix} = $cg->conf('General', 'handles' )
        . $cg->conf('Redbox', 'staffhandle');
    $self->{crosswalk} = $cg->conf('PersonCrosswalk');

	return $self;
}


=item lookup(solr => $solr, id => $id)

Works like 'new' but looks up the details by encrypted staff id in Mint.

=cut


sub lookup {
    my ( $class, %params ) = @_;

    my $self = $class->new(%params);

    if( !$self ) { 

        warn("Need a source and id for lookup");
        return undef;
    }

    my $solr = $self->{source}{coataglue}->mint;

    my $handle = $self->encrypt_id;

    # colons need to be escaped in solr queries

	$handle =~ s/:/\\:/g;

    my $query = join(':', 'dc_identifier', $handle);

    $self->{log}->debug("Solr query: $query");

	my $results = $solr->select(q => $query);
    my $n = undef;
    eval {
        $n = $results->nrSelected;
    };

    if( $@ ) {
        $self->{log}->error("Apache::Solr lookup failed: $@");
        $self->{log}->error("Check that Mint is running and/or the URL is correct");
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


	for my $field ( sort keys %{$self->{crosswalk}} ) {
        my $solrf = $doc->field($self->{crosswalk}->{$field});
        $self->{$field} = $solrf->{content} || '';
	}
	
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
        staffid => $self->{id},
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

    return $creator;
}







=item encrypt_id()

Encrypt a staff ID to put in a handle

=cut


sub encrypt_id {
	my ( $self, %params ) = @_;
	
	if( $self->{key} !~ /^[0-9A-F]{20}$/ ) {
		$self->{log}->error("cryptKey must be a 20-digit hexadecimal number.");
		die("Invalid cryptKey - must be 20-digit hex");
	}

	my $id = $self->{id};	
	
	my $keybytes = pack("H20", $self->{key});
	
	my $cypher = Crypt::Skip32->new($keybytes);
	
	my $plaintext = pack("N", $id);
	my $encrypted = $cypher->encrypt($plaintext);
	$self->{encrypted_id} = unpack("H8", $encrypted);
    if( $self->{prefix} ne 'none' ) {
        $self->{encrypted_id} = $self->{prefix} . $self->{encrypted_id};
    }
	$self->{log}->trace("Encrypted $id to $self->{encrypted_id}");
	return $self->{encrypted_id};
}	

=back

=cut

1;
