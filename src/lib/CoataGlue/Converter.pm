package CoataGlue::Converter;

use strict;

use Module::Pluggable search_path => [ 'CoataGlue::Converter' ], require => 1;
use Log::Log4perl;
use Carp qw(cluck);
use Data::Dumper;
use POSIX qw(strftime);

my $TIMEFORMAT = "%FT%T%z";

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{log} = Log::Log4perl->get_logger($class);
	
	if( $class eq 'CoataGlue::Converter' ) {
		$self->register_plugins(%params);
		return $self;
	} else {
		$self->init(%params);
		return $self;
	}
}



sub init {
	my ( $self ) = @_;
	
	$self->{log}->error("All CoataGlue::Converter subclasses need an init method (" . ref($self) . ")");
	die;
}

sub scan {
	my ( $self ) = @_;
	
	$self->{log}->error("All CoataGlue::Converter subclasses need a scan method (" . ref($self) . ")");
	die;
}


sub register_plugins {
	my ( $self, %params ) = @_;
	
	$self->{log}->debug("Registering plugins...");
	
	for my $plugin ( $self->plugins ) {
		$self->{plugins}{$plugin} = 1;
	}
}


# $converter->converter(converter => $plugin_class, settings => $settings)


sub converter {
	my ( $self, %params  ) = @_;
	
	my $plugin = $params{converter};
	my $settings = $params{settings};
	
	if( $self->{plugins}{$plugin} ) {
		return $plugin->new(%{$settings});
	} else {
		$self->{log}->error("Unknown converter '$plugin'");
		return undef;
	}
}

# Returns the current time in a standard format for all converters

sub timestamp {
	my ( $self ) = @_;
	
	my $format = $self->{source}->conf('General', 'timeformat');
	
	return strftime($format, localtime);
}



1;
