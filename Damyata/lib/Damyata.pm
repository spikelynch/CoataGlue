package Damyata;

=head NAME

Damyata

=head DESCRIPTION

Dancer module to control access to datasets in Fedora Commons 
based on their settings in the Research Data Catalogue (RDC)

=head SYNOPSIS

All datasets in the RDC are assigned a digital object in Fedora,
whether they're being published on the web or not.  For a given
dataset D, there exists:

=over 4

=item A Fedora digital object with an ID like 'RDC.n'

=item A dataset URL like 'http://research.uts.edu.au/data/RDC.n'

=item A ReDBox dataset with the URL as an identifier

=back

Damyata accepts dataset URLs and does the following:

=over 4

=item Look up the request URL in the RDC (via the Solr API)

=item Get the dataset's access setting from the RDC:

=over 4

=item If the dataset is public, return the landing page

=item If the dataset is UTS-only, return the landing page if the request is from UTS

=item If neither of the above, return a 'not found' page

=back

=item If the dataset was not found, return a 'not found' page.

=back

Damyata generates the landing page based on the metadata values
returned from the RDC, and by looking up the Fedora record to 
find the datastreams.

=cut

use Dancer ':syntax';
use Apache::Solr;

our $VERSION = '0.1';

my $solr_server = config->{solr}{server};
my $solr_core = config->{solr}{core};

if( !$solr_server || !$solr_core ) {
	error("Need config/solr => { server, core }");
	die;
}

my $solr = Apache::Solr->new(
    server => $solr_server,
    core => $solr_core,

);

my $solr_urifield = config->{solr_urifield};

if( !$solr_urifield ) {
	error("Config field missing: 'solr_urifield'");
	die;
}

$solr_urifield =~ s/:/\\:/g;

my $redbox_map = config->{redbox_map};

if( !$redbox_map ) {
	error("Config field missing: 'redbox_map'");
	die;
}

if( ref($redbox_map) ne 'HASH' ) {
	error("Config 'redbox_map' must be a hash");
	die;
}

my $fake_baseurl = config->{fake_baseurl};


get '/' => sub {
    template 'index';
};


get '/:id' => sub {
	
	my $uri = request->uri;
	my $base = undef;
	
	if( $fake_baseurl ) {
		$base = $fake_baseurl;		
	} else {
		$base = request->uri_base; 
	}
	
	$uri = $base . $uri;

	my $dataset = lookup(uri => $uri);
	
	if( !$dataset ) {
		template 'not_found' => { uri => $uri };
	} else {
		debug({ dataset => $dataset });
		
		
		if( $dataset->{access} eq 'local' && !request_is_local() ) {
			template 'forbidden' => { uri => $uri };
		} else {
			template 'dataset' => $dataset
		}
	}
};


sub lookup {
	my %params = @_;
	
	my $uri = $params{uri} || return undef;
	
	my $esc_uri = $uri;

	$esc_uri =~ s/:/\\:/g;
	
	my $solr_query = join(':', $solr_urifield, $esc_uri);

	debug("Solr query: '$solr_query'");

	my $results = $solr->select(q => $solr_query);
	
	my $n = $results->nrSelected;
	
	if( !$n ) {
		debug("URI '$uri' not found in Solr.");
		return undef;
	}
	
	if( $n > 1 ) {
		warn("More than one Solr index with URI '$uri'");
	} else {
		debug("Found a result for '$uri'");
	}
	
	my $doc = $results->selected(0);
	
	my $dataset = {};
	
	for my $field ( keys %$redbox_map ) {
		$dataset->{$field} = $doc->content($redbox_map->{$field}) || '';
	}
	
	return $dataset;
}


sub request_is_local {
	return true;
}

true;
