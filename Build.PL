use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Gtk::HandyCList',
    license             => 'perl',
    dist_author         => 'Simon Cozens',
    dist_version_from   => 'lib/Gtk/HandyCList.pm',
    requires => {
		'Gnome'      => 0,
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Gtk-HandyCList-*' ],
	create_makefile_pl => 'traditional',
);

$builder->create_build_script();
