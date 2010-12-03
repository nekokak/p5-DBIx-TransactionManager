use strict;
use warnings;
use utf8;
use t::Utils;
use Test::More;
use DBIx::TransactionManager;

my $dbh = t::Utils::setup;

subtest 'do scope commit' => sub {
    my $tm = DBIx::TransactionManager->new($dbh);

    my $txn = $tm->txn_scope;

        $dbh->do("insert into foo (id, var) values (1,'baz')");

    $txn->commit;

    my $row = $dbh->selectrow_hashref('select * from foo');
    is $row->{id},  1;
    is $row->{var}, 'baz';

    $dbh->do('delete from foo');
    done_testing;
};
 
subtest 'do scope rollback' => sub {
    my $tm = DBIx::TransactionManager->new($dbh);

    my $txn = $tm->txn_scope;

        $dbh->do("insert into foo (id, var) values (2,'boo')");

    $txn->rollback;

    my $row = $dbh->selectrow_hashref('select * from foo');
    ok not $row;

    done_testing;
};
 
subtest 'do scope guard for rollback' => sub {
 
    my $tm = DBIx::TransactionManager->new($dbh);

    {
        local $SIG{__WARN__} = sub {};
        my $txn = $tm->txn_scope;
        $dbh->do("insert into foo (id, var) values (3,'bebe')");
    } # do rollback auto.
 
    my $row = $dbh->selectrow_hashref('select * from foo');
    ok not $row;

    done_testing;
};


subtest 'do nested scope rollback-rollback' => sub {
    my $tm = DBIx::TransactionManager->new($dbh);

    my $txn = $tm->txn_scope;
    {
        my $txn2 = $tm->txn_scope;
            $dbh->do("insert into foo (id, var) values (4,'kumu')");
        $txn2->rollback;
    }
    $dbh->do("insert into foo (id, var) values (5,'kaka')");
    $txn->rollback;

    ok not $dbh->selectrow_hashref('select * from foo');
    done_testing;
};

subtest 'do nested scope commit-rollback' => sub {
    my $tm = DBIx::TransactionManager->new($dbh);

    my $txn = $tm->txn_scope;
    {
        my $txn2 = $tm->txn_scope;
            $dbh->do("insert into foo (id, var) values (6,'muki')");
        $txn2->commit;
        ok $dbh->selectrow_hashref('select * from foo');
    }
    $dbh->do("insert into foo (id, var) values (7,'mesi')");
    $txn->rollback;

    ok not $dbh->selectrow_hashref('select * from foo');
    done_testing;
};

subtest 'do nested scope rollback-commit' => sub {
    my $tm = DBIx::TransactionManager->new($dbh);

    {
        local $SIG{__WARN__} = sub {};
        my $txn = $tm->txn_scope;
        {
            my $txn2 = $tm->txn_scope;
                $dbh->do("insert into foo (id, var) values (8,'uso')");
            $txn2->rollback;
        }
        $dbh->do("insert into foo (id, var) values (9,'nani')");
        eval {$txn->commit}; # XXX
        like $@, qr/tried to commit but already rollbacked in nested transaction./;
    }

    my $row = $dbh->selectrow_hashref('select * from foo');
    ok not $dbh->selectrow_hashref('select * from foo');
    done_testing;
};

subtest 'do nested scope commit-commit' => sub {
    my $tm = DBIx::TransactionManager->new($dbh);

    my $txn = $tm->txn_scope;
    {
        my $txn2 = $tm->txn_scope;
            $dbh->do("insert into foo (id, var) values (10,'ahi')");
        $txn2->commit;
    }
    $dbh->do("insert into foo (id, var) values (11,'uhe')");
    $txn->commit;

    my @rows = $dbh->selectrow_array('select * from foo');
    is scalar(@rows), 2;
    done_testing;
};

done_testing;

