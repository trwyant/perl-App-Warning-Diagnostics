package main;

use 5.006;

use strict;
use warnings;

use Test2::V0;

do './tools/extract-warnings';

my $xw = extract::warnings->new();

my $old = $xw->read_warnings_cache();

my $new = $xw->build_warnings_table();

is $new->{warnings}, $old->{_warnings}, 'Cacned warnings table did not change'
    or diag <<'EOD';

The cached warnings table has changed. you may need to run
 $ tools/extract-warnings --update
and then republish this package.
EOD

done_testing;

1;

# ex: set textwidth=72 :
