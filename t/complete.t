package main;

use 5.006;

use strict;
use warnings;

use App::Warning::Diagnostics qw{ builtins complete };
use Test::More 0.88;	# Because of done_testing();

use constant REF_ARRAY	=> ref [];

complete_ok( 'foo xyzzy', [], q<Complete 'foo xyzzy'> );

complete_ok( 'foo --bar', [], q<Complete 'foo --bar'> );

complete_ok( 'foo i',
    [ qw{ illegalproto imprecision inplace internal io } ],
    q<Complete 'foo i'>,
);

complete_ok(
    [ 'foo -b', undef, qw{ bar! baz=s } ],
    [ qw{ --bar --baz= } ],
    q<Complete 'foo -b'>,
);

complete_ok(
    [ 'foo -n', undef, qw{ bar! baz=s } ],
    [ qw{ --no-bar } ],
    q<Complete 'foo -n'>,
);

complete_ok(
    [ 'foo ', undef, qw{ bar! baz=s } ],
    [ sort( ( map { $_ => "no-$_" } builtins() ),
	    qw{ --bar --no-bar --baz= } ) ],
    q<Complete 'foo ', which should return everything>,
);

done_testing;

sub complete_ok {
    my ( $complete_arg, $want, $title ) = @_;
    REF_ARRAY eq ref $complete_arg
	or $complete_arg = [ $complete_arg ];
    @_ = ( [ complete( @{ $complete_arg } ) ], $want, $title );
    goto &is_deeply;
}

1;

# ex: set textwidth=72 :
