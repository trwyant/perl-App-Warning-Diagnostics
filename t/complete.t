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

# FIXME the problem with testing this is that bits() has to become a LOT
# smarter to duplicate what the code is producing -- in fact, it needs
# to duplicate the code being tested, and how is that a test? I am
# reluctant to provide a manual list because that will change by Perl
# release.
# is complete( 'n' ), bits( 'n' ), q<Complete 'n'>;

is complete( 'experimental::r' ), bits( 'experimental::r' ),
    q<Complete 'experimental::r'>;

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
