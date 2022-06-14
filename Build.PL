use 5.006;
use strict;
use warnings;
use Module::Build;
Module::Build->VERSION('0.4004');

my $class = Module::Build->subclass(
    code => q{
        sub _clear_cache {
            for ( glob "$ENV{HOME}/.cache/my_pod*.cache" ) {
                print "Removing: $_\n";
                unlink or warn $!;
            }
        }
        sub ACTION_install {
            my ($s) = @_;
            $s->_clear_cache;
            $s->SUPER::ACTION_install;
        }
        sub ACTION_clean {
            my ($s) = @_;
            $s->_clear_cache;
            $s->SUPER::ACTION_clean;
        }
    },
);

my $builder = $class->new(
    module_name         => 'App::Pod',
    license             => 'artistic_2',
    dist_author         => q{Tim Potapov <tim.potapov[AT]gmail.com>},
    dist_version_from   => 'lib/App/Pod.pm',
    release_status      => 'stable',
    configure_requires => {
        'Module::Build' => '0.4004',
    },
    test_requires => {
        'Test::More' => '0',
    },
    requires => {
        'Module::Functions' => '2.1.3',
        'Pod::Query' => '0.14',
        'Mojolicious' => '9.19',
    },
    add_to_cleanup     => [
        'App-Pod-*',
        "$ENV{HOME}/.cache/my_pod*.cache",
    ],
);

$builder->create_build_script();
