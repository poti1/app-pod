@REM='
@echo off
perl -x -S -l %0 %*
exit /b
';





#!perl

use v5.30;
use strict;
use warnings;
use File::Basename   qw/ basename        /;
use List::Util       qw/ max             /;
use Getopt::Long;
use Mojo::Base       qw/ -strict -signatures /;
use Mojo::ByteStream qw/ b /;
use Mojo::Util       qw/ dumper /;
use subs             qw/ r sayt /;

our $VERSION = "1.0.0";
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
   my $self = basename($0);
   $self =~ s/ \.\w+ $ //x;

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

   Shows valid class methods and documentation

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
   eval "package $class; use $class";

   my $import_ok = do{
      if($@){ warn $@; 0 }
      else  {          1 }
   };

   $import_ok;
}

sub debug_pod($class) {
   my $pod = My::Pod->new($class);
   my $doc = $pod->find_method_summary($class);
   say dumper $pod;
   say $doc;

   exit;
}

sub edit_file($class,$method) {
   my $path = My::Pod->new($class, "path")->path;
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
   my $pod     = My::Pod->new($class);
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
   say scalar My::Pod->new($class)
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
   my %events = My::Pod->new($class)->find_events;
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
   my @dirs = $class->dir;
   my $pod  = My::Pod->new($class);
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
   my $term_width  = My::Pod::get_term_width();
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



#--------------------------------------------
#               My::Pod
#--------------------------------------------

package My::Pod;
use Mojo::Base       qw/ -base -signatures /;
use Mojo::Util       qw/ dumper class_to_path /;
use Mojo::ByteStream qw/ b/;
use Term::ReadKey    qw/ GetTerminalSize /;
use Pod::Text();
use Carp             qw/ croak /;
use subs             qw/ r /;

use constant {
   DEBUG_TREE    => 0,
   DEBUG_FIND    => 0,
   DEBUG_INVERT  => 0,
   DEBUG_RENDER  => 0,
   MOCK_ROOT     => 0,
   MOCK_SECTIONS => 0,
};

BEGIN {

  has [ qw/
     pod_class
     path
     root
     tree
     title
     events
   / ];
}

sub new($class,$pod_class,$path_only=0) {
   state %CACHE;

   my $cached;
   return $cached if $cached = $CACHE{$pod_class};

   my $s = bless {
      pod_class => $pod_class,
      path      => _class_to_path($pod_class),
   }, $class;

   return $s if $path_only;

   my $root = MOCK_ROOT ? _mock_root() :
      My::Pod::Simple::SimpleTree->new->parse_file($s->path)->root;

   $s->root($root);
   $s->tree( _root_to_tree($root) );

   # say dumper $s;
   # exit;

   $CACHE{$pod_class} = $s;

   $s;
}
sub _class_to_path($pod_class) {
   state %CACHE;
   my $p;

   return $p if $p = $CACHE{$pod_class};

   $p = $INC{class_to_path($pod_class)};
   return $CACHE{$pod_class} = $p if $p;

   $p = qx(perldoc -l $pod_class);
   chomp $p;
   return $CACHE{$pod_class} = $p if $p;

   croak "Missing: pod_class=$pod_class";
}
sub _mock_root {
   [

      [
         "head1",
         "HEAD1",
      ],
      [
         "head2",
         "HEAD2_1",
      ],
      [
         "Verbatim",
         "HEAD2_1-VERBATIM_1",
      ],
      [
         "Para",
         "HEAD2_1-PARA_1" . ("long" x 20),
      ],
      [
         "Verbatim",
         "HEAD2_1-VERBATIM_2",
      ],
      [
         "Para",
         "HEAD2_1-PARA_2",
      ],
      [
         "head2",
         "HEAD2_2",
      ],
      [
         "Verbatim",
         "HEAD2_2-VERBATIM_1",
      ],
      [
         "Para",
         "HEAD2_2-PARA_1",
      ],
      [
         "Para",
         "OPTS:",
      ],
      [
         "over-text",
         [
            "item-text",
            "OPT-A",
         ],
         [
            "Verbatim",
            "OPT-A => 1",
         ],
         [
            "Para",
            "OPT-A DESC",
         ],
         [
            "item-text",
            "OPT-B",
         ],
         [
            "Verbatim",
            "OPT-B => 1",
         ],
         [
            "Para",
            "OPT-B DESC",
         ],
      ],
      [
         "Verbatim",
         "HEAD2_2-VERBATIM_2",
      ],
      [
         "Para",
         "HEAD2_2-PARA_2",
      ],

   ]
}
sub _root_to_tree($root) {
   my ($is_in, $is_out);
   my $is_head = qr/ ^ head (\d) $ /x;
   my @main;
   my $q = {};

   my $push = sub {        # push to main list
      return unless %$q;   # only if queue
      my $sub = $q->{sub}; # sub tags
      my $has = _has_head($sub);
      $q->{sub} = _root_to_tree($sub) if $has;
      push @main, $q;
      $q = {};
   };

   DEBUG_TREE and
      say "\n_ROOT_TO_TREE()";

   for($root->@*){
      DEBUG_TREE and
         say "\n_=", dumper $_;

      my $leaf = _make_leaf($_);
      my $tag  = $leaf->{tag};

      DEBUG_TREE and
         say "\nleaf=", dumper $leaf;

      if(not $is_in or $tag =~ /$is_out/){
         $push->();
         $q = $leaf;
         next unless $tag =~ /$is_head/;
         ($is_in,$is_out) = _get_heads_regex($1);
      }
      else {
         $q->{sub} //= [];
         push $q->{sub}->@*, $leaf;
         DEBUG_TREE and
            say "q: ", dumper $q;
      }
   }

   $push->();

   \@main;
}
sub _has_head($list) {
   return unless ref $list;

   DEBUG_TREE and
      say "\nlist=", dumper $list;

   my $is_head = qr/ ^ head (\d) $ /x;

   my $any_head = grep {
      $_->{tag} =~ /$is_head/;
   } @$list;

   $any_head;
}
sub _make_leaf($node) {
   return $node if ref $node eq ref {};

   my ($tag,@text) = @$node;
   my $leaf        = {
      tag  => $tag,
      text => \@text,
   };

   if($tag eq "over-text"){
      $leaf->{is_over} = 1,
      $leaf->{text}    = _structure_over(\@text),
   }

   $leaf;
}
sub _structure_over($text_list) {
   my @struct;
   my @q;

   for(@$text_list){
      my ($tag,$text) = @$_;
      if($tag eq "item-text"){
         push @struct, [splice @q] if @q;
      }

      push @q, $_;
   }

   push @struct, [splice @q] if @q;

   \@struct;
}

=pod
   $pod->find(@sections)

   Where each section can contain:
   {
      tag      => "TAG_NAME",     # Find all matching tags.
      text     => "TEXT_NAME",    # Find all matching texts.
      keep     => 1,              # Capture the text.
      keep_all => 1,              # Capture entire section.
      nth      => 0,              # Use only the nth match.
   }

   # Return contents of entire head section:
   find (
      {tag => "head", text => "a", keep_all => 1},
   )

   # Results:
   # [
   #    "  my \$app = a('/hel...",
   #    {text => "Create a route with ...", wrap => 1},
   #    "  \$ perl -Mojo -E ...",
   # ]
=cut

sub find_title($s) {
   $s->find(
      {
         tag       => "head1",
         text      => "NAME",
         nth       => 0,
      },
      {
         tag       => "Para",
         nth       => 0,
      },
   );
}
sub find_method($s,$method) {
   $s->find(
      {
         tag       => qr/ ^ head \d $ /x,
         text      => quotemeta($method),
         nth_group => 0,
         keep_all  => 1,
      },
   );
}
sub find_method_summary($s,$method) {
   $s->find(
      {
         tag       => qr/ ^ head \d $ /x,
         text      => quotemeta($method),
         nth       => 0,
      },
      {
         tag       => "Para",
         nth       => 0,
      },
   );
}
sub find_events($s) {
   $s->find(
      {
         tag       => qr/ ^ head \d $ /x,
         text      => "EVENTS",
         nth       => 0,
      },
      {
         tag       => qr/ ^ head \d $ /x,
         keep      => 1,
      },
      {
         tag       => "Para",
         nth_group => 0,
      },
   );
}
sub find($s,@find_sections) {
   @find_sections = (
      {
         tag      => "head1",
   #     text     => "MAIN",
   #     keep     => 1,
   #     keep_all => 1,
      },
      {
         tag      => "head2",
     #   text     => "SUB1",
     #   keep     => 1,
     #   keep_all => 1,
         nth      => 1,
      },
      {
         tag      => "over-text",
     #   text     => "SUB1",
     #   keep     => 1,
         keep_all => 1,
     #   nth      => 1,
      },
    # {
    #    tag      => "Para",
    # #  text     => "SKIP1",
    #    keep     => 1,
    # #  keep_all => 1,
    #    nth      => 1,
    # },
   ) if MOCK_SECTIONS;

   _check_sections(\@find_sections);
   _set_section_defaults(\@find_sections);

   my @tree = $s->tree->@*;
   my $kept_all;

   for my $find (@find_sections) {
      @tree = _find($find,@tree);
      if($find->{keep_all}){
         $kept_all++;
         last;
      }
   }

   if(not $kept_all){
      @tree = _invert(@tree);
   }

   # say "tree= ", dumper \@tree;
   # exit;

   _render($kept_all,@tree);
}
sub _check_sections($sections) {

   my $error_message = <<~'ERROR';

      Invalid input: expecting a hash reference!

      Syntax:

         $pod->find(
            # section1
            {
               tag       => "TAG",
               text      => "TEXT",
               keep      => 1,      # Must only be in last section.
               keep_all  => 1,
               nth       => 0,      # These options ...
               nth_group => 0,      #   are exclusive.
            },
            # ...
            # sectionN
         );
   ERROR

   die "$error_message" if grep { ref() ne ref {} } @$sections;

   # keep_all should only be in the last section
   my $last = $#$sections;
   while(my($n,$section) = each @$sections) {
      die "Error: keep_all is not in last query!\n"
         if $section->{keep_all} and $n < $last;
   }

   # Cannot use both nth and nth_group (makes no sense, plus may cause errors)
   while(my($n,$section) = each @$sections) {
      die "Error: nth and nth_group are exclusive!\n"
         if defined $section->{nth} and 
            defined $section->{nth_group};
   }

}
sub _set_section_defaults($sections) {
   for my $section (@$sections){

      # Text Options
      for(qw/ tag text /){
         if(defined $section->{$_}) {
            if(ref $section->{$_} ne ref qr//){
               $section->{$_} = qr/ ^ $section->{$_} $ /x;
            }
         }
         else {
            $section->{$_} = qr/./;
         }
      }

      # Bit Options
      for(qw/ keep keep_all /){
         if(defined $section->{$_}) {
            $section->{$_} = !!$section->{$_};
         }
         else {
            $section->{$_} = 0;
         }
      }

      # Range Options
      my $zero     = "0 but true";
      my $is_digit = qr/ ^ -?\d+ $ /x;
      for(qw/ nth nth_group /){
         my $v = $section->{$_};
         if(defined $v and $v =~ /$is_digit/){
            $v ||= $zero;
            my $end  = ($v >= 0) ? "pos" : "neg";
            my $name = "_${_}_$end";
            $section->{$name} = $v;
         }
      }

   }
}
sub _get_heads_regex($num) {
   # Make regex for inner and outer =head tags
   my $inner  = join "", grep {$_ >  $num} 1..4;
   my $outer  = join "", grep {$_ <= $num} 1..4;
   my $is_in  = qr/ ^ head ([$inner]) $ /x;
   my $is_out = qr/ ^ head ([$outer]) $ /x;

   ($is_in,$is_out);
}
sub _find($need,@groups) {
   if(DEBUG_FIND){
      say "\n_FIND()";
      say "need:   ", dumper $need;
      say "groups: ", dumper \@groups;
   }

   my $tag         = $need->{tag};
   my $text        = $need->{text};
   my $keep        = $need->{keep};
   my $nth         = $need->{nth};
   my $nth_p       = $need->{_nth_pos};
   my $nth_n       = $need->{_nth_neg};   
   my $nth_group   = $need->{nth_group};
   my $nth_group_p = $need->{_nth_grou_pos};
   my $nth_group_n = $need->{_nth_grou_neg};
   my @found;

   GROUP: for my $group (@groups) {
      my @tries = ($group);
      my $prev  = $group->{prev} // [];
      $prev = [@$prev]; # shallow copy
      my $locked_prev = 0;
      my @q;
      if(DEBUG_FIND){
         say "\nprev: ", dumper $prev;
         say "group:  ", dumper $group;
      }

      while (my $try = shift @tries) {
         DEBUG_FIND and
            say "\nTrying: try=", dumper $try;

         my $_tag    = $try->{tag};
         my ($_text) = $try->{text}->@*;
         my $_sub    = $try->{sub};
         my $_keep   = $try->{keep};

         if (defined $_keep){
            DEBUG_FIND and
               say "ENFORCING: keep";
         }
         elsif($_tag =~ /$tag/ and
              $_text =~ /$text/){
            DEBUG_FIND and
               say "Found:  tag=$_tag, text=$_text";
            push @q, {
               %$try,
               prev => $prev,
               keep => $keep,
            };

            # Specific match (positive)
            if($nth_p and @q > $nth_p){
               DEBUG_FIND and
                  say "ENFORCING: nth=$nth";
               @found = $q[$nth_p];
               last GROUP;
            }

            # Specific group match (positive)
            elsif($nth_group_p and @q > $nth_group_p){
               DEBUG_FIND and
                  say "ENFORCING: nth_group=$nth_group";
               @q = $q[$nth_group_p];
               last;
            }            
         }

         if($_sub and not @q){
            DEBUG_FIND and
               say "Got sub and nothing yet in queue";
            unshift @tries, @$_sub;
            if($_keep and not $locked_prev++){
               unshift @$prev, {
                  tag  => $_tag,
                  text => [$_text],
               };
               DEBUG_FIND and
                  say "prev changed: ", dumper $prev;
            }
            DEBUG_FIND and
               say "locked_prev: $locked_prev";
         }
      }

      # Specific group match (negative)
      if($nth_group_n and @q >= abs $nth_group_n){
         DEBUG_FIND and
            say "ENFORCING: nth_group_n=$nth_group_n";
         @q = $q[$nth_group_n];
      }

      push @found, splice @q if @q;
   }

   # Specific match (negative)
   if($nth_n and @found >= abs $nth_n){
      DEBUG_FIND and
         say "ENFORCING: nth=$nth";
      @found = $found[$nth_n];
   }

   DEBUG_FIND and
      say "found: ", dumper \@found;
   @found;
}
sub _to_list($groups,$recursive=0) {
   my @groups = @$groups;
   my @list;

   say "\n_TO_LIST()";
   say "groups: ", dumper \@groups;

   while (my $group = shift @groups) {
      my ($tag,$text,$sub,$opts) = @$group;
      push @list, {
         tag  => $tag,
         text => $text,
      };

      if($sub and $recursive){
         unshift @groups, @$sub;
      }
   }

   @list;
}
sub _invert(@groups) {
   if(DEBUG_INVERT){
      say "\n_INVERT()";
      say "groups: ", dumper \@groups;
   }

   my @tree;
   my %navi;

   for my $group (@groups) {
      push @tree, {
         %$group{qw/tag text sub is_over/}
      };
      if(DEBUG_INVERT){
         say "\nInverting: group=" , dumper $group;
         say "tree: ", dumper \@tree;
      }

      my $prevs = $group->{prev} // [];
      for my $prev (@$prevs){
         my $prev_node = $navi{$prev};
         if(DEBUG_INVERT){
            say "prev: ",      dumper $prev;
            say "prev_node: ", dumper $prev_node;
         }
         if($prev_node){
            push @$prev_node, pop @tree;
            if(DEBUG_INVERT){
               say "FOUND: prev_node=",
                  dumper $prev_node;
            }
            last;
         }
         else{
            $prev_node = $navi{$prev} = [$tree[-1]];
            $tree[-1] = {%$prev, sub => $prev_node};
            if(DEBUG_INVERT){
               say "NEW: prev_node=",
                  dumper $prev_node;
            }
         }
      }

      DEBUG_INVERT and
         say "tree end: ", dumper \@tree;
   }

   @tree;
}
sub _render($kept_all,@tree) {
   if(DEBUG_RENDER){
      say "\n_RENDER()";
      say "tree: ", dumper \@tree;
      say "kept_all: ", dumper $kept_all;
   }

   my $formatter = Pod::Text->new(
      width => get_term_width(),
   );
   $formatter->{MARGIN} = 2;

   my @lines;
   my $n;

   for my $group (@tree) {
      my @tries = ($group);
      DEBUG_RENDER and
         say "\ngroup:  ", dumper $group;

      while (my $try = shift @tries) {
         DEBUG_RENDER and
            say "\nTrying: try=", dumper $try;

         my $_tag  = $try->{tag};
         my $_text = $try->{text}[0];
         my $_sub  = $try->{sub};

         if($try->{is_over}){
            $_text = _render_over(
               $try->{text},
               $kept_all,
            );
         }
         elsif($kept_all){
            $_text .= ":" if ++$n == 1;
            if($_tag eq "Para"){
               DEBUG_RENDER and
                  say "USING FORMATTER";
               $_text = $formatter->reformat($_text);
            }
         }

         push @lines, $_text;
         push @lines, "" if $kept_all;

         if($_sub){
            unshift @tries, @$_sub;
            if(DEBUG_RENDER){
               say "Got subs";
               say "tries:  ", dumper \@tries;
            }
         }

      }

   }

   DEBUG_RENDER and
      say "lines: ", dumper \@lines;

   return @lines if wantarray;
   join "\n", @lines;
}
sub _render_over($list,$kept_all) {
   if(DEBUG_RENDER){
      say "\n_RENDER_OVER()";
      say "list=", dumper $list;
   }

   my @txt;

   # Formatters
   state $f_norm;
   state $f_sub;
   if(not $f_norm){
      $f_norm = Pod::Text->new(
         width => get_term_width(),
      );
      $f_norm->{MARGIN} = 2;
      $f_sub = Pod::Text->new(
         width => get_term_width(),
      );
      $f_sub->{MARGIN} = 4;
   }

   for my $items (@$list){
      my $n;
      for(@$items){
         DEBUG_RENDER and
            say "over-item=", dumper $_;

         my($tag,$text) = @$_;

         if($kept_all){
            DEBUG_RENDER and
               say "USING FORMATTER";
            $text .= ":" if ++$n == 1;
            if($tag eq "item-text"){
               $text = $f_norm->reformat($text);
            }
            else{
               $text = b($text)->trim;
               $text = $f_sub->reformat($text);
            }
         }

         push @txt, $text;
         push @txt, "" if $kept_all;
      }
   }

   my $new_text = join "\n", @txt;

   DEBUG_RENDER and
      say "Changed over-text to: $new_text";

   $new_text;
}

sub get_term_width {
   state $term_width;

   if(not $term_width){
      ($term_width) = GetTerminalSize();
      $term_width--;
   }

   $term_width;
}

sub r($what,$depth=undef) {
   require Data::Dumper;
   my $d = Data::Dumper->new($what)
      ->Sortkeys(1)
      ->Indent(1)
      ->Terse(1)
      ->Maxdepth($depth)
      ;
   say $d->Dump;
}



#--------------------------------------------
#        My::Pod::Simple::SimpleTree
# Overwrites 3 important subs for having a
# simple pod parsing solution.
#--------------------------------------------

package My::Pod::Simple::SimpleTree;

use Mojo::Base qw/ -base Pod::Simple -signatures /;
use Mojo::Util qw/ dumper /;

use constant MY_DEBUG => 0;

BEGIN {

  has [ qw/ _pos root / ];
}

sub _handle_element_start($s,$tag,$attr) {
   MY_DEBUG and say "TAG_START: $tag";

   if($s->_pos) {
      my $x = (length($tag)==1) ? [] : [$tag];  # Ignore single character tags
      push $s->_pos->[0]->@*, $x;               # Append to root
      unshift $s->_pos->@*, $x;                 # Set as current position
   }
   else {
      my $x = [];
      $s->root($x);                             # Set root
      $s->_pos([$x]);                           # Set current position
   }

   MY_DEBUG and say "_pos: ", dumper $s->_pos;
}
sub _handle_text($s,$text) {
   MY_DEBUG and say "TEXT: $text";

   push $s->_pos->[0]->@*, $text;            # Add text

   MY_DEBUG and say "_pos: ", dumper $s->_pos;
}
sub _handle_element_end {
   my ($s,$tag) = @_;
   MY_DEBUG and say "TAG_END: $tag";
   shift $s->_pos->@*;

   if( length $tag == 1 ){
      # Single character tags (like L<>) should be on the same level as text.
      $s->_pos->[0][-1] = join "", $s->_pos->[0][-1]->@*;
      MY_DEBUG and say "TAG_END_TEXT: @{[ $s->_pos->[0][-1] ]}";
   }
   elsif($tag eq "Para"){
      # Should only have 2 elements: tag, entire text
      my ($_tag, @text) = $s->_pos->[0][-1]->@*;
      my $text = join "", @text;
      $s->_pos->[0][-1]->@* = ($_tag, $text);
   }

   MY_DEBUG and say "_pos: ", dumper $s->_pos;
}
