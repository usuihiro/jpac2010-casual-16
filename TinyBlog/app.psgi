use lib "lib";
use Plack::Builder;
use TinyBlog;
my $app = sub {
    TinyBlog->run( @_ );
};
builder {
    enable "Plack::Middleware::Static",
      path => sub { s!^/img/!! }, root => 'img/';
    $app;
}
