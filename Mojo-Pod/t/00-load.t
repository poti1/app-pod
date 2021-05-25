#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Mojo::Pod' ) || print "Bail out!\n";
}

diag( "Testing Mojo::Pod $Mojo::Pod::VERSION, Perl $], $^X" );
