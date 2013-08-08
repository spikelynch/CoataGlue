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



=cut

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{log} = Log::Log4perl->get_logger($class);

	$self->{id}   = $params{id} || do {
		$self->{log}->error("$class requires an id");
		return undef;
	};
	
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

    $self->encrypt_id(key => $key);

    $self->{log}->debug("Encrypted id = $self->{encrypted_id}");
    
    my $handle = $self->{encrypted_id};
    my $query = join(':', 'dc_identifier', $handle);
	my $results = $solr->select(q => $query);
	
	my $n = $results->nrSelected;
	
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

	for my $field ( keys %$crosswalk ) {
        my $solrf = $doc->field($crosswalk->{$field});
        $self->{$field} = $solrf->{content} || '';
	}
	
    return $self;
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
