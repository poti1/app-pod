#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
   use_ok( 'App::pod' ) || print "Bail out!\n";
}

diag( "Testing App::pod $App::pod::VERSION, Perl $], $^X" );
