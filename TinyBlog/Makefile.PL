use inc::Module::Install;
name 'TinyBlog';
all_from 'lib/TinyBlog.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
