package CoataGlue::Person;

=head1 NAME

CoataGlue::Person

=head1 SYNOPSIS

Object for a UTS researcher. Holds the staff ID encryption code.

=cut

use strict;

use Log::Log4perl;
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