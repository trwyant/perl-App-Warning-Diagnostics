package main;

use 5.010;

use strict;
use warnings;

use Test2::V0 -target => 'App::Warning::Diagnostics';

is complete( '-', undef, qw{ foo=s bar! } ),
    [ qw{ -bar -foo -no-bar -nobar } ],
    q<Complete '-' with option spec foo=s bar!>;

is complete( '--f', undef, qw{ foo=s bar! } ),
    [ qw{ --foo } ],
    q<Complete '--f' with option spec foo=s bar!>;

is complete( 'un' ), bits( 'un' ), q<Complete 'un'>;

is complete( 'n' ), bits( 'n' ), q<Complete 'n'>;

done_testing;

sub bits {
    my ( $pfx ) = @_;
    return [ sort grep { ! index $_, $pfx }
	map {; $_, "no$_", "no-$_" }
	CLASS->__builtins() ];
}

sub complete {
    my ( $line, $point, @opt_spec ) = @_;
    defined $line
	or die "Test bug - \$line undefined";
    local $ENV{COMP_LINE} = $line;
    defined $point
	and local $ENV{COMP_POINT} = $point;
    return scalar CLASS->bash_completion( @opt_spec );
}

1;

# ex: set textwidth=72 :
