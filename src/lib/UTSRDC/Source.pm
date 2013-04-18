package UTSRDC::Source;

use strict;

use Log::Log4perl;

use UTSRDC::Converter;


=head1 NAME

UTSRDC::Source

=head1 DESCRIPTION

Basic object describing a data source

name      - unique id
converter - A UTSRDC::Converter object (passed in by UTSRDC)
settings  - the config settings (these depend on the Converter)

=cut

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	
	bless $self, $class;

	$self->{log} = Log::Log4perl->get_logger($class);

	my $missing = undef;
	for my $field ( qw(name converter settings) ) {
		$self->{$field} = $params{$field} || do {
			$self->{log}->error("Missing $field for $class");
			$missing = 1;
		}
	}
	
	return $self;
}


sub scan {
	my ( $self ) = @_;
	
	return $self->{converter}->scan();
}

1;