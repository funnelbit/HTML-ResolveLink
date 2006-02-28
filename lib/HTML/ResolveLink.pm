package HTML::ResolveLink;

use strict;
our $VERSION = '0.01';
use base qw(HTML::Parser);

use Carp;
use HTML::Tagset ();
use URI;

sub new {
    my($class, %p) = @_;
    my $self = $class->SUPER::new(
        start_h => [ \&_start_tag, "self,tagname,attr,attrseq,text" ],
        default_h => [ \&_default, "self,tagname,attr,text" ],
    );

    unless ($p{base}) {
        Carp::croak("HTML::ResolveLink->new: base is a required parameter");
    }

    $p{base} = URI->new($p{base}) unless ref $p{base};
    $self->{resolvelink_base} = $p{base};

    $self;
}

sub _start_tag {
    my($self, $tagname, $attr, $attrseq, $text) = @_;

    if ($tagname eq 'base' && defined $attr->{href}) {
        $self->{resolvelink_base} = $attr->{href};
    }

    my $base = $self->{resolvelink_base};

    my $links = $HTML::Tagset::linkElements{$tagname} || [];
    $links = [$links] unless ref $links;

    for my $a (@$links) {
        next unless exists $attr->{$a};

        my $link = $attr->{$a};
        my $uri  = URI->new($link);

        # relative link: 
        unless (defined $uri->scheme) {
            $uri = $uri->abs($base);
            $attr->{$a} = $uri->as_string;
        }
    }

    $self->{resolvelink_html} .= "<$tagname";
    for my $a (@$attrseq) {
        next if $a eq '/';
        $self->{resolvelink_html} .= sprintf qq( %s="%s"), $a, _escape($attr->{$a});
    }
    $self->{resolvelink_html} .= ' /' if $attr->{'/'};
    $self->{resolvelink_html} .= '>';
}

sub _default {
    my($self, $tagname, $attr, $text) = @_;
    $self->{resolvelink_html} .= $text;
}

my %escape = (
    '<' => '&lt;',
    '>' => '&gt;',
    '"' => '&qout;',
    '&' => '&amp;',
);
my $esc_re = join '|', keys %escape;

sub _escape {
    my $str = shift;
    $str =~ s/($esc_re)/$escape{$1}/g;
    $str;
}

sub resolve {
    my($self, $html) = @_;

    $self->{resolvelink_html} = ''; # init
    $self->parse($html);
    $self->eof;

    $self->{resolvelink_html};
}

1;
__END__

=head1 NAME

HTML::ResolveLink - Resolve relative links in (X)HTML into absolute URI

=head1 SYNOPSIS

  use HTML::ResolveLink;

  my $resolver = HTML::ResolveLink->new(
      base => 'http://www.example.com/foo/bar.html',
  );
  $html = $resolver->resolve($html);

=head1 DESCRIPTION

HTML::ResolveLink is a module to rewrite relative links in XHTML or
HTML into absolute URI.

For example. when you have

  <a href="foo.html">foo</a>
  <img src="/bar.gif" />

and use C<http://www.example.com/foo/bar> as C<base> URL, you'll get:

  <a href="http://www.example.com/foo/foo.html">foo</a>
  <img src="http://www.example.com/bar.gif" />

If the parser encounters C<< <base> >> tag in HTML, it'll honor that.

=head1 METHODS

=over 4

=item new

  my $resolver = HTML::ResolveLink->new(
      base => 'http://www.example.com/',
  );

C<base> is a required parameter, which is used to resolve the relative
URI found in the document.

=item resolve

  $html = $resolver->resolve($html);

Resolves relative URI found in C<$html> into absolute and returns a
string containing rewritten one.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<HTML::Parser>, L<HTML::LinkExtor>

=cut