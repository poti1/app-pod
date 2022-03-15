#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
   use_ok( 'Pod::LOL' ) || print "Bail out!\n";
}

diag( "Testing Pod::LOL $Pod::LOL::VERSION, Perl $], $^X" );
