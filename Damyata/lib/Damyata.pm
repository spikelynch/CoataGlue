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

=item A dataset URL like 'http://research.uts.edu.au/damyata/RDC.n'

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
use Data::Dumper;
use File::MimeInfo;
use Catmandu::FedoraCommons;

our $VERSION = '0.1';

our %REQUIRED_CONF = (
	solr => [ qw(server core search) ],
	fedora => [ qw(url user password) ],
	redbox_map => [ qw(
		title description access created
		creator_title creator_familyname creator_givenname
	) ],
	filestore => [ qw(basedir) ]
);


my $conf = load_config();


my $solr = Apache::Solr->new(
    server => $conf->{solr}{server},
    core => $conf->{solr}{core}
) || do {
	error("Couldn't connect to ReDBox/Solr");
	die;
};


my $fedora = Catmandu::FedoraCommons->new(
	$conf->{fedora}{url},
	$conf->{fedora}{user},
	$conf->{fedora}{password}
) || do {
	error("Couldn't connect to Fedora Commons");
	die;
};

debug({ "Fedora credentials:" => $conf->{fedora} } );


=head DANCER PATHS

=over 4

=item get /

A placeholder index page

=cut

get '/' => sub {
    template 'index';
};

=item get /:id

The landing page for a dataset

=cut


get '/:id' => sub {
	
	my $id = param('id');

	my $uri = request->uri;
	my $base = undef;
	
	if( $conf->{fake_baseurl} ) {
		$base = $conf->{fake_baseurl};		
	} else {
		$base = request->uri_base; 
	}
	
	$uri = $base . $uri;

	my $dataset = find_dataset(
		solr_field => $conf->{solr}{search},
		redbox_map => $conf->{redbox_map},
		fedora_id => $id,
		uri => $uri
	);
	
	if( !$dataset ) {
		template 'not_found' => { uri => $uri };
	} else {
		
		if( $dataset->{access} eq 'local' && !request_is_local() ) {
			template 'forbidden' => { uri => $uri };
		} else {
			template 'dataset' => $dataset
		}
	}
};


=item get /fs/:audience/:id/:ds

Serves a datastream which is located in the filesystem, NOT Fedora.

Note: for production, if we use this, needs security based on the
:section parameter.

=cut

get '/fs/:section/:id/:ds' => sub {
	
	warning("In datastream section");
	
	my $section = param('section');
	my $id = param('id');
	my $ds = param('ds');
	
#my ( $file, $ext ) = split(/\./, $ds);
	
	my $mimetype = mimetype($ds);
	
	my $path = join(
		'/', $conf->{filestore}{basedir}, $section, $id, $ds
	);
	
	warning("***File path = $path");
	
	send_file(
		$path,
		content_type => $mimetype,
		filename => $ds
	);
	
};


=item get /fedora/:id/:ds

Serves a datastream which is stored in Fedora Commons, rather
than the filesystem.


=cut


get '/fedora/:id/:ds' => sub {
	
	my $id = param('id');
	my $dsid = param('ds');
	
	my $data = '';
	
	my $datastreams = find_datastreams(fedora_id => $id);

	my @ds = grep { $_->{dsid} eq $dsid } @$datastreams;
	
	if( !@ds ) {
		template 'not_found';
	} else {
		my $mimetype = $ds[0]->{mimeType};
		debug("mimetype $dsid = $mimetype");
		content_type $mimetype;
		
		my $data = '';
		$fedora->getDatastreamDissemination(
			pid => $id,
			dsID => $dsid,
			callback => sub {
				my ( $d, $response, $protocol ) = @_;
				$data .= $d;
			}
		);
		my @mimeparts = split('/', $mimetype);
		my $filename = join('.', $id, $dsid, $mimeparts[1]);
		return send_file(
			\$data,
			content_type => $mimetype,
			filename => $filename
		);
	}
	
};


=back

=head METHODS

=over 4

=item load_config

Loads and validates the app's config variables.  Calls error
and dies if any are missing or invalid.

=cut


sub load_config {

	my $conf = {};
	
	# build the config hash and die if any mandatory fields
	# are missing
	
	my $missing = 0;
	for my $section ( keys %REQUIRED_CONF ) {
		my $req = $REQUIRED_CONF{$section};
		$conf->{$section} = config->{$section};
		if( ! $conf->{$section} ) {
			error("Missing config section $section");
			$missing = 1;
		} else {
			for my $value ( @$req ) {
				if( ! $conf->{$section}{$value} ) {
					error("Missing config value $section.$value");
					$missing = 1;
				}
			}
		}
	}
	die if $missing;
	
	$conf->{solr}{search} =~ s/:/\\:/g;
	
	# not a mandatory field so we have to fetch it explicitly
	
	$conf->{fake_baseurl} = config->{fake_baseurl};

	return $conf;
}

=item find_dataset

Looks up the dataset by its URI in Solr.  If it's found, also
looks it up in Fedora to get the list of datastreams.

Parameters:

=over 4

=item uri
=item fedora_id 
=item solr_field
=item redbox_map

=back

The return value is a hash as follows:

=over 4

=item title
=item description
=item access
=item created
=item creator_title
=item creator_familyname
=item creator_givenname
=item datastreams

=back

Mapping from the ReDBox/Solr index to these fieldnames is controlled
by redbox_map in the config file.

All of the values are scalars except for 'datastreams', which is an
arrayref of hashes as follows:

=over 4

=item dsid
=item label
=item mimeType
=item url

=back


=cut

sub find_dataset {
	my %params = @_;
	
	my $uri = $params{uri} || return undef;
	my $fedora_id = $params{fedora_id} || return undef;
	my $urifield = $params{solr_field};
	my $redbox_map = $params{redbox_map};
	
	my $esc_uri = $uri;

	$esc_uri =~ s/:/\\:/g;
	
	my $solr_query = join(':', $urifield, $esc_uri);

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
	
	$dataset->{datastreams} = find_datastreams(
		fedora_id => $fedora_id
	);
	
	# build a url for each datastream
    # Pay No Attention to the Man behind the Curtain
	
	for my $ds ( @{$dataset->{datastreams}} ) {
		$ds->{url} = uri_for(join('/', 'fs', 'local', $fedora_id, $ds->{dsid}));
	}
	
	return $dataset;
}


=item find_datastreams 

Looks the dataset up in Fedora and returns a list of datastreams.
The list is an arrayref of hashrefs: keys are dsid, mimeType and
label

=cut


sub find_datastreams {
	my %params = @_;
	
	
	my $fedora_id = $params{fedora_id};
	my $datastreams = {};
	
	my $result = $fedora->listDatastreams(pid => $fedora_id);

	if( $result->is_ok ) {
		my $dss = $result->parse_content;
		
		return $dss->{datastream};
		
	} else {
		debug("Error looking up datastreams in FC: " . $result->error);
		return []
	}
}


=item request_is_local

Return true if this request is 'local'

=cut



sub request_is_local {
	return true;
}

true;
