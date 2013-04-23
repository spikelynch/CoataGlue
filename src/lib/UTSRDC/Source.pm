package UTSRDC::Source;

use strict;

use Log::Log4perl;
use Storable qw(lock_store lock_retrieve);
use Data::Dumper;
use Config::Std;
use XML::Writer;

use UTSRDC::Converter;


=head1 NAME

UTSRDC::Source

=head1 DESCRIPTION

Basic object describing a data source

name      - unique id
converter - A UTSRDC::Converter object (passed in by UTSRDC)
settings  - the config settings (these depend on the Converter)
store     - the directory where the source histories are kept 

=cut

our $STATUS_NEW      = 'new';
our $STATUS_ERROR    = 'error';
our $STATUS_INGESTED = 'ingested';


sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	
	bless $self, $class;

	$self->{log} = Log::Log4perl->get_logger($class);

	my $missing = undef;
	for my $field ( qw(name converter settings store) ) {
		$self->{$field} = $params{$field} || do {
			$self->{log}->error("Missing $field for $class");
			$missing = 1;
		}
	}
	
	if( $missing ) {
		return undef;
	}
	
	# add this source to its converter so that the converter
	# can do status lookups etc.

	$self->{converter}{source} = $self;
	
	$self->{storefile} = join('/', $self->{store}, $self->{name});
	
	$self->load_history;
	$self->load_templates;
	
	return $self;
}

sub load_history {
	my ( $self ) = @_;	
	if( -f $self->{storefile} ) {
		$self->{log}->debug("Loading history $self->{storefile}");
		$self->{history} = lock_retrieve($self->{storefile});
	} else {
		$self->{log}->info("Empty history for $self->{name}");
		$self->{history} = {};
	}
}


sub save_history {
	my ( $self ) = @_;
	
	lock_store $self->{history}, $self->{storefile};
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
	
	if( $self->{history}{$dataset->{id}} ) {
		return $self->{history}{$dataset->{id}};
	} else {
		return { status => 'new' };
	}
}


sub set_status {
	my ( $self, %params ) = @_;
	
	my $dataset = $params{dataset} || do {
		$self->{log}->error("Can't sest status for empty dataset");
		return undef;
	};
	my $status = { status => $params{status} };
	
	if( $params{details} ) {
		$status->{details} = $params{details};
	}
	
	$self->{history}{$dataset->{id}} = $status;
	$self->save_history;
}







=item scan

Calls scan on this source's converter and returns all datasets 
which haven't been ingested on a previous pass

=cut

sub scan {
	my ( $self ) = @_;
	
	my @datasets = ();
	
	for my $dataset ( $self->{converter}->scan ) {
		my $status = $self->get_status(dataset => $dataset);
		if( $status->{status} eq 'new') {
			push @datasets, $dataset;
		} else {
			$self->{log}->debug("Skipping $dataset->{id}: status = $status->{status}");
		}
	}
	return @datasets;
}



=item load_templates

Loads this data source's template config.

=cut


sub load_templates {
	my ( $self ) = @_;
	
	my $template_cf = "$ENV{RDC_TEMPLATES}/$self->{settings}{templates}.cf";
	
	if( !-f $template_cf ) {
		$self->{log}->error("$self->{name}: Template config $template_cf not found");
		die("$self->{name}: Template config $template_cf not found");
	}
	
	read_config($template_cf => $self->{template_cf});
	$self->{log}->debug("Data source $self->{name} loaded template config $template_cf");
	$self->{tt} = Template->new({
		INCLUDE_PATH => $ENV{RDC_TEMPLATES},
	});
}


=item render_view(dataset => $ds, view => $view)

Generate an XML view of a dataset.  Expansion works like this:
the top level is a crosswalk into XML elements.  Each of these 
elements can either be a straight copy from one of the metadata
fields, or an expansion of a template.  The templates have access
to all of the metadata of the dataset, so (for example) technical
metadata fields can be combined into a single 'description' element.

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
			if( !defined $ds->{metadata}{$field} ) {
				$self->{log}->warn("View $name: $field not defined for dataset $ds->{id}");
				$elements->{$field} = '';
			} else {
				$elements->{$field} = $ds->{metadata}{$field};
			}
		}
	}
	my $output;
	
	my $writer = XML::Writer->new(OUTPUT => $output);
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

	if( $self->{tt}->process($params{template}, $metadata, \$output) ) {
		return $output;
	}
	$self->{log}->error("Template error in $template " . $self->{tt}->error);
}

1;