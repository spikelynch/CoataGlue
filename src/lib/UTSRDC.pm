package UTSRDC;

use strict;

use Config::Std;
use Log::Log4perl;
use Data::Dumper;




sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	
	bless $self, $class;
	
	$self->{log} = Log::Log4perl->get_logger($class);
	
	if( !$params{config} || !$params{templates}) {
		$self->{log}->error("$class needs parameters conf (a file) and templates (a directory)");
		die;
	}
	
	$self->{conffile} = $params{config};
	$self->{templates} = $params{templates};
	$self->{log}->debug("Reading config from $self->{conffile}");

	if( !-f $self->{conffile} ) {
		$self->{log}->error("Config file $self->{conffile} not found");
		die;
	}
		
	eval {
		read_config($self->{conffile} => $self->{conf});
	};
	
	if( $@ ) {
		$self->{log}->error("Config file error: $@");
		die;
	}
	
	# Global settings are stored with a hash key of '' - only
	# the store directory so far.

	$self->{store} = $self->{conf}{''}{store} || do {
		$self->{log}->error("No store directory defined in config");
		die;
	};
	
	delete $self->{conf}{''};

	$self->{converters} = UTSRDC::Converter->new();
	
	
	SOURCE: for my $name ( keys %{$self->{conf}} ) {
		my %settings = %{$self->{conf}{$name}};

		my $convclass = $settings{converter};
		if( !$convclass ) {
			$self->{log}->error("Data source $name has no converter");
			next SOURCE;
		}
		delete $settings{converter};
		my $converter = $self->{converters}->converter(
			converter => $convclass,
			settings => \%settings
		);
		my $source = UTSRDC::Source->new(
			name => $name,
			store => $self->{store},
			converter => $converter,
			settings => \%settings
		);
		if( $source ) {
			$self->{sources}{$name} = $source;
		} else {
			# If the config is screwed, $source will be empty, but
			# we don't want to bail out of everything.
			$self->{log}->error("Source '$name' could not be initialised");
		}
	}
	
	return $self;
}



sub sources {
	my ( $self ) = @_;
	
	return map { $self->{sources}{$_} } sort keys %{$self->{sources}};
}

sub template {
	my ( $self, %params ) = @_;
	
	my $template = $params{template} || do {
		$self->{log}->error("Template filename missing");
		return undef;
	};
	
	$self->{tt} = Template->new();
}



1;