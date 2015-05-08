package CoataGlue::Converter::OAIPMH::Omeka_XML;

use strict;
use base qw( XML::SAX::Base );

use Data::Dumper;

our $VERSION = 'v1.00.0';

=head1 NAME

CoataGlue::Converter::OAIPMH::Omeka_XML - class for parsing Omeka-xml records

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 new()

=cut

sub new {
    my ( $class, %opts ) = @_;
    my $self = bless \%opts, ref( $class ) || $class;
    return( $self );
}


sub start_document {
    my $self->{_collect} = 0;
}


sub start_element {
    my ( $self, $element ) = @_;

    my $name = $element->{Name};
    warn("Start element $name");
  SWITCH: {
      $name eq 'item' && do {
          $self->{itemId} = $element->{Attributes}{itemId}{value};
          last SWITCH;
      };

      $name =~ /^collection|itemType|files/ && do {
          $self->{section} = $name;
          last SWITCH;
      };

      $name =~ /^elementSet$/ && do {
          $self->{elementSetID} = $element->{Attributes}{elementSetId}{value};
          if( !$self->{section} ) {
              $self->{section} = 'item';
              $self->{values} = {};
          }
          last SWITCH;
      };

      $name =~ /^elementText$/ && do {
          $self->{element} = [];
          $self->{_collect} = 1;
          last SWITCH;
      };

      $name =~ /^name$/ && do {
          $self->{name} = '';
          $self->{text} = [];
          $self->{_collect} = 1;
          last SWITCH;
      };

    }
}


sub end_element {
    my ( $self, $element ) = @_;

    my $name = $element->{Name};

    return unless $self->{section};
    
  SWITCH: {
      $name eq 'name' && do {
          $self->{name} = $self->{characters};
          $self->{characters} = '';
          $self->{text} = [];
          $self->{_collect} = 0;
          last SWITCH;
      };

      $name eq 'elementText' && do {
          push @{$self->{text}}, $self->{characters};
          $self->{characters} = '';
          last SWITCH;
      };
      
      $name eq 'element' && do {
          if( $self->{name} ) {
              $self->{values}{$self->{name}} = $self->{text};
              delete $self->{name};
          }
          $self->{_collect} = 0;
          last SWITCH;
      };

      $name eq 'elementSet' && do {
          if( $self->{section} ) {
              my $s = $self->{section};
              $self->{sections}{$s} = $self->{values};
              delete $self->{section};
              delete $self->{values};
          }
          last SWITCH;
      };
      
    }
}




# Only bother accumulating characters if we're within an interesting
# section element

sub characters {
    my ( $self, $chars ) = @_;
    warn(Dumper({ _collect => $self->{_collect}, text => $self->{text}, section => $self->{section}, elementID => $self->{elementID} })); 
    if( $self->{_collect} ) {
        $self->{characters} .= $chars->{Data};
    }
}




1;

