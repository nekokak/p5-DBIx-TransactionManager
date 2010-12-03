use inc::Module::Install;
name 'DBIx-TransactionManager';
all_from 'lib/DBIx/TransactionManager.pm';

requires 'Try::Tiny';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More' => '0.94';

auto_set_repository;
WriteAll;
