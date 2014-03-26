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
    

=head1 DESCRIPTION

Basic object describing a data source

=over 4

=item name      - unique id

=item converter - A CoataGlue::Converter object (passed in by CoataGlue)

=item settings  - the config settings (some of which depend on the Converter)

=item store     - the directory where the source histories are kept 

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
   

=cut

our $STATUS_NEW      = 'new';
our $STATUS_ERROR    = 'error';
our $STATUS_INGESTED = 'ingested';

our @MANDATORY_PARAMS = qw(coataglue name converter ids settings store);

our @MANDATORY_SETTINGS = qw(templates);

our @HEADER_FIELDS = qw( 
    source id handle file access dateconverted
    repositoryURL manifest location
);

our %MONTHS = (
    jan => 0,
    feb => 1,
    mar => 2,
    apr => 3,
    may => 4,
    jun => 5,
    jul => 6,
    aug => 7,
    sep => 8,
    oct => 9,
    nov => 10,
    dec => 11
    );

=head1 METHODS

=item new(%params)

Create a new Source. Parameters:

=over 4

=item coataglue - the CoataGlue object

=item name - unique name of this Source

=item converter - the CoataGlue::Converter class

=item ids - the ID uniquifier

=item settings - the settings hash from the config file

=item store - the directory where store files are written

=back

=cut


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


=item open()

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

=item close()

Saves the source's history hash to the store file and releases the
lock.

=cut


sub close {
	my ( $self ) = @_;
	
	lock_store $self->{history}, $self->{storefile};
	$self->{locked} = 0;
	
	return 1;
}


=item get_status(dataset => $dataset)

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


=item set_status(dataset => $dataset, status => $status)

Set the dataset's status in the history file.

=cut

sub set_status {
	my ( $self, %params ) = @_;
	
	my $dataset = $params{dataset} || do {
		$self->{log}->error("Can't set status for empty dataset");
		return undef;
	};
	
	if( !$dataset->{file} || !$dataset->{id} ) {
		$self->{log}->error("dataset needs 'file' and 'id', can't set status");
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


=item skip()

Returns true if the 'skip' flag in the datasource config is set.
Used to skip broken converters when testing.

=cut

sub skip {
    my ( $self ) = @_;


    if( $self->{converter}{skip} ) {
        $self->{log}->debug("Source $self->{name}: skipping");
        return 1;
    } else {
        $self->{log}->debug("Source $self->{name}: no skip");
        return 0;
    }
}

=item scan([test => 1, redo => 1])

Calls scan on this source's converter and returns all datasets 
which haven't been ingested on a previous pass.

If a true value is passed in for 'test', this will output metadata
files to the test metadata directory but not touch the history.

If running in test mode and redo is true, this will rewrite the
metadata files for all datasets, not just the new ones.

=cut

sub scan {
	my ( $self, %params ) = @_;
	
	$self->{log}->info(
        "Scanning $self->{name} [" . ref($self->{converter}) . "]"
        );

    my $test = $params{test} || undef;
    my $id = $params{id} || undef;

    if( $test ) {
        return $self->test_scan(%params);
    }

    my $raw_keys = {};

   	my @datasets = ();
	
	if( !$self->{locked} ) {
		$self->{log}->error("Source $self->{name} hasn't been opened: can't scan");
		return ();
	}

	for my $dataset ( $self->{converter}->scan ) {
        #my $handle = $dataset->handle();
		my $status = $self->get_status(dataset => $dataset);
        if( $id && $status->{id} eq $id ) {
            $dataset->{id} = $id;
            $self->{log}->info("Returning single dataset with id $id");
            return ( $dataset );
        }
		if( $status->{status} eq 'new' ) {
			my $id = $self->{ids}->create_id();
            for my $key ( keys %{$dataset->{raw_metadata}} ) {
                $raw_keys->{$key} = 1;
            }
			if( $id ) {
				$dataset->{id} = $id;
                $self->set_status(
                    dataset => $dataset,
                    status => 'new'
                    );
				push @datasets, $dataset;
				$self->{log}->info("New id for dataset: $id");
			} else {
				$self->{log}->error("New id for dataset $dataset->{file} failed");
			}
		} else {
			$self->{log}->info("Skipping $dataset->{file}: status = $status->{status}");
		}
	}

    $self->{log}->debug("Raw metadata keys for $self->{name}");
    for my $key ( sort keys %$raw_keys ) {
        $self->{log}->debug(": $key");
    }


    if( $id ) {
        $self->{log}->error("Couldn't find dataset with id $id");
        return ();
    }
	return @datasets;
}


=item test_scan

Test version of scan.  I broke this out into its own subroutine because
doing both test and live in the same loop was creating code that was too
complicated around the id incrementation.

=cut


sub test_scan {
    my ( $self, %params ) = @_;

    $self->{log}->info("Running in test mode");
    my $id = $params{id}; 
    my $redo = $params{'redo'} || undef;
  	my @datasets = ();
	
	if( !$self->{locked} ) {
		$self->{log}->error("Source $self->{name} hasn't been opened: can't scan");
		return ();
	}

    my $tid = $self->{ids}->create_id;

    my $raw_keys = {};


	for my $dataset ( $self->{converter}->scan ) {
		my $status = $self->get_status(dataset => $dataset);
        if( $id && $dataset->{id} eq $id ) {
            $self->{log}->info("Returning single dataset with id $id");
            return ( $dataset );
        }

		if( $status->{status} eq 'new' || $redo ) {
            for my $key ( keys %{$dataset->{raw_metadata}} ) {
                $raw_keys->{$key} = 1;
            }
            $dataset->{id} = $tid;
            push @datasets, $dataset;
            $self->{log}->info("New id for dataset $dataset->{file}: $tid");
            $tid++;
		} else {
			$self->{log}->info("Skipping $dataset->{file}: status = $status->{status}");
		}
	}
    if( $id ) {
        $self->{log}->error("Couldn't find dataset with id $id");
        return ();
    }

    $self->{log}->debug("Raw metadata keys for $self->{name}");
    for my $key ( sort keys %$raw_keys ) {
        $self->{log}->debug(": $key");
    }

	return @datasets;
}





=item dataset(%params)

Creates a new dataset based on the parameters:

=over 4

=item metadata - metadata hash

=item file - the actual metadata file

=item location - the file's location (usually a dir)

=item datastreams - a hashref of datastreams

=back

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
		FIELD: for my $field ( keys %$crosswalk ) {

            # If it's a string literal, don't test for handlers
            next FIELD if( $crosswalk->{$field} =~ /^"(.*)"$/ );
                
			# generate code snippets for converting dates etc
			my ( $mdf, @expr ) = split(/\s+/, $crosswalk->{$field});
            
			if( @expr ) {

                # If the mdf ends in .tt, the @expr are arguments controlling
                # the subtemplate expansion

                if( $mdf =~ /\.tt$/ ) {
                    $self->{template_args}{$view}{$field} = \@expr;
                    $self->{log}->debug("Template args: $view $field " . join(', ', @expr));
                } else {                
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
            $self->{log}->trace("mdfield = $mdfield");
            if( $mdfield =~ /^"(.*)"$/ ) {
                $self->{log}->trace("Expanding literal $field = $1");
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
            $self->{log}->trace(
                "Crosswalked $mdfield='$original->{$mdfield}' to $field='$new->{$field}'"
                );

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
        source => $self,
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
 	
	my $p = CoataGlue::Person->new(source => $self, id => $id) || do {
		$self->{log}->error("Couldn't create CoataGlue::Person");
		die;
	};

	my $handle = $p->encrypt_id;

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
    my $subtt_args = $self->{template_args}{$view} || undef;

	
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
        DATA_INDENT => 4,
        UNSAFE => 1       # required for passing raw XML through
        
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

    # CREATEXML
    

	for my $tag ( sort keys %$elements ) {
        next if( $view eq 'metadata' && $tag =~ /access|creator/ );
		$writer->startTag($tag);
        if( $subtt_args && $subtt_args->{$tag} && $subtt_args->{$tag}[0] eq 'raw' ) {
            $writer->raw($elements->{$tag});
        } else {
            $writer->characters($elements->{$tag});
        }
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
	for my $field (  @HEADER_FIELDS ) {
		$writer->startTag($field);
		$writer->characters($header->{$field});
		$writer->endTag;
	}
    
	$writer->endTag;
}


=item write_creator_XML(writer => $writer)

Add the standard creator tag

=cut

sub write_creator_XML {
	my ( $self, %params ) = @_;
	
	my $dataset = $params{dataset};
	my $writer = $params{writer};
	
	my $creator = $dataset->metadata()->{creator};

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

	$self->{log}->debug("Expanding template $params{template}");

	if( $self->{tt}->process($params{template}, $metadata, \$output) ) {
        $self->{log}->debug("Template results \n$output \n");
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

=item repository_crosswalk(%metadata)

Crosswalks a standard metadata hash into a DC hashref to
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


=item make_handler(expr => $expr, field => $field)

Generates a handler function for a field, based on $expr.

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
    } elsif( $expr->[0] eq 'timestamp' ) {
        return $self->timestamp_handler(field => $field, expt => $expr)
    } else {
		$self->{log}->error("Unknown handler '$expr->[0]'");
		return undef;
	}
}


=item date_handler(field => $field, expr => $expr)

   date($RE, $f1, $f2, $f3)

Where $RE is a regular expression matching groups for date
components, and the $f1... are YEAR MON DAY HOUR MIN SEC.

For example,

    date((\d+)\/(\d+)\/(\d+), DAY, MON, YEAR)

will match and convert dates like 31/12/1969

It's assumed that MON is either 1..12 or a string which matches
(jan|feb|mar...) and the year is four digits: other years will throw
an error.

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
            my $month = $self->parse_month(month => $val->{MON});
            if( !defined $month ) {
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



=item parse_month(month => $month)

Takes months either as 1-12 or names (Jan, January) and returns a value
0-11 to pass to strftime

=cut

sub parse_month {
    my ( $self, %params ) = @_;

    my $m = $params{month};
    
    if( $m =~ /^\d+$/ ) {
        if( $m > 0 || $m < 13 ) {
            return $m - 1;
        } else {
            $self->{log}->error("Integer month $m out of range");
            return undef;
        }
    }

    my $m3 = lc(substr($m, 0, 3));
    if( defined $MONTHS{$m3} ) {
        return $MONTHS{$m3};
    } else {
        $self->{log}->error("Unknown month name '$m'");
        return undef;
    }
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

=item timestamp_handler

This just appends a timestamp to the end of the field value.  A utility
for testing so that you can tell which version of a test dataset is 
which.

=cut


sub timestamp_handler {
    my ( $self, %params ) = @_;
    
    return sub {
        my ( $value ) = @_;
        my $ts = time;

        return "$value $ts";
    }
}

=item MIME_overrides

If there are any _MIME overrides, return them as a hashref

=cut

sub MIME_overrides {
    my ( $self ) = @_;

    if( $self->{template_cf}{_MIME} ) {
        return $self->{template_cf}{_MIME};
    } else {
        return undef;
    }
}

=back

=cut


1;
