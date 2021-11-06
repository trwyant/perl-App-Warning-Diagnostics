package main;

use strict;
use warnings;

use Test::More;

require_ok 'App::Warning::Diagnostics'
    or BAIL_OUT;

like App::Warning::Diagnostics->__find_pod(),
    qr< /perldiag \. pod \z >smx, 'POD location'
    or BAIL_OUT;

done_testing;

1;

# ex: set textwidth=72 :
