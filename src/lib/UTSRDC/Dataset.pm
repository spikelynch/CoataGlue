package UTSRDC::Dataset;

=head1 NAME

UTSRDC::Dataset

=head1 SYNOPSIS

An object for datasets.  As simple as it can be.

Variables:

$location -> where the data is: a directory, a file, a URL, a physical location
$metadata -> a hashref of metadata
$id       -> some sort of unique ID

=cut

use strict;

use Log::Log4perl;

my $LOGGER = 'UTSRDC::Dataset';



Log::Log4perl->init($ENV{RDC_LOG4J});

my $log = Log::Log4perl->get_logger($LOGGER);


sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{id}       = $params{id};
	$self->{location} = $params{location};
	$self->{metadata} = $params{metadata};

	my $error = undef;
	for my $field ( qw(id location metadata) ) {
		if( !$self->{$field} ) {
			$log->error("Missing field $field in $class");
			$error = 1;
		}
	}
	
	if( $error ) {
		return undef;
	}
	
	return $self;
}



sub write_xml {
	my ( $class ) = @_;
	
}