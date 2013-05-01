package CoataGlue::Source;

use strict;

use Carp qw(cluck);

use Log::Log4perl;
use Storable qw(lock_store lock_retrieve);
use Data::Dumper;
use Config::Std;
use XML::Writer;

use CoataGlue::Converter;
use CoataGlue::ID::NaiveSequence;

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

our @MANDATORY_PARAMS = qw(name converter ids settings store);

our @MANDATORY_SETTINGS = qw(redboxdir templates);


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
				$self->{log}->debug("New id for dataset $dataset->{file}: $id");
			} else {
				$self->{log}->error("New id for dataset $dataset->{file} failed");
			}
		} else {
			$self->{log}->debug("Skipping $dataset->{id}: status = $status->{status}");
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
	
	if( !$metadata || ! $file ) {
		$self->{log}->error("New dataset needs metadata and file");
		return undef;
	}
	
	my $dataset = CoataGlue::Dataset->new(
		source => $self,
		file => $file,
		metadata => $metadata
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
	
	my $template_cf = "$ENV{COATAGLUE_TEMPLATES}/$self->{settings}{templates}.cf";
	
	if( !-f $template_cf ) {
		$self->{log}->error("$self->{name}: Template config $template_cf not found");
		die("$self->{name}: Template config $template_cf not found");
	}
	
	read_config($template_cf => $self->{template_cf});
	$self->{log}->debug("Data source $self->{name} loaded template config $template_cf");
	$self->{tt} = Template->new({
		INCLUDE_PATH => $ENV{COATAGLUE_TEMPLATES},
		POST_CHOMP => 1
	});
}


=item render_view(dataset => $ds, view => $view)

Generate an XML view of a dataset.  Expansion works like this:
the top level is a crosswalk into XML elements.  Each of these 
elements can either be a straight copy from one of the metadata
fields, or an expansion of a template.  The templates have access
to all of the metadata of the dataset, so (for example) technical
metadata fields can be combined into a single 'description' element.

All XML views get an 'rdc' element at the top which contains
the dataset's origin file, global ID, Fedora object ID (if one
is created)

Returns the resulting XML.

=cut

sub render_view {
	my ( $self, %params ) = @_;
	
	my $name = $params{view};
	my $ds = $params{dataset};
	
	if( !$self->{template_cf}{$name} ) {
		$self->{log}->error("View '$name' not defined in template config");
		return undef;
	}
	if( !$ds ) {
		$self->{log}->error("render_xml needs a dataset");
		return undef;
	}
	
	my $view = $self->{template_cf}{$name};
	my $elements = {};
	
	for my $field ( keys %$view ) {
		if( $view->{$field} =~ /\.tt$/ ) {
			$self->{log}->debug("Expanding template $field: $view->{$field}");
			$elements->{$field} = $self->expand_template(
				template => $view->{$field},
				metadata => $ds->{metadata}
			);
		} else {
			my $mdfield = $view->{$field};
			if( !defined $ds->{metadata}{$mdfield} ) {
				$self->{log}->warn("View $name: $mdfield not defined for dataset $ds->{id}");
				$elements->{$field} = '';
			} else {
				$elements->{$field} = $ds->{metadata}{$mdfield};
			}
		}
	}
	my $output;
	
	my $writer = XML::Writer->new(OUTPUT => \$output);
	$writer->startTag($name);
	for my $tag ( keys %$elements ) {
		$writer->startTag($tag);
		$writer->characters($elements->{$tag});
		$writer->endTag();
	}
	$writer->endTag();
	
	return $output;
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
	$self->{log}->error("Template error in $template " . $self->{tt}->error);
	return undef;
}

1;