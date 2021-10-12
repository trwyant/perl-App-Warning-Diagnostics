package main;

use 5.010;

use strict;
use warnings;

use Test::More 0.88;	# Because of done_testing();

eval {
    require Test::Pod::LinkCheck::Lite;
    1;
} or plan skip_all => 'Unable to load Test::Pod::LinkCheck::Lite';

Test::Pod::LinkCheck::Lite->new(
    ignore_url	=> qr< \A https://github\.com \b >smx,
)->all_pod_files_ok(
    qw{ blib },
);

done_testing;

1;

# ex: set textwidth=72 :
