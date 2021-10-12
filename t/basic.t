package main;

use strict;
use warnings;

use Test2::V0;
use Test2::Plugin::BailOnFail;
use Test2::Tools::LoadModule;

load_module_ok 'App::Warning::Diagnostics';

like App::Warning::Diagnostics->__find_pod(),
    qr< /perldiag \. pod \z >smx, 'POD location';

done_testing;

1;

# ex: set textwidth=72 :
