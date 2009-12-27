d ~package Graphics::Primitive::Driver::GD;
use Moose;

our $VERSION = '0.01';

use GD;
use Math::Trig qw(rad2deg);

with 'Graphics::Primitive::Driver';

has 'current_x' => (
    is => 'rw',
    isa => 'Num',
    default => 0
);

has 'current_y' => (
    is => 'rw',
    isa => 'Num',
    default => 0
);

has 'fill_mode' => (
    is => 'rw',
    isa => 'Bool'
);

has 'gd' => (
    is => 'ro',
    isa => 'GD::Image',
    lazy_build => 1
);

sub _draw_textbox {}
sub _finish_page {}
sub _resize {}

sub get_textbox_layout {}
sub reset {}

sub _build_gd {
    my ($self) = @_;

    return GD::Image->new($self->width, $self->height, 1);
}

before('draw', sub {
    my ($self, $comp) = @_;

    my $o = $comp->origin;
    $self->move_to($o->x, $o->y);
});

sub data {
    my ($self) = @_;

    # XX PNG only?
    return $self->gd->png;
}

sub convert_color {
    my ($self, $color) = @_;

    return $self->gd->colorAllocateAlpha(
        $color->red * 255,
        $color->green * 255,
        $color->blue * 255,
        127 - ($color->alpha * 127)
    );
}

sub move_to {
    my ($self, $x, $y) = @_;

    $self->current_x($x);
    $self->current_y($y);
}

sub rel_move_to {
    my ($self, $x, $y) = @_;

    $self->current_x($self->current_x + $x);
    $self->current_y($self->current_y + $y);
}

sub set_style {
    my ($self, $brush) = @_;

    # Sets gdStyled to the dash pattern and sets the color
    my $dash = $brush->dash_pattern;
    my $color = $self->convert_color($brush->color);
    $self->gd->setAntiAliased($color);
    $self->gd->setThickness($brush->width);

    my @dash_style = ();
    if(defined($dash) && scalar(@{ $dash })) {
        foreach my $dc (@{ $dash }) {
            for (0..$dc) {
                # Try this?
                # push(@dash_style, ($color) x $dc);
                push(@dash_style, $color);
            }
        }
    } else {
        @dash_style = ( $color );
    }
    $self->gd->setStyle(@dash_style);
}

sub write {
    my ($self, $file) = @_;

    my $fh = IO::File->new($file, 'w')
        or die("Unable to open '$file' for writing: $!");
    $fh->binmode;
    $fh->print($self->data);
    $fh->close;
}

sub _do_stroke {
    my ($self, $op) = @_;

    my $gd = $self->gd;
    $self->fill_mode(0);

    $self->set_style($op->brush);
}

sub _do_fill {
    my ($self, $op) = @_;
    $self->fill_mode(1);

    $self->set_style($op->brush);
}

sub _draw_arc {
    my ($self, $comp) = @_;

    # No stroke!
    my $gd = $self->gd;
    $gd->arc(
        $self->current_x, $self->current_y, $comp->radius, $comp->radius,
        rad2deg($comp->angle_start), rad2deg($comp->angle_end), gdStyled
    );
}

sub _draw_bezier {
    my ($self, $bezier) = @_;

    my $context = $self->cairo;
    my $start = $bezier->start;
    my $end = $bezier->end;
    my $c1 = $bezier->control1;
    my $c2 = $bezier->control2;

    $context->curve_to($c1->x, $c1->y, $c2->x, $c2->y, $end->x, $end->y);
}

sub _draw_canvas {
    my ($self, $comp) = @_;

    $self->_draw_component($comp);

    foreach (@{ $comp->paths }) {
        $self->_draw_path($_->{path}, $_->{op});
    }
}

sub _draw_circle {
    my ($self, $comp) = @_;

    # No stroke!
    my $gd = $self->gd;
    if($self->fill_mode) {
        $gd->filledEllipse(
            $self->current_x, $self->current_y, $comp->radius, $comp->radius,
            gdStyled
        );
    } else {
        $gd->ellipse(
            $self->current_x, $self->current_y, $comp->radius, $comp->radius,
            gdStyled
        );
    }
}

sub _draw_component {
    my ($self, $comp) = @_;

    my $gd = $self->gd;

    my $bc = $comp->background_color;
    if(defined($bc)) {
        my ($mt, $mr, $mb, $ml) = $comp->margins->as_array;
        # GD's alpha is backward from Graphics::Color::RGB's...
        my $color = $self->convert_color($bc);
        $self->rel_move_to($mr, $mt);

        $gd->filledRectangle(
            $self->current_x,
            $self->current_y,
            $self->current_x + $comp->width - $ml - $mr - 1,
            $self->current_y + $comp->height - $mb - $mt - 1,
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

sub _draw_complex_border {
    my ($self, $comp) = @_;

    my ($mt, $mr, $mb, $ml) = $comp->margins->as_array;

    my $gd = $self->gd;
    my $border = $comp->border;

    my $width = $comp->width;
    my $height = $comp->height;

    my $bt = $border->top;
    my $thalf = (defined($bt) && defined($bt->color))
        ? $bt->width / 2: 0;

    my $br = $border->right;
    my $rhalf = (defined($br) && defined($br->color))
        ? $br->width / 2: 0;

    my $bb = $border->bottom;
    my $bhalf = (defined($bb) && defined($bb->color))
        ? $bb->width / 2 : 0;

    my $bl = $border->left;
    my $lhalf = (defined($bl) && defined($bl->color))
        ? $bl->width / 2 : 0;

    if($thalf) {
        $self->set_style($bt);
        $gd->line(
            $self->current_x,
            $self->current_y + $thalf,
            $self->current_x + $width - $mr - $ml - 1,
            $self->current_y + $thalf,
            gdStyled
        );
    }

    if($rhalf) {
        $self->set_style($br);
        $gd->line(
            $self->current_x + $width - $mr - $ml - $rhalf,
            $self->current_y,
            $self->current_x + $width - $mr - $ml - $rhalf,
            $self->current_y + $height - $mb - $mt - 1,
            gdStyled
        );
    }

    if($bhalf) {
        $self->set_style($bb);
        $gd->line(
            $self->current_x + $width - $mr - $ml - 1,
            $self->current_y + $height - $mb - $mt - $bhalf,
            $self->current_x,
            $self->current_y + $height - $mb - $mt - $bhalf,
            gdStyled
        );
    }

    if($lhalf) {
        $self->set_style($bl);
        $gd->line(
            $self->current_x + $lhalf,
            $self->current_y,
            $self->current_x + $lhalf,
            $self->current_y + $height - $mt - $mb - 1,
            gdStyled
        );
    }
}

sub _draw_ellipse {
    my ($self, $comp) = @_;

    # No stroke!
    my $gd = $self->gd;
    if($self->fill_mode) {
        $gd->filledEllipse(
            $self->current_x, $self->current_y, $comp->width, $comp->height,
            gdStyled
        );
    } else {
        $gd->ellipse(
            $self->current_x, $self->current_y, $comp->width, $comp->height,
            gdStyled
        );
    }
}

sub _draw_line {
    my ($self, $line) = @_;

    my $gd = $self->gd;

    my $end = $line->end;
    $gd->line($self->current_x, $self->current_y, $end->x, $end->y, gdStyled);
}

sub _draw_path {
    my ($self, $path, $op) = @_;

    my $gd = $self->gd;

    if($op->isa('Graphics::Primitive::Operation::Stroke')) {
        $self->_do_stroke($op);
    } elsif($op->isa('Graphics::Primitive::Operation::Fill')) {
        $self->_do_fill($op);
    }


    # If preserve count is set we've "preserved" a path that's made up 
    # of X primitives.  Set the sentinel to the the count so we skip that
    # many primitives
    # my $pc = $self->_preserve_count;
    # if($pc) {
    #     $self->_preserve_count(0);
    # } else {
    #     $context->new_path;
    # }

    my $pcount = $path->primitive_count;
    for(my $i = 0; $i < $pcount; $i++) {
        my $prim = $path->get_primitive($i);
        my $hints = $path->get_hint($i);

        if(defined($hints)) {
            unless($hints->{contiguous}) {
                my $ps = $prim->point_start;
                $self->move_to($ps->x, $ps->y);
            }
        }

        # FIXME Check::ISA
        if($prim->isa('Geometry::Primitive::Line')) {
            $self->_draw_line($prim);
        } elsif($prim->isa('Geometry::Primitive::Rectangle')) {
            $self->_draw_rectangle($prim);
        } elsif($prim->isa('Geometry::Primitive::Arc')) {
            $self->_draw_arc($prim);
        } elsif($prim->isa('Geometry::Primitive::Bezier')) {
            $self->_draw_bezier($prim);
        } elsif($prim->isa('Geometry::Primitive::Circle')) {
            $self->_draw_circle($prim);
        } elsif($prim->isa('Geometry::Primitive::Ellipse')) {
            $self->_draw_ellipse($prim);
        } elsif($prim->isa('Geometry::Primitive::Polygon')) {
            $self->_draw_polygon($prim);
        }
    }

    if($op->preserve) {
        $self->_preserve_count($path->primitive_count);
    }
}

sub _draw_polygon {
    my ($self, $comp) = @_;

    my $gd = $self->gd;
    my $poly = GD::Polygon->new;
    for(my $i = 1; $i < $poly->point_count; $i++) {
        my $p = $poly->get_point($i);
        $poly->addPto($p->x, $p->y);
    }
    if($self->fill_mode) {
        $gd->filledPolygon($poly, gdStyled);
    } else {
        $gd->openPolygon($poly, gdStyled);
    }
}

sub _draw_rectangle {
    my ($self, $comp) = @_;

    my $gd = $self->gd;
    if($self->fill_mode) {
        $gd->filledRectangle(
            $comp->origin->x, $comp->origin->y,
            $comp->origin->x + $comp->width, $comp->origin->y + $comp->height
        );
    } else {
        $gd->rectangle(
            $comp->origin->x, $comp->origin->y,
            $comp->origin->x + $comp->width, $comp->origin->y + $comp->height
        );
    }
}

sub _draw_simple_border {
    my ($self, $comp) = @_;

    my $gd = $self->gd;

    my $border = $comp->border;
    my $top = $border->top;
    my $bswidth = $top->width;

    my $c = $comp->border->top->color;
    my $color = $gd->colorAllocateAlpha(
        $c->red * 255, $c->green * 255, $c->blue * 255, 127 - ($c->alpha * 127)
    );

    my @margins = $comp->margins->as_array;

    $gd->setThickness($bswidth);

    my $swhalf = $bswidth / 2;
    my $width = $comp->width;
    my $height = $comp->height;
    my $mx = $margins[3];
    my $my = $margins[1];

    $self->set_style($top);

    $self->rel_move_to($margins[3], $margins[0]);
    $gd->rectangle(
        $self->current_x + $swhalf,
        $self->current_y + $swhalf,
        $self->current_x + $width - $bswidth - $margins[1] + $swhalf,
        $self->current_y + $height - $bswidth - $margins[0] + $swhalf,
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
