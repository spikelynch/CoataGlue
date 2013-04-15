package UTSRDC::DataSource;

use Module::Pluggable search_path => [ 'UTSRDC::DataSource' ], require => 1;
use Log::Log4perl;

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{log} = Log::Log4perl->get_logger('UTSRDC.DataSource');
	
	if( $class eq 'UTSRDC::DataSource' ) {
		$self->register_sources(%params);
		return $self;
	} else {
		return $self->init(%params);
	}
}



sub init {
	my ( $self ) = @_;
	
	$self->{log}->error("You need to provide an init method for " . ref($self));
	die;
}

sub register_sources {
	my ( $self, %params ) = @_;
	
	$self->{log}->debug("Registering sources...");
	
	my @srcs = $self->plugins;
	
	for my $source ( $self->plugins ) {
		eval {
			my $s_obj = $source->new(%params);
			# 'Abstract' DataSource classes should return undef 
			# when they are instantiatied.
			if( $s_obj ) {
				$self->{sources}{$source} = $s_obj;				
			}
		};
		if( $@ ) {
			$self->{log}->warn("DataSource plugin $source failed to initialise: $@");
		}
	}
}


sub scan {
	my ( $self, %params ) = @_;
	
	$self->{log}->debug("Scanning data sources...");
	
	my @sources = ();
	if( $params{source} ) {
		@sources = ( $params{source} );
	} else {
		@sources = sort keys %{$self->{sources}};
	}
	
	for my $source ( @sources ) {
		$self->{log}->debug("Source $source");
		$self->{sources}{$source}->scan();
	}
}

1;