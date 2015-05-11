package CoataGlue::Converter::OAIPMH::Omeka_XML_prime;

use strict;
use base qw( XML::SAX::Base );

use Data::Dumper;

our $VERSION = 'v1.00.0';

=head1 NAME

CoataGlue::Converter::OAIPMH::Omeka_XML_prime - trying for a better 
version

=head1 SYNOPSIS

This one turns the XML tree into an arrayref of arrayrefs where nodes
are hashes

=head1 DESCRIPTION

=head1 METHODS

=head2 new()

=cut

sub new {
    my ( $class, %opts ) = @_;
    my $self = bless \%opts, ref( $class ) || $class;
    $self->{root} = { 
        tag => '_root',
        children => []
    };
    $self->{stack} = [ $self->{root} ];

    return( $self );
}



sub start_document {
    my ( $self ) = @_;

    warn("Start_document");
    die;
    
}



sub start_element {
    my ( $self, $element ) = @_;

    my $name = $element->{Name};
    warn("START <$name>\n");
    $self->{node} = {
        tag => $name,
        children => [],
        atts => $element->{Attributes}{values},
        text => []
    };
    push @{$self->{stack}}, $self->{node};
}


sub end_element {
    my ( $self, $element ) = @_;

    my $node = pop @{$self->{stack}} || do {
        die("Stack error");
    };
    
    my $name = $element->{Name};
    warn("END </$name>\n");
    warn("Popped node = $node->{tag}\n");
    if( my $l = scalar @{$self->{stack}} ) {
        my $parent = $self->{stack}[$l - 1];
        push @{$parent->{children}}, $node;
        $self->{node} = $parent;
    } else {
        warn("Lost the root of the stack");
    }
    
    
}



sub characters {
    my ( $self, $chars ) = @_;

    $self->{node}{characters} .= $chars->{Data};

}




1;

