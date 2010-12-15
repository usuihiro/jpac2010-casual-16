use common::sense;
use CGI;
use HTML::Shakan;
use YAML;

sub test {
    my $req = shift; # CGIとかPlack::Requestとか
    # フォームオブジェクトを作る
    my $form = HTML::Shakan->new(
        fields => [
            EmailField(
                name => 'mail',
                label => 'E-mail address', # labelタグをつける
                filters => ['WhiteSpace'], # 空白を取り除くHTML::Shakan::Filters::*を参照
                required => 1
            ),
            PasswordField(
                name => 'password',
                label => 'Password',
                filters => ['WhiteSpace'],
                required => 1,
            )
        ],
        request => $req,
    );

    # 日本語デフォルトメッセージをロード。SEE ALSO FormValidator::Lite
    $form->load_function_message('ja');
    # バリデーションチェック
    if ($form->submitted_and_valid) {
        # フィルター済かつバリデーション済みの値を取得
        my $mail = $form->param('mail');
        my $password = $form->param('password');
        say "mail = '$mail', password = '$password'";
        # DB問い合わせなど
    } else {
        # エラーの場合
        my $errors = $form->get_error_messages();
        say Dump( $errors );
    }
    # フォームタグ生成
    say $form->render;
}

my $req1 = CGI->new();
$req1->param( mail => 'hogehoge' );
test( $req1 );

my $req2 = CGI->new();
$req2->param( mail => '   hogehoge@hoge.com   ' );
$req2->param( password => '  hogehoge  ' );
test( $req2 );
    
