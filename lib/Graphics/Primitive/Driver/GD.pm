package Graphics::Primitive::Driver::GD;
use Moose;

our $VERSION = '0.01';

use GD;

with 'Graphics::Primitive::Driver';

has 'gd' => (
    is => 'ro',
    isa => 'GD::Image',
    lazy_build => 1
);

sub _do_fill {}
sub _do_stroke {}
sub _draw_bezier {}
sub _draw_circle {}
sub _draw_complex_border {}
sub _draw_ellipse {}
sub _draw_line {}
sub _draw_path {}
sub _draw_polygon {}
sub _draw_rectangle {}
sub _draw_textbox {}
sub _finish_page {}
sub _resize {}

sub get_textbox_layout {}
sub reset {}

sub _build_gd {
    my ($self) = @_;

    return GD::Image->new($self->width, $self->height, 1);
}

sub data {
    my ($self) = @_;

    # XX PNG only?
    return $self->gd->png;
}

sub write {
    my ($self, $file) = @_;

    my $fh = IO::File->new($file, 'w')
        or die("Unable to open '$file' for writing: $!");
    $fh->binmode;
    $fh->print($self->data);
    $fh->close;
}

sub _draw_canvas {
    my ($self, $comp) = @_;

    $self->_draw_component($comp);

    foreach (@{ $comp->paths }) {
        $self->_draw_path($_->{path}, $_->{op});
    }
}

sub _draw_component {
    my ($self, $comp) = @_;

    my $gd = $self->gd;

    my $bc = $comp->background_color;
    if(defined($bc)) {
        my $o = $comp->origin;
        my $ox = $o->x;
        my $oy = $o->y;

        my ($mt, $mr, $mb, $ml) = $comp->margins->as_array;
        # GD's alpha is backward from Graphics::Color::RGB's...
        my $color = $gd->colorAllocateAlpha($bc->red * 255, $bc->green * 255, $bc->blue * 255, 127 - ($bc->alpha * 127));
        # X,Y position is wrong?
        $gd->filledRectangle(
            $ox + $mr,
            $oy + $mt,
            $ox + $comp->width - $mr - $ml,
            $ox + $comp->height - $mt - $mb,
            $color
        );
    }

    my $border = $comp->border;
    if(defined($border)) {
        if($border->homogeneous) {
            if($border->top->width) {
                $self->_draw_simple_border($comp);
            }
        } else {
            $self->_draw_complex_border($comp);
        }
    }
}

sub _draw_simple_border {
    my ($self, $comp) = @_;

    my $gd = $self->gd;

    my $border = $comp->border;
    my $top = $border->top;
    my $bswidth = $top->width;
    my $o = $comp->origin;
    my $ox = $o->x;
    my $oy = $o->y;

    print STDERR "WEEE\n";

    my $c = $comp->border->top->color;
    my $color = $gd->colorAllocateAlpha($c->red * 255, $c->green * 255, $c->blue * 255, 127 - ($c->alpha * 127));
    # $context->set_source_rgba($top->color->as_array_with_alpha);

    my @margins = $comp->margins->as_array;

    $gd->setThickness($bswidth);
    # $context->set_line_cap($top->line_cap);
    # $context->set_line_join($top->line_join);

    # $context->new_path;
    my $swhalf = $bswidth / 2;
    my $width = $comp->width;
    my $height = $comp->height;
    my $mx = $margins[3];
    my $my = $margins[1];

    my $dash = $top->dash_pattern;
    if(defined($dash) && scalar(@{ $dash })) {
        my @dash_style = ();
        foreach my $dc (@{ $dash }) {
            for (0..$dc) {
                push(@dash_style, $color);
            }
        }
        $gd->setStyle(@dash_style);
        # $context->set_dash(0, @{ $dash });
    } else {
        my @dash_style = ( $color );
        $gd->setStyle(@dash_style);
    }

    $gd->rectangle(
        $ox + $margins[3] + $swhalf, $oy + $margins[0] + $swhalf,
        $ox + $width - $bswidth - $margins[3] - $margins[1] + $swhalf,
        $oy + $height - $bswidth - $margins[2] - $margins[0] + $swhalf,
        gdStyled
    );
}

__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Graphics::Primitive::Driver::GD - The great new Graphics::Primitive::Driver::GD!

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Graphics::Primitive::Driver::GD;

    my $foo = Graphics::Primitive::Driver::GD->new();
    ...

=head1 AUTHOR

Cory G Watson, C<< <gphat at cpan.org> >>

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2009 Cory G Watson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
