package CoataGlue;

=head1 NAME

CoataGlue

=head1 DESCRIPTION

Object representing a CoataGlue installation.

=head1 SYNOPSIS

    my $coataglue = CoataGlue->new(
        home      => $CG_HOME_DIR,
	    global    => $CG_GLOBAL_CONF,
	    sources   => $CG_SOURCES_CONF,
	    templates => $CG_TEMPLATES_DIR
    );

    my @sources = $coataglue->sources;

    my $repo = $coataglue->repository;

    my $solr = $coataglue->mint;

=head1 CONFIGURATION

See the Wiki: https://github.com/spikelynch/CoataGlue/wiki/Configuration





=cut


use strict;

use Config::Std;
use Log::Log4perl;
use Data::Dumper;

use Apache::Solr;

use CoataGlue::Repository;


my @MANDATORY_PARAMS = qw(home global sources templates);

my %MANDATORY_CONFIG = (
	General => [ 'timeformat', 'store', 'handles' ],
	Repository => [ 'baseurl', 'username', 'password' ],
	RepositoryCrosswalk => [ 'title', 'description', 'creator', 'date' ],
    Publish => [ 'datastreams',
                 'directory', 'targets',
                 'datastreamurl', 'dataseturl' ],
	Redbox => [ 
        'directory', 'extension', 'staffhandle', 'datasethandle',
        'handlerequest', 'handledir'
    ],
    Mint => [ 'solr', 'core' ]
);


=head1 METHODS

=over 4

=item new(%params)

Create an new CoataGlue object.  Parameters:

=over 4

=item home - CoataGlue installation directory

=item global - The global config file (see CONFIGURATION)

=item sources - The data source config file (see DATA SOURCES)

=item templates - The metadata templates directory (see TEMPLATES)

=back

If either of the config files can't be parsed, returns undef.

If an individual data source's config is unparsable, this will be logged
but the CoataGlue object will be returned.

=cut

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
	
    $self->{home} = $params{home};
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

    $self->expand_conf();

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
	
	$self->{store} = $self->{conf}{global}{General}{store};
	
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
			store => $self->{store},
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


=item sources()

Return an array of all data sources

=cut


sub sources {
	my ( $self ) = @_;
	
	return map { $self->{sources}{$_} } sort keys %{$self->{sources}};
}


=item conf($section, $field)

Return a configuration values

=cut


sub conf {
	my ( $self, $section, $field ) = @_;
	
	if( exists $self->{conf}{global}{$section} ) {
        if( $field ) {
            if ( exists $self->{conf}{global}{$section}{$field} ) {
                return $self->{conf}{global}{$section}{$field};
            } else {
                $self->{log}->error("No config setting '$field' in section '$section'");
                return undef;
            }
        } else {
            return $self->{conf}{global}{$section};
        }
    } else {
		$self->{log}->error("No config section '$section'");
	}
    return undef;
}

=item expand_conf()

Goes through all the config values and expands $COATAGLUE to the value
of $self->{home}

=cut

sub expand_conf {
    my ( $self ) = @_;

    for my $file ( keys %{$self->{conf}} ) {
        for my $section ( keys %{$self->{conf}{$file}} ) {
            for my $field ( keys %{$self->{conf}{$file}{$section}} ) {
                
                if( $self->{conf}{$file}{$section}{$field} =~ s/^\$COATAGLUE/$self->{home}/ ) {
                    $self->{log}->debug("Expanded \$COATAGLUE to $self->{home} in $file/$section/$field");
                }
            }
        }
    }
}

=item template

Obsolete method: template expansion now in CoataGlue::Source

=cut

sub template {
	my ( $self, %params ) = @_;
	
	my $template = $params{template} || do {
		$self->{log}->error("Template filename missing");
		return undef;
	};
	
	$self->{tt} = Template->new();
}

=item repository()

Returns a CoataGlue::Repository object connected to the repository, or
undef if connection fails.

=cut


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


=item repository_crosswalk(metadata => $metadata)

Crosswalks a dataset's metadata into the fields expected by the repository,
based on the RepositoryCrosswalk config section.

=cut


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


=item mint()

Returns an Apache::Solr object for doing lookups in Mint for 
researcher details

=cut

sub mint {
    my ( $self ) = @_;

    if( ! $self->{mint} ) {
        my $mc = $self->{conf}{global}{Mint};

        eval {
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
    return $self->{mint};
}


=back


=cut    



1;
