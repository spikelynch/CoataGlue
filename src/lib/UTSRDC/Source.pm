package UTSRDC::Source;

use strict;

use Log::Log4perl;
use Storable;

use UTSRDC::Converter;


=head1 NAME

UTSRDC::Source

=head1 DESCRIPTION

Basic object describing a data source

name      - unique id
converter - A UTSRDC::Converter object (passed in by UTSRDC)
settings  - the config settings (these depend on the Converter)
store     - the directory where the source histories are kept 

=cut

our $STATUS_NEW      = 'new';
our $STATUS_ERROR    = 'error';
our $STATUS_INGESTED = 'ingested';


sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	
	bless $self, $class;

	$self->{log} = Log::Log4perl->get_logger($class);

	my $missing = undef;
	for my $field ( qw(name converter settings store) ) {
		$self->{$field} = $params{$field} || do {
			$self->{log}->error("Missing $field for $class");
			$missing = 1;
		}
	}
	
	$self->{storefile} = join('/', $self->{store}, $self->{name});
	
	$self->load_history;
	
	return $self;
}

sub load_history {
	my ( $self ) = @_;	
	if( -f $self->{storefile} ) {
		$self->{history} = lock_retrieve($self->{storefile});
	} else {
		$self->{log}->info("Source $self->{name} has no history");
		$self->{history} = {};
	}
}


sub save_history {
	my ( $self ) = @_;
	
	lock_store $self->{history}, $self->{storefile};
}

=item scan

Calls scan on this source's converter and returns all datasets 
which haven't been ingested on a previous pass

=cut

sub scan {
	my ( $self ) = @_;
	
	my @datasets = ();
	
	for my $dataset ( $self->{converter}->scan ) {
		my $status = $self->get_status(dataset => $dataset);
		if( $status->{status} eq 'new ') {
			push @datasets, $dataset;
		}
	}
	return @datasets;
}


=item get_status 

Looks up the status of a dataset in this source's history.  Returns the
'new' status if it's not there.

=cut

sub get_status {
	my ( $self, %params ) = @_;
	
	my $dataset = $params{dataset};
	
	if( !$dataset ) {
		$self->{log}->error("get_status needs a dataset");
		die;
	}
	
	if( $self->{history}{$dataset->{id}} ) {
		return $self->{history}{$dataset->{id}};
	} else {
		return { status => 'new' };
	}
}


sub set_status {
	my ( $self, %params ) = @_;
	
	my $dataset = $params{dataset} || do {
		$self->{log}->error("Can't sest status for empty dataset");
		return undef;
	};
	my $status = { status => $params{status} };
	
	if( $params{details} ) {
		$status->{details} = $params{details};
	}
	
	$self->{history}{$dataset->{id}} = $status;
	$self->save_history;
}



1;