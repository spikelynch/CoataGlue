package UTSRDC;

use Config::Std;
use Log::Log4perl;
use Data::Dumper;




sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	
	bless $self, $class;
	
	$self->{log} = Log::Log4perl->get_logger($class);
	
	if( !$params{conf} ) {
		$self->{log}->error("$class needs a config file");
		die;
	}
	
	$self->{conffile} = $params{conf};
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



1;