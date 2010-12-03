use strict;
use warnings;
use t::Utils;
use Test::More;
use DBIx::TransactionManager;

my $dbh = t::Utils::setup;

subtest 'do basic transaction' => sub {
    my $tm = DBIx::TransactionManager->new($dbh);

    $tm->txn_begin;
    
        $dbh->do("insert into foo (id, var) values (1,'baz')");

    $tm->txn_commit;

    my $row = $dbh->selectrow_hashref('select * from foo');
    is $row->{id},  1;
    is $row->{var}, 'baz';

    $dbh->do('delete from foo');
    done_testing;
};
 
subtest 'do rollback' => sub {
    my $tm = DBIx::TransactionManager->new($dbh);

    $tm->txn_begin;
    
        $dbh->do("insert into foo (id, var) values (2,'bal')");

    $tm->txn_rollback;

    my $row = $dbh->selectrow_hashref('select * from foo');
    ok not $row;
};
 
done_testing;


