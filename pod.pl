@REM='
@echo off
perl -x -S -l %0 %*
exit /b
';





#!perl

use v5.30;
use strict;
use warnings;
use FindBin           qw/ $RealBin /;  
use lib               ".", "$RealBin/Pod-Query/lib";
use Module::Functions qw/ get_public_functions /;
use Pod::Query;
use File::Basename    qw/ basename        /;
use List::Util        qw/ max             /;
use Getopt::Long;
use Mojo::Base        qw/ -strict -signatures /;
use Mojo::ByteStream  qw/ b /;
use Mojo::Util        qw/ dumper /;
use subs              qw/ r sayt /;

use constant DEBUG_POD => 0;


#--------------------------------------------
#                    MAIN
#--------------------------------------------

my $opts = get_opts();

show_help() if not @ARGV or $opts->{help};

my ($class,@args) = @ARGV;
my ($method)      = @args;

import_class($class) or exit;

debug_pod($class) if DEBUG_POD;

if($opts->{edit}){
   edit_file($class,$method);
}
elsif($opts->{doc}){
   doc_class($class,@args);
}

print_header($class);
if($method){
   show_method_doc($class,$method);
}
else{
   show_inheritance($class);
   show_events($class);
   show_methods($class,$opts);
}


#--------------------------------------------
#                    SUBS
#--------------------------------------------

sub define_spec {
   <<~SPEC;

      all|a  - Show all available class functions.
      doc|d  - View the class documentation.
      edit|e - Edit the source code.
      help|h - Show this help section.

   SPEC
}
sub _build_spec_list {
   map  { [split / \s+ - \s+ /x, $_, 2] }       # Split into: opts - description
   map  { b($_)->trim }                         # Trim leading/trailing spaces
   grep { not /^ \s* $/x }                      # Blank lines
   split "\n",
   define_spec();
}
sub get_spec_list {
   map { $_->[0] }
   _build_spec_list();
}
sub get_opts {
   my $opts = {};

   GetOptions($opts, get_spec_list) or die $!;

   $opts;
}
sub show_help {
   my $YELLOW  = "\e[33m";
   my $RESTORE = "\e[0m";
   my $self = basename($0);
   $self =~ s/ \.\w+ $ //x;
   $self = "$YELLOW$self$RESTORE";

   my @all = map {
         my ($opt,$desc) = @$_;
         $opt =~ s/\|/, /g;
         $opt =~ s/ (?=\b\w{2}) /--/gx; # Long opts
         $opt =~ s/ (?=\b\w\b)  /-/gx;  # Short opts
         [$opt,$desc,length $opt];
      }
      _build_spec_list();

   my $max = max map { $_->[2] } @all;

   my $options =
      join "\n   ",
      map { sprintf "%-${max}s - %s", @$_[0,1] }
      @all;

   say <<~HELP;

   Shows available class methods and documentation

   Syntax:
      $self module_name [method_name]

   Options:
      $options

   Examples:
      # Methods
      $self Mojo::UserAgent
      $self Mojo::UserAgent -a

      # Method
      $self Mojo::UserAgent prepare

      # Documentation
      $self Mojo::UserAgent -d

      # Edit
      $self Mojo::UserAgent -e
      $self Mojo::UserAgent prepare -e
   HELP

   exit;
}

sub import_class($class) {
   # Since ojo imports its DSL into the current package
   eval {
      eval "package $class; use $class";
   };

   my $import_ok = do{
      if($@){ warn $@; 0 }
      else  {          1 }
   };

   $import_ok;
}

sub debug_pod($class) {
   my $pod = Pod::Query->new($class);
   my $doc = $pod->find_method_summary($class);
   say dumper $pod;
   say $doc;

   say Pod::Query->new("ojo")->find_title;

   exit;
}

sub edit_file($class,$method) {
   my $path = Pod::Query->new($class, "path")->path;
   my $cmd  = "vim $path";

   if($method){
      my $m      = "<\\zs$method\\ze>";
      my $sub    = "<sub $m";
      my $monkey = "<monkey_patch>.+$m";
      my $list   = "^ +$m +\\=\\>";
      my $qw     = "<qw>.+$m";
      my $emit   = "<(emit|on)\\($m";
      $cmd .= " '+/\\v$sub|$monkey|$list|$qw|$emit'";
   }

   # say $cmd;
   # exit;
   exec $cmd;
}
sub doc_class($class,@args) {
   my $cmd  = "perldoc @args $class";

   # say $cmd;
   exec $cmd;
}

sub print_header($class) {
   my $pod     = Pod::Query->new($class);
   my $version = $class->VERSION;

   say "";
   sayt "# package: " . $class;
   sayt "# path:    " . $pod->path;
   sayt "# version: " . $version if $version;
   say "";
   sayt $pod->find_title;
   say "";
}

sub show_method_doc($class,$method) {
   say scalar Pod::Query->new($class)
      ->find_method($method);
}

sub show_inheritance(@classes) {
   my @tree;
   my %seen;
   no strict 'refs';

   while(my $class = shift @classes){
      next if $seen{class};   # Already saw it
      $seen{$class}++;        # Otherwise, now we did
      push @tree, $class;     # Add to tree

      eval "require $class";
      my @isa = @{"${class}::ISA"};
      push @classes, @isa;
   }

   my $size = @tree;
   say "Inheritance ($size):";
   say " $_" for @tree;
   say "";
}

sub show_events($class) {
   my %events = Pod::Query->new($class)->find_events;
   my @names  = sort keys %events;
   my $size   = @names;
   return unless $size;

   my $len    = max map { length } @names;
   my $format = " %-${len}s - %s";

   say "Events ($size):";
   for(@names){
      sayt sprintf $format, $_, $events{$_};
   }

   say "";
}

sub show_methods($class,$opts) {
  #my @dirs = $class->dir;
   my @dirs = sort {$a cmp $b} get_public_functions($class);
   my $pod  = Pod::Query->new($class);
   my $doc  = "";

   my @meths_all = map {
      my $doc = $pod->find_method_summary($_);
      [$_,$doc];
   } @dirs;

   # Documented methods
   my @meths_doc = grep { $_->[1] } @meths_all;

   # If we have methods, but none are documented
   if(@meths_all and not @meths_doc){
      say "Warning: All methods are undocumented! (reverting to --all)\n";
      $opts->{all} = 1;
   }

   my @meths = $opts->{all} ? @meths_all : @meths_doc;
   my $size  = @meths;
   my $max   = max map { length $_->[0] } @meths;
   $max //= 0;

   my $format = " %-${max}s%s";
   say "Methods ($size):";

   for my $list (@meths){
      my ($method,$doc_raw) = @$list;
      my $doc = $doc_raw ? " - $doc_raw" : "";
      sayt sprintf $format, $method, $doc;
   }

   say "\nUse --all (or -a) to see all methods."
      unless $opts->{all};
   say "";
}

sub _trim($line) {
   my $term_width  = Pod::Query::get_term_width();
   my $replacement = " ...";
   my $width       = $term_width - length($replacement) - 1;   # "-1" for newline

   # Trim to terminal width
   if(length($line) >= $term_width){                           # "=" also for newline
      $line = substr($line, 0, $width) . $replacement;
   }

   $line;
}
sub r {

   say dumper \@_;
}
sub sayt {

   say _trim(@_);
}



=for REMOVE

#--------------------------------------------
#               UNIVERSAL
#--------------------------------------------

package UNIVERSAL;

sub dir{
   my ($s)   = @_;               # class or object
   my $ref   = ref $s;
   my $class = $ref ? $ref : $s; # myClass
   my $pkg   = $class . "::";    # MyClass::
   my @keys_raw;
   my $is_special_block = qr/^ (?:BEGIN|UNITCHECK|INIT|CHECK|END|import|DESTROY) $/x;

   no strict 'refs';

   while( my($key,$stash) = each %$pkg){
#     next if $key =~ /$is_special_block/;   # Not a special block
#     next if $key =~ /^ _ /x;               # Not private method
      next if ref $stash;                    # Stash name should not be a reference
      next if not defined *$stash{CODE};     # Stash function should be defined
      push @keys_raw, $key;
   }

   my @keys = sort @keys_raw;

   return @keys if defined wantarray;

   say join "\n  ", "\n$class", @keys;
}

=cut
