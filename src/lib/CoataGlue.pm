package CoataGlue;
use strict;

use Config::Std;
use Log::Log4perl;
use Data::Dumper;
use Apache::Solr;

use CoataGlue::Repository;


my @MANDATORY_PARAMS = qw(global sources templates);

my %MANDATORY_CONFIG = (
	General => [ 'timeformat' ],
	Store => [ 'store' ],
	Repository => [ 'baseurl', 'username', 'password' ],
	RepositoryCrosswalk => [ 'title', 'description', 'creator', 'date' ],
	Redbox => [ 'directory', 'extension', 'handleprefix' ],
    Mint => [ 'solr', 'core' ]
);


sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	
	bless $self, $class;
	
	$self->{log} = Log::Log4perl->get_logger($class);
	
	my $missing = 0;
	for my $field ( @MANDATORY_PARAMS ) {
		if( !$params{$field} ) {
			$self->{log}->error("$class needs a $field param");
			$missing = 1;			
		}
	}
	
	if( $missing ) {
		$self->{log}->error("Can't continue");
		return undef;
	}
	
	$self->{globalcf} = $params{global};
	$self->{sourcescf} = $params{sources};
	$self->{templates} = $params{templates};
	$self->{log}->debug("Reading config from $self->{conffile}");

	for my $conf ( qw(global sources) ) {
		my $file = $self->{$conf . 'cf'};
		if( !-f $file ) {
			$self->{log}->error("Config file $file not found");
			die;
		}

		eval {
			read_config($file => $self->{conf}{$conf});
		};
		if( $@ ) {
            $self->{log}->error("Error parsing $conf - $file: $@");
            die;
        }
    }

	my $missing = 0;
	for my $section ( keys %MANDATORY_CONFIG ) {
		if( !$self->{conf}{global}{$section} ) {
			$self->{log}->error("Missing section $section from global config");
			$missing = 1;
		} else {
			for my $var ( @{$MANDATORY_CONFIG{$section}} ) {
				if( !$self->{conf}{global}{$section}{$var} ) {
					$self->{log}->error("Missing var $section.$var from global config");
					$missing = 1;
				}
			}
		}
	}
	
	die if $missing;
	
	$self->{store} = $self->{conf}{global}{Store}{store};
	
	$self->{converters} = CoataGlue::Converter->new();
	
	
	SOURCE: for my $name ( keys %{$self->{conf}{sources}} ) {
		my %settings = %{$self->{conf}{sources}{$name}};

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
		
		if( !$settings{ids} ) {
			$self->{log}->error("Data source $name has no ids (ID generator)");
			next SOURCE;
		}
		
		my $source = CoataGlue::Source->new(
			coataglue => $self,
			name => $name,
			store => $self->{conf}{global}{Store}{store},
			converter => $converter,
			ids => $settings{ids},
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

sub conf {
	my ( $self, $section, $field ) = @_;
	
	if( exists $self->{conf}{global}{$section} ) {
        if( $field ) {
            if ( exists $self->{conf}{global}{$section}{$field} ) {
                return $self->{conf}{global}{$section}{$field};
            } else {
                $self->{log}->error("No config setting '$field' in section '$section'");
            }
        } else {
            return $self->{conf}{global}{$section};
        }
    } else {
		$self->{log}->error("No config section '$section'");
	}
    return undef;
}


sub template {
	my ( $self, %params ) = @_;
	
	my $template = $params{template} || do {
		$self->{log}->error("Template filename missing");
		return undef;
	};
	
	$self->{tt} = Template->new();
}


sub repository {
	my ( $self ) = @_;
	
	if( !$self->{repository} ) {
		my $conf = $self->{conf}{global}{Repository};
		$self->{repository} = CoataGlue::Repository->new(
			baseurl => $conf->{baseurl},
			username => $conf->{username},
			password => $conf->{password}
		) || do {
			$self->{log}->fatal("Can't connect to repository:" . Dumper(
				{ conf  => $conf }
			));
			die;
		};
	}
	
	return $self->{repository};
}


sub repository_crosswalk {
	my ( $self, %params ) = @_;
	
	my $metadata = $params{metadata} || do {
		$self->{log}->fatal("Need a metadata to do crosswalk");
		die;
	};
	
	my $dc = {};
	
	my $cw = $self->{conf}{global}{RepositoryCrosswalk};
	
	for my $field ( keys %$cw ) {
		$dc->{$field} = $metadata->{$cw->{$field}};
	}
	
	return $dc;
}

=item mint

Returns an Apache::Solr object for doing lookups in Mint for 
researcher details

=cut

sub mint {
    my ( $self ) = @_;

    $self->{log}->warn("About to get Solr");
    
    if( ! $self->{mint} ) {
        my $mc = $self->{conf}{global}{Mint};

        eval {
            $self->{log}->warn("In eval");
            $self->{mint} = Apache::Solr->new(
                server => $mc->{solr},
                core => $mc->{core}
                );
        };

        if( $@ ) {
            $self->{log}->error("Mint (solr) connection failed: $@");
            return undef;
        } elsif( !$self->{mint} ) {
            $self->{log}->error("Mint (solr) connection returned nothing");
            return undef;
        }
    }
    $self->{log}->warn("Returing $self->{mint}");
    return $self->{mint};
}

    



1;
