package DBIx::TransactionManager;
use strict;
use warnings;
use Carp ();
our $VERSION = '1.11';

sub new {
    my ($class, $dbh) = @_;

    unless ($dbh) {
        Carp::croak('missing mandatory parameter dbh');
    }

    bless {
        dbh => $dbh,
        active_transactions => [],
        rollbacked_in_nested_transaction => 0,
    }, $class;
}

sub txn_scope {
    DBIx::TransactionManager::ScopeGuard->new( @_ );
}

sub txn_begin {
    my ($self, %args) = @_;

    my $caller = $args{caller} || [ caller(0) ];
    my $txns   = $self->{active_transactions};
    my $rc = 1;
    if (@$txns == 0 && $self->{dbh}->FETCH('AutoCommit')) {
        $rc = $self->{dbh}->begin_work;
    }
    if ($rc) {
        push @$txns, { caller => $caller, pid => $$ };
    }
}

sub txn_rollback {
    my $self = shift;
    my $txns = $self->{active_transactions};
    return unless @$txns;

    my $current = pop @$txns; 
    if ( @$txns > 0 ) {
        # already popped, so if there's anything, we're in a nested
        # transaction, mate.
        $self->{rollbacked_in_nested_transaction}++;
    } else {
        $self->{dbh}->rollback;
        $self->_txn_end;
    }
}

sub txn_commit {
    my $self = shift;
    my $txns = $self->{active_transactions};
    return unless @$txns;

    if ( $self->{rollbacked_in_nested_transaction} ) {
        Carp::croak "tried to commit but already rollbacked in nested transaction.";
    }

    my $current = pop @$txns;
    if (@$txns == 0) {
        $self->{dbh}->commit;
        $self->_txn_end;
    }
}

sub _txn_end {
    @{$_[0]->{active_transactions}} = ();
    $_[0]->{rollbacked_in_nested_transaction} = 0;
}

sub active_transactions { $_[0]->{active_transactions} }

sub in_transaction {
    my $self = shift;
    my $txns = $self->{active_transactions};
    return @$txns ? $txns->[0] : ();
}

package DBIx::TransactionManager::ScopeGuard;
use Try::Tiny;

sub new {
    my($class, $obj, %args) = @_;

    my $caller = $args{caller} || [ caller(1) ];
    $obj->txn_begin( caller => $caller );
    bless [ 0, $obj, $caller, ], $class;
}

sub rollback {
    return if $_[0]->[0];
    $_[0]->[1]->txn_rollback;
    $_[0]->[0] = 1;
}

sub commit {
    return if $_[0]->[0];
    $_[0]->[1]->txn_commit;
    $_[0]->[0] = 1;
}

sub DESTROY {
    my($dismiss, $obj, $caller) = @{ $_[0] };
    return if $dismiss;

    warn( "Transaction was aborted without calling an explicit commit or rollback. (Guard created at $caller->[1] line $caller->[2])" );

    try {
        $obj->txn_rollback;
    } catch {
        die "Rollback failed: $_";
    };
}

1;
__END__

=head1 NAME

DBIx::TransactionManager - transaction handling for database.

=head1 SYNOPSIS

basic usage:

    use DBI;
    use DBIx::TransactionManager;
    my $dbh = DBI->connect('dbi:SQLite:');
    my $tm = DBIx::TransactionManager->new($dbh);
    
    $tm->txn_begin;
    
        $dbh->do("insert into foo (id, var) values (1,'baz')");
    
    $tm->txn_commit;
    
scope_gurad usage:

    use DBI;
    use DBIx::TransactionManager;
    my $dbh = DBI->connect('dbi:SQLite:');
    my $tm = DBIx::TransactionManager->new($dbh);
    
    my $txn = $tm->txn_scope;
    
        $dbh->do("insert into foo (id, var) values (1,'baz')");
    
    $txn->commit;

nested transaction usage:

    use DBI;
    use DBIx::TransactionManager;
    my $dbh = DBI->connect('dbi:SQLite:');
    my $tm = DBIx::TransactionManager->new($dbh);
    
    {
        my $txn = $tm->txn_scope;
        $dbh->do("insert into foo (id, var) values (1,'baz')");
        {
            my $txn2 = $tm->txn_scope;
            $dbh->do("insert into foo (id, var) values (2,'bab')");
            $txn2->commit;
        }
        {
            my $txn3 = $tm->txn_scope;
            $dbh->do("insert into foo (id, var) values (3,'bee')");
            $txn3->commit;
        }
        $txn->commit;
    }
    
=head1 DESCRIPTION

DBIx::TransactionManager is a simple transaction manager.
like  L<DBIx::Class::Storage::TxnScopeGuard>.

=head1 METHODS

=head2 my $tm = DBIx::TransactionManager->new($dbh)

get DBIx::TransactionManager's instance object.
$dbh parameter must be required.

=head2 my $txn = $tm->txn_scope(%args)

get DBIx::TransactionManager::ScopeGuard's instance object.
You may pass an optional argument to %args, to tell the scope guard
where the scope was generated, like so:

    sub mymethod {
        my $self = shift;
        my $txn = $tm->txn_scope( caller => [ caller() ] );
    }

    $self->mymethod();
    
This will allow the guard object to report the caller's location
from the perspective of C<mymethod()>, not where C<txn_scope()> was
called.

see L</DBIx::TransactionManager::ScopeGuard's METHODS>

=head2 $tm->txn_begin(%args)

Start the transaction.

C<txn_begin> may optionally take a 'caller' argument. This will allow you to
provide caller information which will be used in C<in_transaction>. For example
if you have a wrapper function that calls C<txn_begin>, you may want to 
let the user think that the caller was one stack above your wrapper.

    # use __my__ caller!
    $tm->txn_begin( caller => [ caller(0) ] ); 


=head2 $tm->txn_rollback

Rollback the transaction.

=head2 $tm->txn_commit

Commit the transaction.

=head2 $tm->in_transaction

Returns true if $txn is currently in a middle of a transaction. While normally
you only need to use this value as a boolean, it actually returns a hashref
consisting of 'caller' and 'pid' element. This will tell you exactly where
the currently valid transaction started.

=head1 DBIx::TransactionManager::ScopeGuard's METHODS

=head2 $txn->commit

Commit the transaction.

=head2 $txn->rollback

Rollback the transaction.

=head1 AUTHOR

Atsushi Kobayashi E<lt>nekokak _at_ gmail _dot_ comE<gt>

=head1 SEE ALSO

L<DBIx::Class::Storage::TxnScopeGuard>

L<DBIx::Skinny::Transaction>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
