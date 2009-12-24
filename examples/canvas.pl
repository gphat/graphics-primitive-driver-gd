use strict;

use Graphics::Color::RGB;
use Graphics::Primitive::Border;
use Graphics::Primitive::Canvas;
use Graphics::Primitive::Driver::GD;
use Graphics::Primitive::Operation::Stroke;

my $c = Graphics::Primitive::Canvas->new(
  background_color => Graphics::Color::RGB->new(
      red => 1, green => 1, blue => 0, alpha => 1
  ),
  width => 500, height => 350,
  border => new Graphics::Primitive::Border->new(
      color => Graphics::Color::RGB->new(
          red => 1, green => 0, blue => 0, alpha => 1
      ),
      width => 5
  )
);
$c->path->move_to(50, 50);
$c->path->line_to(20, 0);
$c->do(Graphics::Primitive::Operation::Stroke->new);

my $driver = Graphics::Primitive::Driver::GD->new;

$driver->prepare($c);
$driver->finalize($c);
$driver->draw($c);
$driver->write('foo.png');
