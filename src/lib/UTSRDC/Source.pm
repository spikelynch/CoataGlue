package UTSRDC::Source;

use strict;

use Module::Pluggable search_path => [ 'UTSRDC::Source' ], require => 1;
use Log::Log4perl;
use Carp qw(cluck);
use Config::Std;

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{log} = Log::Log4perl->get_logger('UTSRDC.Source');
	
	$self->{conffile} = $params{conf} || do {
		$self->{log}->error("Need to pass URSRDC::Source->new a config file (conf => \$FILE)");
		die;
	};

	
	if( $class eq 'UTSRDC::Source' ) {
		$self->config() || die("Config failed");
		$self->register_sources(%params);
		return $self;
	} else {
		my @classparts = split('::', $class);
		splice(@classparts, 0, 2);
		$self->{name} = join('::', @classparts);
		return $self->init(%params);
	}
}



sub init {
	my ( $self ) = @_;
	
	$self->{log}->error("All UTSRDC::Source subclasses need an init method (" . ref($self) . ")");
	die;
}



sub register_plugins {
	my ( $self, %params ) = @_;
	
	$self->{log}->debug("Registering plugins...");
	
	for my $plugin ( $self->plugins ) {
		
		eval {
			my $p_obj = $plugin->new(%params);
			if( $p_obj ) {
				$self->{plugins}{$p_obj->{name}} = $p_obj;
			}
		};
		if( $@ ) {
			$self->{log}->warn("Source plugin $plugin failed to initialise: $@");
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
	
	if( ref($self) ne 'UTSRDC::Source' ) {
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
