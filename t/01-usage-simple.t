#!perl
use v5.24;    # Postfix defef.
use strict;
use warnings;
use Test::More;
use Term::ANSIColor qw( colorstrip );

#TODO: Remove this debug code !!!
use feature qw(say);
use Mojo::Util qw(dumper);

BEGIN {
    use_ok( 'App::Pod' ) || print "Bail out!\n";
}

diag( "Testing App::Pod $App::Pod::VERSION, Perl $], $^X" );

{
    no warnings qw( redefine once );

    # Make sure this is already defined a a number.
    like( Pod::Query::get_term_width(),
        qr/^\d+$/, "get_term_width eturns a number" );

    *Pod::Query::get_term_width = sub { 56 };    # Match android.
}

my @cases = (
    {
        name            => "No Input - Help",
        input           => ["--help"],
        expected_output => [
            "",
            "Shows available class methods and documentation",
            "",
            "Syntax:",
            "  pod module_name [method_name]",
            "",
            "Options:",
            "  --help, -h            - Show this help section.",
            "  --tool_options, --to  - List tool options.",
            "  --class_options, --co - Class events and methods.",
            "  --query, -q           - Run a pod query.",
            "  --dump, --dd          - Dump extra info.",
            "  --doc, -d             - View class documentation.",
            "  --edit, -e            - Edit the source code.",
            "  --all, -a             - Show all class functions.",
            "  --flush_cache, -f     - Flush cache file(s).",
            "",
            "Examples:",
            "  # Methods",
            "  pod Mojo::UserAgent",
            "  pod Mojo::UserAgent -a",
            "",
            "  # Method",
            "  pod Mojo::UserAgent prepare",
            "",
            "  # Documentation",
            "  pod Mojo::UserAgent -d",
            "",
            "  # Edit",
            "  pod Mojo::UserAgent -e",
            "  pod Mojo::UserAgent prepare -e",
            "",
            "  # List all methods",
            "  pod Mojo::UserAgent --class_options",
            "",
            "  # List all Module::Build actions.",
            "  pod Module::Build --query head1=ACTIONS/item-text",
        ],
    },
    {
        name            => "tool_options",
        input           => ["--tool_options"],
        expected_output => [
            qw {
              --all
              --class_options
              --co
              --dd
              --doc
              --dump
              --edit
              --flush_cache
              --help
              --query
              --to
              --tool_options
              -a
              -d
              -e
              -f
              -h
              -q
            }
        ],
    },
    {
        name            => "class_options - No class",
        input           => ["--class_options"],
        expected_output => [ "", "Missing class name!", ],
    },
    {
        name            => "class_options - Mojo::UserAgent",
        input           => [ "Mojo::UserAgent", "--class_options" ],
        expected_output => [
            qw{
              BEGIN
              DEBUG
              DESTROY
              ISA
              __ANON__
              _cleanup
              _connect
              _connect_proxy
              _connection
              _dequeue
              _error
              _finish
              _process
              _read
              _redirect
              _remove
              _reuse
              _start
              _url
              _write
              build_tx
              build_websocket_tx
              ca
              cert
              connect_timeout
              cookie_jar
              delete
              delete_p
              get
              get_p
              has
              head
              head_p
              import
              inactivity_timeout
              insecure
              ioloop
              key
              max_connections
              max_redirects
              max_response_size
              monkey_patch
              options
              options_p
              patch
              patch_p
              post
              post_p
              prepare
              proxy
              put
              put_p
              request_timeout
              server
              socket_options
              start
              start
              start_p
              term_escape
              transactor
              weaken
              websocket
              websocket_p
            }
        ],
    },
    {
        name  => "query",
        input => [qw{ Module::Build --query head1=ACTIONS/item-text }],
        expected_output => [
            "build",           "clean",
            "code",            "config_data",
            "diff",            "dist",
            "distcheck",       "distclean",
            "distdir",         "distinstall",
            "distmeta",        "distsign",
            "disttest",        "docs",
            "fakeinstall",     "help",
            "html",            "install",
            "installdeps",     "manifest",
            "manifest_skip",   "manpages",
            "pardist",         "ppd",
            "ppmdist",         "prereq_data",
            "prereq_report",   "pure_install",
            "realclean",       "retest",
            "skipcheck",       "test",
            "testall",         "testcover",
            "testdb",          "testpod",
            "testpodcoverage", "versioninstall",
        ],
    },

    {
        name  => "query_dump",
        input =>
          [qw{ Module::Build --query head1=ACTIONS/item-text[0] --dump }],
        expected_output => [
            "self=bless( {",
            "  \"args\" => [],",
            "  \"class\" => \"Module::Build\",",
            "  \"method\" => undef,",
            "  \"non_main_options\" => [",
            "    {",
            "      \"description\" => \"Run a pod query.\",",
            "      \"handler\" => \"query_class\",",
            "      \"name\" => \"query\",",
            "      \"spec\" => \"query|q=s\"",
            "    }",
            "  ],",
            "  \"opts\" => {",
            "    \"dump\" => 1,",
            "    \"query\" => \"head1=ACTIONS/item-text[0]\"",
            "  }",
            "}, 'App::Pod' )",
            "",
            "Processing: query",
            "DEBUG_FIND_DUMP: [",
            "  {",
            "    \"keep\" => 1,",
            "    \"kids\" => [",
            "      {",
            "        \"tag\" => \"Para\",",
            "        \"text\" => \"[version 0.01]\"",
            "      },",
            "      {",
            "        \"tag\" => \"Para\",",
"        \"text\" => \"If you run the Build script without any arguments, it runs the build action, which in turn runs the code and docs actions.\"",
            "      },",
            "      {",
            "        \"tag\" => \"Para\",",
"        \"text\" => \"This is analogous to the MakeMaker make all target.\"",
            "      }",
            "    ],",
            "    \"prev\" => [],",
            "    \"tag\" => \"item-text\",",
            "    \"text\" => \"build\"",
            "  }",
            "]",
            "",
            "build",
        ],
    },
    {
        name            => "Module - ojo",
        input           => ["ojo"],
        expected_output => [
            "",
            "Package: ojo",
            "Path:    PATH",
            "",
            "ojo - Fun one-liners with Mojo",
            "",
            "Methods (16):",
            " a - Create a route with \"any\" in Mojolicious::Lite  ...",
            " b - Turn string into a Mojo::ByteStream object.",
            " c - Turn list into a Mojo::Collection object.",
            " d - Perform DELETE request with \"delete\" in Mojo::U ...",
            " f - Turn string into a Mojo::File object.",
            " g - Perform GET request with \"get\" in Mojo::UserAge ...",
            " h - Perform HEAD request with \"head\" in Mojo::UserA ...",
            " j - Encode Perl data structure or decode JSON with  ...",
            " l - Turn a string into a Mojo::URL object.",
            " n - Benchmark block and print the results to STDERR ...",
            " o - Perform OPTIONS request with \"options\" in Mojo: ...",
            " p - Perform POST request with \"post\" in Mojo::UserA ...",
            " r - Dump a Perl data structure with \"dumper\" in Moj ...",
            " t - Perform PATCH request with \"patch\" in Mojo::Use ...",
            " u - Perform PUT request with \"put\" in Mojo::UserAge ...",
            " x - Turn HTML/XML input into Mojo::DOM object.",
            "",
            "Use --all (or -a) to see all methods.",
        ],
    },
    {
        name            => "Module - Mojo::UserAgent",
        input           => ["Mojo::UserAgent"],
        expected_output => [
            "",
            "Package: Mojo::UserAgent",
            "Path:    PATH",
            "",
            "Mojo::UserAgent - Non-blocking I/O HTTP and WebSocke ...",
            "",
            "Inheritance (3):",
            " Mojo::UserAgent",
            " Mojo::EventEmitter",
            " Mojo::Base",
            "",
            "Events (2):",
            " prepare - Emitted whenever a new transaction is bei ...",
            " start   - Emitted whenever a new transaction is abo ...",
            "",
            "Methods (36):",
            " build_tx           - Generate Mojo::Transaction::HT ...",
            " build_websocket_tx - Generate Mojo::Transaction::HT ...",
            " ca                 - Path to TLS certificate author ...",
            " cert               - Path to TLS certificate file,  ...",
            " connect_timeout    - Maximum amount of time in seco ...",
            " cookie_jar         - Cookie jar to use for requests ...",
            " delete             - Perform blocking DELETE reques ...",
            " delete_p           - Same as \"delete\", but performs ...",
            " get                - Perform blocking GET request a ...",
            " get_p              - Same as \"get\", but performs al ...",
            " head               - Perform blocking HEAD request  ...",
            " head_p             - Same as \"head\", but performs a ...",
            " inactivity_timeout - Maximum amount of time in seco ...",
            " insecure           - Do not require a valid TLS cer ...",
            " ioloop             - Event loop object to use for b ...",
            " key                - Path to TLS key file, defaults ...",
            " max_connections    - Maximum number of keep-alive c ...",
            " max_redirects      - Maximum number of redirects th ...",
            " max_response_size  - Maximum response size in bytes ...",
            " options            - Perform blocking OPTIONS reque ...",
            " options_p          - Same as \"options\", but perform ...",
            " patch              - Perform blocking PATCH request ...",
            " patch_p            - Same as \"patch\", but performs  ...",
            " post               - Perform blocking POST request  ...",
            " post_p             - Same as \"post\", but performs a ...",
            " proxy              - Proxy manager, defaults to a M ...",
            " put                - Perform blocking PUT request a ...",
            " put_p              - Same as \"put\", but performs al ...",
            " request_timeout    - Maximum amount of time in seco ...",
            " server             - Application server relative UR ...",
            " socket_options     - Additional options for IO::Soc ...",
            " start              - Emitted whenever a new transac ...",
            " start_p            - Same as \"start\", but performs  ...",
            " transactor         - Transaction builder, defaults  ...",
            " websocket          - Open a non-blocking WebSocket  ...",
            " websocket_p        - Same as \"websocket\", but retur ...",
            "",
            "Use --all (or -a) to see all methods.",
        ],
    },
    {
        name            => "Module - Mojo::File",
        input           => ["Mojo::File"],
        expected_output => [
            "",
            "Package: Mojo::File",
            "Path:    PATH",
            "",
            "Mojo::File - File system paths",
            "",
            "Methods (32):",
            " basename    - Return the last level of the path wit ...",
            " child       - Return a new Mojo::File object relati ...",
            " chmod       - Change file permissions.",
            " copy_to     - Copy file with File::Copy and return  ...",
            " curfile     - Construct a new scalar-based Mojo::Fi ...",
            " dirname     - Return all but the last level of the  ...",
            " extname     - Return file extension of the path.",
            " is_abs      - Check if the path is absolute.",
            " list        - List all files in the directory and r ...",
            " list_tree   - List all files recursively in the dir ...",
            " lstat       - Return a File::stat object for the sy ...",
            " make_path   - Create the directories if they don't  ...",
            " move_to     - Move file with File::Copy and return  ...",
            " new         - Construct a new Mojo::File object, de ...",
            " open        - Open file with IO::File.",
            " path        - Construct a new scalar-based Mojo::Fi ...",
            " realpath    - Resolve the path with Cwd and return  ...",
            " remove      - Delete file.",
            " remove_tree - Delete this directory and any files a ...",
            " sibling     - Return a new Mojo::File object relati ...",
            " slurp       - Read all data at once from the file.",
            " spurt       - Write all data at once to the file.",
            " stat        - Return a File::stat object for the path.",
            " tap         - Alias for \"tap\" in Mojo::Base.",
            " tempdir     - Construct a new scalar-based Mojo::Fi ...",
            " tempfile    - Construct a new scalar-based Mojo::Fi ...",
            " to_abs      - Return absolute path as a Mojo::File  ...",
            " to_array    - Split the path on directory separators.",
            " to_rel      - Return a relative path from the origi ...",
            " to_string   - Stringify the path.",
            " touch       - Create file if it does not exist or c ...",
            " with_roles  - Alias for \"with_roles\" in Mojo::Base.",
            "",
            "Use --all (or -a) to see all methods.",
        ],
    },
    {
        name            => "Module - Mojo::File --all",
        input           => [qw(Mojo::File --all)],
        expected_output => [
            "",
            "Package: Mojo::File",
            "Path:    PATH",
            "",
            "Mojo::File - File system paths",
            "",
            "Methods (57):",
            " (\"\"                  ",
            " ((                   ",
            " ()                   ",
            " (\@{}                 ",
            " (bool                ",
            " AUTOLOAD             ",
            " BEGIN                ",
            " EXPORT               ",
            " EXPORT_OK            ",
            " ISA                  ",
            " VERSION              ",
            " __ANON__             ",
            " abs2rel              ",
            " basename              - Return the last level of th ...",
            " can                  ",
            " canonpath            ",
            " catfile              ",
            " child                 - Return a new Mojo::File obj ...",
            " chmod                 - Change file permissions.",
            " copy                 ",
            " copy_to               - Copy file with File::Copy a ...",
            " croak                ",
            " curfile               - Construct a new scalar-base ...",
            " dirname               - Return all but the last lev ...",
            " extname               - Return file extension of th ...",
            " file_name_is_absolute",
            " find                 ",
            " getcwd               ",
            " import               ",
            " is_abs                - Check if the path is absolute.",
            " list                  - List all files in the direc ...",
            " list_tree             - List all files recursively  ...",
            " lstat                 - Return a File::stat object  ...",
            " make_path             - Create the directories if t ...",
            " move                 ",
            " move_to               - Move file with File::Copy a ...",
            " new                   - Construct a new Mojo::File  ...",
            " open                  - Open file with IO::File.",
            " path                  - Construct a new scalar-base ...",
            " realpath              - Resolve the path with Cwd a ...",
            " rel2abs              ",
            " remove                - Delete file.",
            " remove_tree           - Delete this directory and a ...",
            " sibling               - Return a new Mojo::File obj ...",
            " slurp                 - Read all data at once from  ...",
            " splitdir             ",
            " spurt                 - Write all data at once to t ...",
            " stat                  - Return a File::stat object  ...",
            " tap                   - Alias for \"tap\" in Mojo::Base.",
            " tempdir               - Construct a new scalar-base ...",
            " tempfile              - Construct a new scalar-base ...",
            " to_abs                - Return absolute path as a M ...",
            " to_array              - Split the path on directory ...",
            " to_rel                - Return a relative path from ...",
            " to_string             - Stringify the path.",
            " touch                 - Create file if it does not  ...",
            " with_roles            - Alias for \"with_roles\" in M ...",
        ],
    },
);

my $is_path = qr/ ^ Path: \s* \K (.*) $ /x;

for my $case ( @cases ) {
    local @ARGV = ( $case->{input}->@* );
    my $output;

    # Capture STDOUT.
    {
        local *STDOUT;
        open STDOUT, ">", \$output or die $!;
        App::Pod->run;
    }

    my @lines = split /\n/, colorstrip( $output );

    # Normalize Path.
    for ( @lines ) {
        last if s/$is_path/PATH/;
    }

    say dumper \@lines and last
      unless is_deeply( \@lines, $case->{expected_output}, $case->{name} );
}

done_testing( 12 );

