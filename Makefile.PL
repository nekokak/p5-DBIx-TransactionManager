use inc::Module::Install;
name 'DBIx-TransactionManager';
all_from 'lib/DBIx/TransactionManager.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
