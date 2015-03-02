#!perl6

use v6;
use lib 'lib';

use DBIish;
use Template::Mojo;

my $lock = 'gen-report.lock'.IO;
exit if $lock.e;

'gen-report.lock'.IO.open(:w).close; # that's like `touch gen-report.lock`

# database configuration
DBIish.install_driver('Pg');
my $dbh = DBIish.connect('Pg',
    :user<cpandatesters>, :password<cpandatesters>,
    :host<localhost>, :port<5432>, :dbname<cpandatesters>,
    :RaiseError
);

my &report-details := Template::Mojo.new(slurp 'views/report-details.tt').code;
my &main           := Template::Mojo.new(slurp 'views/main.tt').code;

my $mark = $dbh.prepare('UPDATE reports
                         SET "gen-report" = FALSE
                         WHERE id = ?');
my $todo = $dbh.prepare('SELECT *
                         FROM reports
                         WHERE "gen-report"');
$todo.execute();
while $todo.fetchrow_hashref -> $r {
    my $report-data = from-json $r<raw>;
    my $name = $report-data<name>;
    my $initial = $name.substr(0, 1).uc;
    "html/reports/$r<id>.html".IO.spurt: main({
        :breadcrumb(["/dist/$initial/$report-data<name>" R=> $report-data<name>, "Report $r<id>"]),
        :content( report-details($r, $report-data) ),
        :path(''),
    });
    $mark.execute($r<id>);
}

$dbh.disconnect();
$lock.unlink;

CATCH {
    $lock.unlink;
}
