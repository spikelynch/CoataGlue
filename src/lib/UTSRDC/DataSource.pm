package UTSRDC::DataSource;

use strict;

use Module::Pluggable search_path => [ 'UTSRDC::DataSource' ], require => 1;
use Log::Log4perl;
use Carp qw(cluck);
use Config::Std;

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{log} = Log::Log4perl->get_logger('UTSRDC.DataSource');
	
	$self->{conffile} = $params{conf} || do {
		$self->{log}->error("Need to pass URSRDC::DataSource->new a config file (conf => \$FILE)");
		die;
	};

	
	if( $class eq 'UTSRDC::DataSource' ) {
		$self->config() || die("Config failed");
		$self->register_sources(%params);
		return $self;
	} else {
		my @names = split('::', $class);
		splice(@names, 0, 2);   # remove 'UTSRDC::DataSource;
		$self->{name} = join('::', @names);
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
			# when they are instantiated.
			if( $s_obj ) {
				$self->{sources}{$source} = $s_obj;
				my $name = $s_obj->{name};
				if( !$self->{conf}{$name} ) {
					$self->{log}->warn("No config section found for $name");
				} else {
					$self->{sources}{$source}{conf} = $self->{conf}{$name};
				}
			}
		};
		if( $@ ) {
			$self->{log}->warn("DataSource plugin $source failed to initialise: $@");
		}
	}
}

sub sources {
	my ( $self ) = @_;
	
	my @names = sort keys %{$self->{sources}};
	
	my @sources = map { $self->{sources}{$_} } @names;
	
	return @sources;
}

sub config {
	my  ($self, %params ) = @_;
	
	if( ref($self) ne 'UTSRDC::DataSource' ) {
		warn("called read_config on $self");		
		$self->{log}->warn("Called read_config on $self");
		return;
	}
	
	if( !-f $self->{conffile} ) {
		$self->error("Config file $self->{conffile} not found");
		return undef;
	}
	
	
	eval {
		read_config($self->{conffile} => $self->{conf});
	};
	
	if( $@ ) {
		$self->{log}->error("Config file error: $@");
		return undef;
	}
	
	
	return 1;
}



1;