package Graphics::Primitive::Driver::GD;
use Moose;

our $VERSION = '0.01';

use GD;

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
    $self->gd->setThickness($brush->width);

    my @dash_style = ();
    if(defined($dash) && scalar(@{ $dash })) {
        foreach my $dc (@{ $dash }) {
            for (0..$dc) {
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
        my ($mt, $mr, $mb, $ml) = $comp->margins->as_array;
        # GD's alpha is backward from Graphics::Color::RGB's...
        my $color = $self->convert_color($bc);
        $self->rel_move_to($mr, $mt);

        $gd->filledRectangle(
            $self->current_x,
            $self->current_y,
            $self->current_x + $comp->width - $ml,
            $self->current_y + $comp->height - $mb,
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

# sub _draw_complex_border {
#     my ($self, $comp) = @_;
# 
#     my ($mt, $mr, $mb, $ml) = $comp->margins->as_array;
# 
#     my $gd = $self->gd;
#     my $border = $comp->border;
# 
#     my $width = $comp->width;
#     my $height = $comp->height;
# 
#     my $bt = $border->top;
#     my $thalf = (defined($bt) && defined($bt->color))
#         ? $bt->width / 2: 0;
# 
#     my $br = $border->right;
#     my $rhalf = (defined($br) && defined($br->color))
#         ? $br->width / 2: 0;
# 
#     my $bb = $border->bottom;
#     my $bhalf = (defined($bb) && defined($bb->color))
#         ? $bb->width / 2 : 0;
# 
#     my $bl = $border->left;
#     my $lhalf = (defined($bl) && defined($bl->color))
#         ? $bl->width / 2 : 0;
# 
#     my $o = $comp->origin;
#     my $ox = $o->x;
#     my $oy = $o->y;
# 
#     if($thalf) {
#         $gd->line(
#             $ml, $mt + $thalf
#         );
#         $context->move_to($ml, $mt + $thalf);
#         $context->set_source_rgba($bt->color->as_array_with_alpha);
# 
#         $context->set_line_width($bt->width);
#         $context->rel_line_to($width - $mr - $ml, 0);
# 
#         my $dash = $bt->dash_pattern;
#         if(defined($dash) && scalar(@{ $dash })) {
#             $context->set_dash(0, @{ $dash });
#         }
# 
#         $context->stroke;
# 
#         $context->set_dash(0, []);
#     }
# 
#     if($rhalf) {
#         $context->move_to($width - $mr - $rhalf, $mt);
#         $context->set_source_rgba($br->color->as_array_with_alpha);
# 
#         $context->set_line_width($br->width);
#         $context->rel_line_to(0, $height - $mb);
# 
#         my $dash = $br->dash_pattern;
#         if(defined($dash) && scalar(@{ $dash })) {
#             $context->set_dash(0, @{ $dash });
#         }
# 
#         $context->stroke;
#         $context->set_dash(0, []);
#     }
# 
#     if($bhalf) {
#         $context->move_to($width - $mr, $height - $bhalf - $mb);
#         $context->set_source_rgba($bb->color->as_array_with_alpha);
# 
#         $context->set_line_width($bb->width);
#         $context->rel_line_to(-($width - $mb), 0);
# 
#         my $dash = $bb->dash_pattern;
#         if(defined($dash) && scalar(@{ $dash })) {
#             $context->set_dash(0, @{ $dash });
#         }
# 
#         $context->stroke;
#     }
# 
#     if($lhalf) {
#         $context->move_to($ml + $lhalf, $mt);
#         $context->set_source_rgba($bl->color->as_array_with_alpha);
# 
#         $context->set_line_width($bl->width);
#         $context->rel_line_to(0, $height - $mb);
# 
#         my $dash = $bl->dash_pattern;
#         if(defined($dash) && scalar(@{ $dash })) {
#             $context->set_dash(0, @{ $dash });
#         }
# 
#         $context->stroke;
#         $context->set_dash(0, []);
#     }
# }

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
    # $context->set_line_cap($top->line_cap);
    # $context->set_line_join($top->line_join);

    my $swhalf = $bswidth / 2;
    my $width = $comp->width;
    my $height = $comp->height;
    my $mx = $margins[3];
    my $my = $margins[1];

    $self->set_style($top);
    # my $dash = $top->dash_pattern;
    # if(defined($dash) && scalar(@{ $dash })) {
    #     my @dash_style = ();
    #     foreach my $dc (@{ $dash }) {
    #         for (0..$dc) {
    #             push(@dash_style, $color);
    #         }
    #     }
    # 
    #     $gd->setStyle(@dash_style);
    #     # $context->set_dash(0, @{ $dash });
    # } else {
    #     my @dash_style = ( $color );
    #     $gd->setStyle(@dash_style);
    # }

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
