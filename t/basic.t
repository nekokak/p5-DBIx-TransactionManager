use strict;
use warnings;
use t::Utils;
use Test::More;
use DBIx::TransactionManager;


subtest 'do basic transaction' => sub {
    my $dbh = t::Utils::setup;
    my $tm = DBIx::TransactionManager->new($dbh);

    $tm->txn_begin;
    
        $dbh->do("insert into foo (id, var) values (1,'baz')");

    $tm->txn_commit;

    my $row = $dbh->selectrow_hashref('select * from foo');
    is $row->{id},  1;
    is $row->{var}, 'baz';
};
 
subtest 'do rollback' => sub {
    my $dbh = t::Utils::setup;
    my $tm = DBIx::TransactionManager->new($dbh);

    $tm->txn_begin;
    
        $dbh->do("insert into foo (id, var) values (2,'bal')");

    $tm->txn_rollback;

    my $row = $dbh->selectrow_hashref('select * from foo');
    ok not $row;
};
 
done_testing;


