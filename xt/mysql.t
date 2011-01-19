use strict;
use warnings;
use Test::mysqld;
use Test::More;
use DBI;
use DBIx::TransactionManager;

my $mysql = Test::mysqld->new
    or plan skip_all => $Test::mysqld::errstr;

my $dbh = DBI->connect($mysql->dsn( dbname => "test" ));
$dbh->do(q{
    CREATE TABLE job (
        id   INTEGER PRIMARY KEY auto_increment,
        func text
    )
});

my $tm = DBIx::TransactionManager->new($dbh);

{
    my $txn = $tm->txn_scope;
    $dbh->do("insert into job (func) values ('baz')");
    {
        my $txn2 = $tm->txn_scope;
        $dbh->do("insert into job (func) values ('bab')");
        $txn2->commit;
    }
    $txn->commit;

    my $row = $dbh->selectrow_hashref('select * from job');
    ok $row;
}

done_testing;
