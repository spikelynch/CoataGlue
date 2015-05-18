package CoataGlue::Converter::OAIPMH::Omeka_XML;

use strict;
use base qw( XML::SAX::Base );

use Data::Dumper;

our $VERSION = 'v1.00.0';

=head1 NAME

CoataGlue::Converter::OAIPMH::Omeka_XML - XML::SAX handler for Omeka-xml

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 METHODS

=head2 new()

=head1 METADATA

Converted metadata is stored in the {md} member, as follows

=over 4

=item itemID - the item's Omeka ID

=item collectionID - the collection ID, if item belongs to a collection

=item collectionTitle - the collection title

=item itemType - the item type

=item itemTypeID - 

=item itemTypeDetails - some items have contextual info here

=item item - the main metadata for the item, as a hashref.  Not all
items will have a value for every field.

=over 4

=item Title

=item Creator

=item Description

=item Subject

=item Format

=item License

=item Date

=item Contributor

=item Spatial Coverage

=item Language

=item Access Rights

=item Publisher

=item 

=back

=item tags - arrayref of tags

=item files - hashref of files by file ID: each file is represented by

=over 4

=item src (the URL of the file)

=item details

=over 4

=item Title

=back

=back


=cut
    


sub new {
    my ( $class, %opts ) = @_;
    my $self = bless \%opts, ref( $class ) || $class;
    $self->{root} = { 
        tag => '_root',
        children => []
    };
    $self->{stack} = [ $self->{root} ];
    $self->{md} = {};

    return( $self );
}

# open_item - this gets hit on every item

sub open_item {
    my ( $self, $node ) = @_;

    $self->{md}{itemID} = $self->att($node, 'itemId');
    $self->{elementset} = {};
}


sub close_item {
    my ( $self, $node ) = @_;

    if( ! $self->{item_metadata} ) {
        warn("No item-level metadata");
    } else {
        $self->{md}{item} = $self->{item_metadata};
    }
}


# close_collection - all we use from collection are the id and Title

sub open_collection {
    my ( $self, $node ) = @_;
}

sub close_collection {
    my ( $self, $node ) = @_;

    $self->{md}{collectionID} = $self->att($node, 'collectionId');
    $self->{md}{collectionTitle} = $self->{elementset}{Title};
    $self->{elementset} = {};
}

# itemType has to start its own elementset because it doesn't
# encapsulate its values in an <elementSet>

sub open_itemType {
    my ( $self, $node ) = @_;

    my $self->{elementset} = {};
}


sub close_itemType {
    my ( $self, $node ) = @_;

    my ( $name ) = $self->_nodeChildren($node, 'name');
    
    $self->{md}{itemType} = $name->{text} || [ 'Unknown' ];
    $self->{md}{itemTypeID} = $self->att($node, 'itemTypeId');
    $self->{md}{itemTypeDetails} = $self->{elementset};
}

# files

sub open_fileContainer {
    my ( $self, $node ) = @_;

    $self->{files} = {};
}

sub close_fileContainer {
    my ( $self, $node ) = @_;

    if( keys %{$self->{files}} ) {
        $self->{md}{files} = $self->{files};
    }
}



sub close_file {
    my ( $self, $node ) = @_;

    my $file = {
        id => $self->att($node, 'fileId')
    };

    my ( $src ) = $self->_nodeChildren($node, 'src');

    if( $src ) {
        $file->{src} = $self->trim_text($src->{text});
    } else {
        warn("file tag without src child ($file->{id})");
        $file->{src} = '';
    }

    if( keys %{$self->{elementset}} ) {
        $file->{details} = $self->{elementset};
        $self->{elementset} = {};
    }
    
    $self->{files}{$file->{id}} = $file;
}


# tags

sub open_tagContainer {
    my ( $self, $node ) = @_;

    $self->{md}{tags} = [];
}

sub close_tag {
    my ( $self, $node ) = @_;

    my ( $tagname ) = $self->_nodeChildren($node, 'name');

    push @{$self->{md}{tags}}, $self->trim_text($tagname->{text});
}



# open_elementSet and closeElement turn an <elementSet> into a hashref
# of values by <name>.  Values are arrayrefs.

sub open_elementSet {
    my ( $self, $node ) = @_;

    $self->{elementset} = {};
}

# if this elementSet is item/elementSetContainer/elementSet, stash
# the values so that subsequent elementSets don't clobber it

sub close_elementSet {
    my ( $self, $node ) = @_;

    my $grandparent = @{$self->{stack}}[-2];

    if( $grandparent->{tag} eq 'item' ) {
        $self->{item_metadata} = $self->{elementset};
    }
}



sub close_element {
    my ( $self, $node ) = @_;

    my ( $name ) = $self->_nodeChildren($node, 'name');
    my ( $evalues ) = $self->_nodeChildren($node, 'elementTextContainer');
    
    if( $name && $evalues ) {

        my $values = [];
        my $ntext = $self->trim_text($name->{text});
        for my $et ( $self->_nodeChildren($evalues, 'elementText') ) {
            my ( $text ) = $self->_nodeChildren($et, 'text');
            push @$values, $self->trim_text($text->{text});
        }

        if( $self->{elementset}{$ntext} ) {
            warn("More than one element value with $ntext: " . join(', ', @$values));
        }
        $self->{elementset}{$ntext} = $values;
    } else {
        warn("<element> without <name> and <elementTextContainer>");
    }
}






sub _nodeChildren {
    my ( $self, $node, $tag ) = @_;

    if( $node->{children} ) {
        return grep { $_->{tag} eq $tag } @{$node->{children}};
    } else {
        return ();
    }
}

sub att {
    my ( $self, $node, $att ) = @_;

    my $jclark = "{}$att";

    if( $node->{atts}{$jclark} ) {
        return $node->{atts}{$jclark}{Value};
    } else {
        warn("Missing attribute $jclark");
        return undef;
    }
}


sub _stacktrace {
    my ( $self ) = @_;

    return join('/', map { $_->{tag} } @{$self->{stack}});
}


# return an array of children with the tag $tag from a node


sub start_element {
    my ( $self, $element ) = @_;

    my $name = $element->{Name};

    $self->{node} = {
        tag => $name,
        children => [],
        atts => $element->{Attributes},
        text => []
    };

    
    push @{$self->{stack}}, $self->{node};

    if( $self->can("open_$name") ) {
        my $handler = "open_$name";
        $self->$handler($self->{node});
    }

}


sub end_element {
    my ( $self, $element ) = @_;

    my $node = pop @{$self->{stack}} || do {
        die("Stack error");
    };    
    my $name = $element->{Name};

#    print "PATH " . join('/', map { $_->{tag} } @{$self->{stack}}) . "\n";
#    my $text = $self->trim_text($node->{text});

    if( $self->can("close_$name") ) {
        my $handler = "close_$name";
        $self->$handler($node);
    }

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

    push @{$self->{node}{text}}, $chars->{Data};

}


sub trim_text {
    my ( $self, $text ) = @_;

    my $t = '';

    for my $chunk ( @$text ) {
        $chunk =~ s/^\s*//;
        $chunk =~ s/\s*$//;
        if( $chunk ) {
            $t .= $chunk;
        }
    }
    return $t;
}



1;

