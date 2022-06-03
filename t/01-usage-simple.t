#!perl
use v5.24;    # Postfix defef :)
use strict;
use warnings;
use Test::More;

#TODO: Remove this debug code !!!
use feature qw(say);
use Mojo::Util qw(dumper);

BEGIN {
   use_ok( 'App::Pod' ) || print "Bail out!\n";
}

diag( "Testing App::Pod $App::Pod::VERSION, Perl $], $^X" );

my @cases = (
   {
      name            => "No Input - Help",
      Input           => [],
      expected_output => "",
   },
 # {
 #    name            => "Module - ojo",
 #    Input           => [],
 #    expected_output => "",
 # },
 # {
 #    name            => "Module - Mojo::UserAgent",
 #    Input           => [],
 #    expected_output => "",
 # },
);

local *STDOUT;
my $output;
open STDOUT, ">", \$output or die $!;

for my $case ( @cases ) {
   local @ARGV = ( $case->{input}->@* );
   $output = "";

   App::Pod->run;

   my $success = is( $output, $case->{expected_output}, $case->{name} );

 # if ( not $success) {
      say $output;
 # }
}

done_testing( );  # TODO: add the total

