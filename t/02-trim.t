#!perl
use v5.24;    # Postfix defef.
use strict;
use warnings;
use Test::More;

BEGIN {
    use_ok( 'App::Pod' ) || print "Bail out!\n";
}

diag( "Testing App::Pod $App::Pod::VERSION, Perl $], $^X" );

{
    no warnings qw( redefine once );
    *red                        = *App::Pod::_red;
    *yellow                     = *App::Pod::_yellow;
    *green                      = *App::Pod::_green;
    *Pod::Query::get_term_width = sub { 9 };
}

my $replacement = " ...";
my @cases       = (

# perl -Ilib -MApp::Pod -E 'say Pod::Query::get_term_width; App::Pod::_sayt( App::Pod::_red("123") . App::Pod::_yellow("456") . App::Pod::_green("789") )'

    # Less than term_width.
    {
        name            => "Less than term_width",
        input           => "12345678",
        expected_output => "12345678",
    },
    {
        name            => "Less than term_width (with color)",
        input           => red( "12345678" ),
        expected_output => red( "12345678" ),
    },
    {
        name            => "Less than term_width (with 3 colors)",
        input           => red( "123" ) . yellow( "456" ) . green( "78" ),
        expected_output => red( "123" ) . yellow( "456" ) . green( "78" ),
    },

    # Equal to term_width.
    {
        name            => "Equal to term_width",
        input           => "123456789",
        expected_output => "1234$replacement",
    },
    {
        name            => "Equal to term_width (with color)",
        input           => red( "123456789" ),
        expected_output => red( "1234$replacement" ),
    },
    {
        name            => "Equal to term_width (with 3 colors)",
        input           => red( "123" ) . yellow( "456" ) . green( "789" ),
        expected_output => red( "123" ) . yellow( "4$replacement" ),
    },

    # Greater than term_width.
    {
        name            => "Greater than term_width",
        input           => "1234567890",
        expected_output => "1234$replacement",
    },
    {
        name            => "Greater than term_width (with color)",
        input           => red( "1234567890" ),
        expected_output => red( "1234$replacement" ),
    },
    {
        name            => "Greater than term_width (with 3 colors)",
        input           => red( "123" ) . yellow( "456" ) . green( "7890" ),
        expected_output => red( "123" ) . yellow( "4$replacement" ),
    },
);

for my $case ( @cases ) {
    is(
        App::Pod::trim( $case->{input} ),
        $case->{expected_output},
        $case->{name},
    );
}

done_testing( 10 );

