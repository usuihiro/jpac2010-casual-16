use utf8;

package MyModel;
use DBIx::Skinny connect_info => {
    dsn => 'dbi:SQLite:dbname=test.db',
};

__PACKAGE__->dbh->do( q{
    create table if not exists blog (
        id integer primary key,
        body varchar(14),
        tag varchar(30),
        image varchar(255),
        created_at date,
        updated_at date
    )
});

package MyModel::Schema;
use DBIx::Skinny::Schema;
use DBIx::Skinny::InflateColumn::DateTime;
use DateTime;

install_table blog => schema {
    pk 'id';
    columns qw/id body tag image created_at updated_at/;
    trigger pre_insert => sub {
        my ( $class, $args ) = @_;
        $args->{created_at} ||= DateTime->now( time_zone => 'Asia/Tokyo');
        $args->{updated_at} ||= $args->{created_at};
    };
    trigger pre_update => sub {
        my ( $class, $args ) = @_;
        $args->{updated_at} ||= DateTime->now( time_zone => 'Asia/Tokyo');
    }
};

package MyForm;
use Encode;
use HTML::Shakan::Declare;

form 'post' => (
    TextField(
        name => 'body',
        label => 'Body:',
        widget => 'textarea',
        required => 1,
        filters => ['WhiteSpace'],
        constraints => [
            [ 'LENGTH', 1, 30 ],
        ]
    ),
    ChoiceField(
        name => 'tag',
        label => 'Tag:',
        choices => [ map { ( encode_utf8 $_ ) x 2 } 
                    qw(ネタ これはヒドイ)],
    ),
    ImageField(
        name => 'image',
        label => 'Image:'
    ),
);

package MyRenderer;
use Any::Moose;
use HTML::Shakan::Utils;
# HTML::Shakan::Renderer::HTML より拝借
# field毎にpタグをつけて返す

has 'id_tmpl' => (
    is => 'ro',
    isa => 'Str',
    default => 'id_%s',
);

sub render {
    my ($self, $form) = @_;

    my @res;
    for my $field ($form->fields) {
        my @row;
        unless ($field->id) {
            $field->id(sprintf($self->id_tmpl(), $field->{name}));
        }
        if ($field->label) {
            push @row, sprintf( q{<label for="%s">%s</label>},
                $field->{id}, encode_entities( $field->{label} ) );
        }
        push @row, $form->widgets->render( $form, $field );
        push @res, join '', @row;
    }

    '<p>' . (join '</p><p>', @res) . '</p>';
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;

package TinyBlog;
our $VERSION = '0.01';
use strict;
use Text::Xslate qw(mark_raw);
use Plack::Request;
use Data::Section::Simple qw(get_data_section);
use HTML::Shakan::Model::DBIxSkinny;
use Encode;
use File::Copy qw(mv);

sub run {
    my $class = shift;
    my ( $env ) = @_;
    my $req = Plack::Request->new( $env );

    # XXX $req->param('image')が入ってないとvalidation効かないみたい
    if ($req->upload('image')) {
        $req->parameters->add('image', $req->upload('image')->filename);
    }

    my $model = MyModel->new;
    my $form = MyForm->get(
        'post', 
        request => $req,  
        model => HTML::Shakan::Model::DBIxSkinny->new(),
        renderer => MyRenderer->new,
    );
    $form->load_function_message('ja');

    my %param;
    if (my $id = $req->param('id')) {
        # edit or update
        my $article = MyModel->single('blog', { id => $id });
        if ($form->submitted) {
            # update
            if ($form->has_error) {
                my $msg = $form->get_error_messages;
                $param{errors} = [ map { encode_utf8($_) } @$msg ];
            } else {
                if (my $upload = $form->upload('image')) {
                    my $fname = $req->upload('image')->filename;
                    mv( $upload->{upload}->path, "img/$fname");
                }
                $form->model->update( $article );
            }
        } else {
            # edit
            $form->model->fill( $article );
        }
    } else {
        if ($form->submitted) {
            # new post
            if ($form->has_error) {
                my $msg = $form->get_error_messages;
                $param{errors} = [ map { encode_utf8($_) } @$msg ];
            } else {
                if (my $upload = $form->upload('image')) {
                    my $fname = $req->upload('image')->filename;
                    mv( $upload->{upload}->path, "img/$fname");
                }
                $form->model->create( $model => 'blog' );
            }
        }
    }


    my @articles = MyModel->search('blog', {}, 
        { order_by => {created_at => 'desc'}});
    $param{articles} = \@articles;
    $param{form_html} = mark_raw(  $form->render );
    
    my $tmpl = encode_utf8 get_data_section('index.tx');
    my $tx = Text::Xslate->new();
    my $body = $tx->render_string( $tmpl, \%param );

    return [200, ['Content-Type' => 'text/html;charset=utf8'], [ $body ] ];
}

1;

__DATA__

@@ index.tx
<!doctype html>
<body>
<h1>TinyBlog</h1>
<a href="?new">new</a>
<ul class="error">
: for $errors -> $err {
  <li><: $err :></li>
: }
</ul>
</pre>
<form method="post" action="" enctype="multipart/form-data">
  : $form_html
  <input type="submit" />
</form>

<ul>
:for $articles -> $article {
<li>
<p>[<: $article.tag :>]<a href="?id=<: $article.id :>">edit</a><p>
<p><: $article.body :></p>
<p><img src="img/<: $article.image :>" /></p>
<p>
作成：<: $article.created_at.strftime('%Y年%m月%d日 %H時%M分') :>
</p>
<p>
更新：<: $article.updated_at.strftime('%Y年%m月%d日 %H時%M分') :>
</p>
</li>
:}
</ul>
</body>

