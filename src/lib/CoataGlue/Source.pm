package CoataGlue::Source;

use strict;

use Carp qw(cluck);

use Log::Log4perl;
use Storable qw(lock_store lock_retrieve);
use Data::Dumper;
use Config::Std;
use XML::Writer;
use Template;
use POSIX qw(strftime);

use CoataGlue::Converter;
use CoataGlue::ID::NaiveSequence;
use CoataGlue::Person;

=head1 NAME

CoataGlue::Source

=head1 DESCRIPTION

Basic object describing a data source

name      - unique id
converter - A CoataGlue::Converter object (passed in by CoataGlue)
settings  - the config settings (some of which depend on the Converter)
store     - the directory where the source histories are kept 

=head1 SYNOPSIS

    my @sources = $CoataGlue->sources;
    
    for my $source ( @sources ) {
    	my @datasets = $source->scan;
    	
    	for my $ds ( @datasets ) {
    		if( $ds->write_xml ) { 
 		   		$ds->set_status_ingested()
    		} else {
    			$ds->set_status_error();
    		}
    	}
    }
    
=head1 STATUS

Each source has a history file in the store/ directory which keeps
track of the status of each dataset which has been scanned. The
process works like this:



- The $source->scan() function uses the Converter object to 
  scan whatever it scans (a directory within a directory, in
  FolderCSV). The Converter gets datasets with a unique-to-
  this-source string, typically a filepath.  
  
- The Source then gets an exclusive lock on its history file,
  reads it, and looks up all the scanned datasets by their
  filepath.  If they have already been ingested or have raised
  errors, it ignores them.  The remaining datasets are new,
  and get new IDs from the ID generator class (these are 
  unique IDs which can be used as filenames).
  
- The Source passes the list of datasets back to the calling
  code, which will attempt to Do Things (write out the XML
  and add the datasets to Fedora etc).  Based on how successful
  this is, the calling code sets the status for each dataset,
  and the Source writes the status into the history
  
- At the end of this process, the calling code 
  should call $source->close - which writes the history file
  and releases the lock
  
- 

=cut

our $STATUS_NEW      = 'new';
our $STATUS_ERROR    = 'error';
our $STATUS_INGESTED = 'ingested';

our @MANDATORY_PARAMS = qw(coataglue name converter ids settings store);

our @MANDATORY_SETTINGS = qw(templates);


sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	
	bless $self, $class;

	$self->{log} = Log::Log4perl->get_logger($class);

	my $missing = undef;
	for my $field ( @MANDATORY_PARAMS ) {
		$self->{$field} = $params{$field} || do {
			$self->{log}->error("Missing $field for $class");
			$missing = 1;
		}
	}
		
	for my $field ( @MANDATORY_SETTINGS ) {
		if( ! exists $self->{settings}{$field} ) {
			$self->{log}->error("Missing field $field in settings for $class $self->{name}");
			$missing = 1;
		}
	}
	
	if( $missing ) {
		return undef;
	}
	
	# add this source to its converter so that the converter
	# can do status lookups etc.

	$self->{converter}{source} = $self;

	$self->{ids} = $self->{ids}->new(source => $self);
	
	$self->{storefile} = join('/', $self->{store}, $self->{name});
	$self->{locked} = 0;
	$self->load_templates;
	
	return $self;
}


=item open

This reads the Source's history file with an exclusive lock, 
so if any other processes try to scan this source, they'll have
to wait.

=cut

sub open {
	my ( $self ) = @_;	
	if( !-f $self->{storefile} ) {
		$self->{log}->info("Empty history for $self->{name}");
		$self->{history} = {};
		lock_store $self->{history}, $self->{storefile};
	}
	$self->{log}->debug("Loading history $self->{storefile}");
	$self->{locked} = 1;
	$self->{history} = lock_retrieve($self->{storefile});
	return $self->{history};
}

=item close

Saves the source's history hash to the store file and releases the
lock.

=cut


sub close {
	my ( $self ) = @_;
	
	lock_store $self->{history}, $self->{storefile};
	$self->{locked} = 0;
	
	return 1;
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
	
	if( $self->{history}{$dataset->{file}} ) {

		return $self->{history}{$dataset->{file}};
	} else {
		$self->{log}->debug(
			"Dataset not in history (file = $dataset->{file})"
		);
		
		return {
			status => 'new'
		}
	}
}


sub set_status {
	my ( $self, %params ) = @_;
	
	my $dataset = $params{dataset} || do {
		$self->{log}->error("Can't set status for empty dataset");
		return undef;
	};
	
	if( !$dataset->{file} || !$dataset->{id} ) {
		$self->{log}->error("dataset needs 'file' and 'id', can't set status");
		$self->{log}->error(Dumper({ dataset => $dataset }));
		return undef;
	}
	
	
	my $status = {
		status => $params{status},
		id => $dataset->{id}
	};
	
	
	if( $params{details} ) {
		$status->{details} = $params{details};
	}
	
	$self->{history}{$dataset->{file}} = $status;
}







=item scan

Calls scan on this source's converter and returns all datasets 
which haven't been ingested on a previous pass

=cut

sub scan {
	my ( $self ) = @_;
	
	$self->{log}->info("Scanning $self->{name} [" . ref($self->{converter}) . "]");
	
   	my @datasets = ();
	
	if( !$self->{locked} ) {
		$self->{log}->error("Source $self->{name} hasn't been opened: can't scan");
		return ();
	}
	    	
	for my $dataset ( $self->{converter}->scan ) {
		my $status = $self->get_status(dataset => $dataset);
		if( $status->{status} eq 'new') {
			my $id = $self->{ids}->create_id;
			if( $id ) {
				$dataset->{id} = $id;
				$self->set_status(
					dataset => $dataset,
					status => 'new'
				);
				push @datasets, $dataset;
				$self->{log}->info("New id for dataset $dataset->{file}: $id");
			} else {
				$self->{log}->error("New id for dataset $dataset->{file} failed");
			}
		} else {
			$self->{log}->info("Skipping $dataset->{file}: status = $status->{status}");
		}
	}
	return @datasets;
}


=item dataset()

Creates a new dataset.
=cut


sub dataset {
	my ( $self, %params ) = @_;
	
	my $metadata = $params{metadata};
	my $file = $params{file};
	my $location = $params{location};
	my $datastreams = $params{datastreams};
	
	if( !$metadata || ! $file || !$location ) {
		$self->{log}->error("New dataset needs metadata, location and file");
		return undef;
	}
	
	my $dataset = CoataGlue::Dataset->new(
		source => $self,
		file => $file,
		location => $location,
		raw_metadata => $metadata,
		datastreams => $datastreams
	)|| do {
		$self->{log}->error("Error creating dataset");
		return undef;	
	};
	
	return $dataset;
}	





=item load_templates

Loads this data source's template config.

=cut


sub load_templates {
	my ( $self ) = @_;
	
	my $template_cf = join('/', 
                           $self->{coataglue}{templates},
                           "$self->{settings}{templates}.cf"
        );
	
	if( !-f $template_cf ) {
		$self->{log}->error("$self->{name}: Template config $template_cf not found");
		die("$self->{name}: Template config $template_cf not found");
	}
	
	read_config($template_cf => $self->{template_cf});
	
    # sections starting with _ are not views but handler maps etc

	VIEW: for my $view ( keys %{$self->{template_cf}} ) {
        next VIEW if $view =~ /^_/;
		my $crosswalk = $self->{template_cf}{$view};
		for my $field ( keys %$crosswalk ) {
			# generate code snippets for converting dates etc
			my ( $mdf, @expr ) = split(/\s+/, $crosswalk->{$field});
			if( @expr ) {
				my $handler = $self->make_handler(
                    field => $field,
					expr => \@expr
				);
				if( $handler ) {
 					$self->{template_handlers}{$view}{$field} = $handler; 
					$self->{log}->debug("Added $view.$field handler: $handler to source $self");
				} else {
					$self->{log}->error("Handler init failed for $view.$field: check config");
				}
				# Take the converter fields out of the metadata field
				$crosswalk->{$field} = $mdf;
			}
		}
	}
	
	
	$self->{log}->debug("Data source $self->{name} loaded template config $template_cf");
	$self->{tt} = Template->new({
		INCLUDE_PATH => $self->{coataglue}{templates},
		POST_CHOMP => 1
	});
}


=item crosswalk(dataset => $ds, view => $view)

Applies a crosswalk from this view's template file.  If
no view is supplied, it applies the standard metadata crosswalk
to the raw metadata from the converter.  If a view is supplied,
and it isn't 'metadata', it runs one of the other views defined
in the file on the standard metadata (and creates this first
if it hasn't yet been built)

=cut

sub crosswalk {
	my ( $self, %params ) = @_;
	
	my $view = $params{view} || 'metadata';

	my $ds = $params{dataset};
	
	if( !$self->{template_cf}{$view} ) {
		$self->{log}->error("View '$view' not defined in template file for $self->{name}");
		return undef;
	}
	if( !$ds ) {
		$self->{log}->error("crosswalk needs a dataset");
		return undef;
	}
	my $view_name = $view;
	my $view = $self->{template_cf}{$view_name};
	my $handlers = $self->{template_handlers}{$view_name} || undef;
	
	my $original;
	
	if( $view_name eq 'metadata' ) {
		$original = $ds->{raw_metadata};
	} else {
		if( !defined $ds->{metadata} ) {
			$self->crosswalk(
				view => 'metadata',
				dataset => $ds
			)
		}
		$original = $ds->{metadata};
	}
	my $new = {};
	
    $self->{log}->trace("view keys = " . join(' ', keys %$view));

	for my $field ( keys %$view ) {
		if( $view->{$field} =~ /\.tt$/ ) {
			$new->{$field} = $self->expand_template(
				template => $view->{$field},
				metadata => $original
			);
		} else {
			my $mdfield = $view->{$field};
            if( $mdfield =~ /^"(.*)"$/ ) {
                $new->{$field} = $1;
            } elsif( !defined $original->{$mdfield} ) {
				$new->{$field} = '';
			} else {
				if( $handlers && $handlers->{$field} ) {
					my $h = $handlers->{$field};
					$new->{$field} = &$h($original->{$mdfield});
				} else {
					$new->{$field} = $original->{$mdfield};
				}
			}
            $self->{log}->trace("Crosswalked $mdfield='$original->{$mdfield}' to $field='$new->{$field}'");

		}
	}
	
	if( $view_name eq 'metadata' ) {
		$ds->{metadata} = $new;
		$ds->{datecreated} = $ds->{metadata}{datecreated};
        my $id = $ds->{metadata}{creator};
        my $creator = {};
        if( my $person = $self->get_person(id => $id) ) {
            $ds->{metadata}{creator} = $person->creator;
        } else {
            $self->{log}->error(
                "Warning: dataset $ds->{id} creator $id not found"
                );
            $ds->{metadata}{creator} = { staffid => $id };
        }
	} else {
		$ds->{views}{$view_name} = $new;
	}
	return $new;
}

=item get_person(id => $id)

Takes a staff ID and calls CoataGlue::Person::lookup to find them in 
Mint.

=cut


sub get_person {
 	my ( $self, %params ) =  @_;
 	
 	my $id = $params{id};

    my $person = CoataGlue::Person->lookup(
        coataglue => $self->{coataglue},
        id => $id
        ) || do {
            $self->{log}->error("Couldn't find creator id $id");
            return undef;
    };
    
    return $person;
}


=item staff_id_to_handle

This method has been superseded by get_person (above) but I'm leaving it
in because some of the tests use it.  FIXME

=cut

sub staff_id_to_handle {
 	my ( $self, %params ) =  @_;
 	
 	my $id = $params{id};
 	
	my $p = CoataGlue::Person->new(id => $id) || do {
		$self->{log}->error("Couldn't create CoataGlue::Person");
		die;
	};

	my $key = $self->conf('Redbox', 'cryptkey');

	my $encrypt = $p->encrypt_id(id => $id, key => $key	);

    my $prefix = $self->conf('Redbox', 'handleprefix');
    my $handle = $encrypt;
    
    if( $prefix ne 'none' ) {
        $handle = $prefix . $handle;
    }


	$self->{log}->debug("Staff id $id => handle $handle");

	return $handle;
}




=item render_view(dataset => $ds, view => $view)

Generate an XML view of a dataset.  Expansion works like this:
the top level is a crosswalk into XML elements.  Each of these 
elements can either be a straight copy from one of the metadata
fields, or an expansion of a template.  The templates have access
to all of the metadata of the dataset, so (for example) technical
metadata fields can be combined into a single 'description' element.

All XML views get an 'header' element at the top which contains the
dataset's origin file, id, location, repositoryURL, date converted
and 'publish' flag

Returns the resulting XML.


=cut

sub render_view {
	my ( $self, %params ) = @_;
	
	my $view = $params{view} || 'metadata';
	my $dataset = $params{dataset};
	
	if( !$dataset ) {
		$self->{log}->error("render_view needs a dataset");
		return undef;
	}

	my $elements = $self->crosswalk(
		view => $view,
		dataset => $dataset
	);
	
	my $output;
	
	my $writer = XML::Writer->new(
        OUTPUT => \$output,
        DATA_MODE => 1,
        DATA_INDENT => 4
        
);
	$writer->startTag($view);
	$self->write_header_XML(
		writer => $writer,
		dataset => $dataset
	);
    if( $view eq 'metadata' ) {
        $self->write_creator_XML(
            writer => $writer,
            dataset => $dataset
            );
    }

	for my $tag ( sort keys %$elements ) {
        next if( $view eq 'metadata' && $tag =~ /access|creator/ );
		$writer->startTag($tag);
		$writer->characters($elements->{$tag});
		$writer->endTag();
	}
	$writer->endTag();
	
	return $output;
}


=item write_header_XML(writer => $writer)

Add the standard header tag

=cut

sub write_header_XML {
	my ( $self, %params ) = @_;
	
	my $dataset = $params{dataset};
	my $writer = $params{writer};
	
	my $header = $dataset->header();

	$writer->startTag('header');	
	for my $field ( qw(source id file location access repositoryURL dateconverted) ) {
		$writer->startTag($field);
		$writer->characters($header->{$field});
		$writer->endTag();
	}
	$writer->endTag();
}


=item write_creator_XML(writer => $writer)

Add the standard creator tag

=cut

sub write_creator_XML {
	my ( $self, %params ) = @_;
	
	my $dataset = $params{dataset};
	my $writer = $params{writer};
	
	my $creator = $dataset->metadata()->{creator};

    $self->{log}->debug("### creator" . Dumper({creator => $creator}));

	$writer->startTag('creator');	
	for my $field ( qw(staffid mintid name givenname familyname honorific jobtitle groupid) ) {
		$writer->startTag($field);
		$writer->characters($creator->{$field});
		$writer->endTag();
	}
	$writer->endTag();
}



=item expand_template(template => $template, metadata => $metadata)

Populate one of the templated elements with a template file

=cut

sub expand_template {
	my ( $self, %params ) = @_;
	
	my $template = $params{template};
	my $metadata = $params{metadata};

	my $output = '';

	$self->{log}->debug("Expanding temlate $params{template}");

	if( $self->{tt}->process($params{template}, $metadata, \$output) ) {
		return $output;
	}
	$self->{log}->error("Template error ($template) " . $self->{tt}->error);
	return undef;
}


=item repository

Initialises a connection to the Fedora repository if it's not
already been made, and returns it as a Catmandu::Store object

=cut

sub repository {
	my ( $self ) = @_;
	
	return $self->{coataglue}->repository;
}

=item repository_crosswalk

Crosswalks a standard metadata hashref into a DC hashref to
be added to the Fedora repository

=cut

sub repository_crosswalk {
	my ( $self, %params ) = @_;
	
	return $self->{coataglue}->repository_crosswalk(%params);
}

=item conf

Get config values from the Coataglue object

=cut

sub conf {
	my ( $self, $section, $field ) = @_;
	
	return $self->{coataglue}->conf($section, $field);
}


=item make_handler

This might be a bit half-baked: 

=cut

sub make_handler {
	my ( $self, %params ) = @_;
	
	my $expr = $params{expr};
    my $field = $params{field};

	if( $expr->[0] eq 'date' ) {
		shift @$expr;
		return $self->date_handler(field => $field, expr => $expr);
	} elsif( $expr->[0] eq 'map' ) {
        return $self->map_handler(field => $field, map => $expr->[1]);
    } else {
		$self->{log}->error("Unknown handler '$expr->[0]'");
		return undef;
	}
}


=item date_handler

date($RE, $f1, $f2, $f3)

Where $RE is a regular expression matching groups for date
components, and the $f1... are YEAR MON DAY HOUR MIN SEC.

For example.

date((\d+)\/(\d+)\/(\d+), DAY, MON, YEAR)

will match and convert dates like 31/12/1969

It's assumed that MON is 1..12 and the year is four digits:
other years will throw an error.

=cut

sub date_handler {
	my ( $self, %params ) = @_;
	
	my $expr = $params{expr};
    my $field => $params{field};
	
	my $re = shift @$expr;
	my @fields = @$expr;
	
	my $timefmt = $self->conf('General', 'timeformat');
	
	my %check = map { $_ => 1 } @fields;

	my $missing = 0;
	for my $p ( qw(DAY MON YEAR) ) {
		if( !$check{$p} ) {
			$self->{log}->error("No $p field");
			$missing = 1;
		}
	}
	
	if( $missing ) {
		$self->{log}->error("Date handler must have a  DAY, MON and YEAR");
		$self->{log}->error("Got: " . join(', ', @fields));
		return undef;
	}
	
	my $handler = sub {
		my ( $value ) = @_;
		my @matches = ( $value =~ /$re/ );
		my $val = {};
		my $i = 0;
		for my $v ( @matches ) {
			$val->{$fields[$i]} = $v;
			$i++;
		}
		if( $val->{YEAR} && $val->{MON} && $val->{DAY} ) {
			if( $val->{YEAR} !~ /^\d\d\d\d$/ ) {
				$self->{log}->error("Invalid date '$value' in $field (year must be four digits)");
				return undef;
			}
			return strftime(
				$timefmt, $val->{SEC}, $val->{MIN}, $val->{HOUR},
				$val->{DAY}, $val->{MON} - 1, $val->{YEAR} - 1900
 				);
		} else {
			$self->{log}->error("Invalid date '$value'");
			$self->{log}->debug(Dumper(
			{ value => $value, re => $re, val =>  $val }));
			return undef;
		}
	};
		
	$self->{log}->debug("Built date handler $handler");
	return $handler;
	
}


=item map_handler(map => $configmap)

Maps raw values onto another set, as defined by the [map] section of
the source's config file

=cut

sub map_handler {
	my ( $self, %params ) = @_;
	
    my $mapname = $params{map};
    
    my $map = $self->{template_cf}{$mapname};

    $self->{log}->debug("Map handler $params{field} $mapname");

    if( !$map ) {
        $self->{log}->error("map handler: no config section '$mapname'");
        return undef;
    }
    return sub { 
        my ( $value ) = @_;
        if( $map->{$value} ) {
            return $map->{$value}
        } else {
            $self->{log}->warn("Warning: no map value for $value");
            return undef;
        }
    };
}


1;
