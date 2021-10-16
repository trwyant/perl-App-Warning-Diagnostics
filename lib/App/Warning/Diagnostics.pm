package App::Warning::Diagnostics;

use 5.010;

use strict;
use warnings;

use Carp;
use Config;
use Exporter qw{ import };

our $VERSION = '0.000_007';

our @EXPORT_OK = qw{ builtins pod_encoding warning_diagnostics };
our %EXPORT_TAGS = (
    all	=> \@EXPORT_OK,
);

use constant COUNT_SET_BITS	=> '%32b*';	# Unpack template

my $diagnostic;	# Array of diagnostics.
my $encoding;	# =encoding if any, undef if none
my @primitive;	# Primitive (=non-compoosite) warning categories
my %builtin;	# All builtin warnings (a guess)

# The problem we need to solve is that we want to consider only built-in
# warnings categories. But it is possible to add categories, and this
# may already have been done by the time we get loaded.
#
=begin comment

# So we do the best we can by:
#
# * Masking out bits that are not in $warnings::NONE. This does not get
#   updated when categories are added, but because a category only takes
#   two bits we will still accept zero to three added categories as a
#   result of this check.
# * Requiring categories occupying the last byte of $warnings::NONE
#   to be all lower-case or colons. This is an heuristic based on the
#   fact that added categories are qualified by the name space that
#   added them. which is typically mixed-case. This also potentially
#   catches built-in primitives defined in the last byte, and built-in
#   composites that include primitives defined in the last byte, but so
#   far (as of Perl 5.34.0) those are all lower-case or colons.
# * Brute-force elimination of categories occupying the last byte that
#   are not amenable to any of the above.
#
# Only the first check is guaranteed, so we may still get as many as
# three added categories, but the second check makes more than zero
# unlikely. I hope. But my hope is cheated because constant.pm calls
# warnings::register.
{
    my %brute_force = map { $_ => 1 } qw{ constant };
    my $all = ~ $warnings::NONE;
    my $suspicious = $warnings::NONE;
    substr $suspicious, -1, 1, "\xFF";
    foreach ( sort keys %warnings::Bits ) {
	my $bit_mask = $warnings::Bits{$_};
	my $set_bits = unpack COUNT_SET_BITS, $bit_mask & $all
	    or next;
	unpack COUNT_SET_BITS, $bit_mask & $suspicious
	    and ( m/ [[:upper:]] /smx || $brute_force{$_} )
	    and next;
	$builtin{$_} = $bit_mask;
	1 == $set_bits
	    and push @primitive, $_;
    }
}

# The following is really brute-force, but working directly with (say)
# %warnings::Bits involved so much ad-hocery to strain out stuff that
# got added by warnings::register that eventually I just gave up. If
# this does not work I will probably extract something like it to a
# tools/ script, hand-groom the output, and slap that into this module.
{
    local $/ = undef;	# Slurp mode
    open my $fh, '<', $INC{'warnings.pm'}
	or die "Unable to open warnings.pm: $!\n";
    my $source = <$fh>;
    close $fh;
    # (
    $source =~ m/ ( ^ \Qour %Bits = (\E [^)]+ \); $ ) /smx
	or die "Unable to find definition of %Offsets hash\n";
    my $hash = $1;

    while ( $hash =~ m/ ' ( [\w:]+ ) ' \s* => \s* "[^"]+" \s* , /smxg ) {
	my $bit_mask = $warnings::Bits{$1};
	$builtin{$1} = $bit_mask;
	1 == unpack COUNT_SET_BITS, $bit_mask
	    and push @primitive, "$1";
    }
}

=end comment

=cut

# The following is also brute-force, but exerts the force just once to
# produce the following table. The drawback of this implementation is
# that the addition of a warning category requires re-release of this
# module. Sigh.

## BEGIN REPLACEMENT

# The following code is replaced by tools/extract-warnings. Do not edit.
# Generated 2021-10-15 by Perl v5.35.4 using warnings 1.54

my @possible_builtins = qw{
    all
    ambiguous
    bareword
    closed
    closure
    debugging
    deprecated
    digit
    exec
    exiting
    experimental
    experimental::alpha_assertions
    experimental::bitwise
    experimental::const_attr
    experimental::declared_refs
    experimental::defer
    experimental::isa
    experimental::lexical_subs
    experimental::postderef
    experimental::private_use
    experimental::re_strict
    experimental::refaliasing
    experimental::regex_sets
    experimental::script_run
    experimental::signatures
    experimental::smartmatch
    experimental::try
    experimental::uniprop_wildcards
    experimental::vlb
    glob
    illegalproto
    imprecision
    inplace
    internal
    io
    layer
    locale
    malloc
    misc
    missing
    newline
    non_unicode
    nonchar
    numeric
    once
    overflow
    pack
    parenthesis
    pipe
    portable
    precedence
    printf
    prototype
    qw
    recursion
    redefine
    redundant
    regexp
    reserved
    semicolon
    severe
    shadow
    signal
    substr
    surrogate
    syntax
    syscalls
    taint
    threads
    uninitialized
    unopened
    unpack
    untie
    utf8
    void
};

## END REPLACEMENT

# The reason for going through this loop is that we may be running under
# an earlier version of Perl than the one that generated the above, so
# we need to figure out which of the above list are actually recognized
# by warnings.pm

foreach ( @possible_builtins ) {
    my $bit_mask = $warnings::Bits{$_}
	or next;
    $builtin{$_} = $bit_mask;
    1 == unpack COUNT_SET_BITS, $bit_mask
	and push @primitive, "$_";
}


sub builtins {
    return keys %builtin;
}

sub pod_encoding {
    $diagnostic
	or __read_pod();
    return $encoding;
}

sub warning_diagnostics {
    my @warning = @_;

    # Maybe called as static method.
    @warning
	and $warning[0]->isa( __PACKAGE__ )
	and shift @warning;

    my $mask = $warnings::NONE;

    foreach ( @warning ) {
	if ( exists $builtin{$_} ) {
	    $mask |= $builtin{$_};
	} elsif ( m/ \A no- ( .* ) /smx && exists $builtin{$1} ) {
	    $mask &= ~ $builtin{$1};
	} else {
	    croak "Unknown warnings category $_";
	}
    }

    unpack COUNT_SET_BITS, $mask
	or return;

    my %want_diag;
    foreach ( @primitive ) {
	# NOTE: Can't just test $mask & $builtin{$_}, because
	# they are non-empty strings, so the result will also be a
	# non-empty string, which is always true whatever its contents.
	if ( unpack COUNT_SET_BITS, $mask & $builtin{$_} ) {
	    $want_diag{$_} = 1;
	}
    }


    $diagnostic
	or __read_pod();

    my @pod =
	map { $_->[1] }
	grep { _want_diag( \%want_diag, $_ ) } @{ $diagnostic };

    wantarray
	and return @pod;

    return join '', "=over\n\n", @pod, "=back\n";
}

# The following is verbatim from diagnostics.pm

## VERBATIM START diagnostics
my $privlib = $Config{privlibexp};
if ($^O eq 'VMS') {
    require VMS::Filespec;
    $privlib = VMS::Filespec::unixify($privlib);
}
my @trypod = (
	   "$privlib/pod/perldiag.pod",
	   "$privlib/pods/perldiag.pod",
	  );
## VERBATIM END

sub __find_pod {
    foreach ( @trypod ) {
	-e
	    or next;
	return "$_";
    }
    croak 'Unable to find perldiag.pod';
}

sub __read_pod {

    my $pod_file = __find_pod();

    open my $fh, '<', $pod_file	## no critic (RequireBriefOpen)
	or croak "Unable to open $pod_file: $!";

    my $nest = 0;
    my $raw_pod;
    my $pod_handler = my $ignore_pod = sub {};
    my $accumulate_pod = sub { ${ $raw_pod } .= $_; };

    while ( <$fh> ) {

	# Yes, this is done with regular expressions rather than a POD
	# parser, but I figure if it's good enough for the diagnostics
	# module it's good enough for me.

	if ( m/ \A =over \b /smx ) {
	    $nest++
		or $pod_handler = $accumulate_pod;
	    $pod_handler->();
	} elsif ( m/ \A =back \b /smx ) {
	    if ( --$nest ) {
		$pod_handler->();
	    } else {
		$pod_handler = $accumulate_pod;
		# $pod_handler->();
		last;
	    }
	} elsif ( m/ \A =item \b /smx ) {

	    if ( 1 == $nest ) {
		my $leader = $_;
		while ( <$fh> ) {
		    $leader .= $_;
		    m/ \S /smx
			or next;
		    m/ ^ = /smx
			and next;
		    if ( m/ \A \( [[:upper:]] \s+ ( [\w:, ]+ ) \) /smx ) {
			$_ = $leader;
			my @category = split qr< \s* , \s* >smx, $1;
			push @{ $diagnostic ||= [] }, [ \@category, $leader ];
			$raw_pod = \( $diagnostic->[-1][1] );
			$pod_handler = $accumulate_pod;
		    } else {
			$pod_handler = $ignore_pod;
		    }
		    last;
		}
	    } else {
		$pod_handler->();
	    }
	} elsif ( ! defined $encoding && m/ \A =encoding \s+ ( \S+ ) /smx ) {
	    $diagnostic = $raw_pod = undef;
	    $encoding = $1;
	    seek $fh, 0, 0;
	    $pod_handler = $ignore_pod;
	    binmode $fh, ":encoding($encoding)"
		or carp "Failed to set input encoding to $encoding: $!";
	} elsif ( m/ \A = /smx ) {
	    $pod_handler = $ignore_pod;
	} else {
	    $pod_handler->();
	}
    }

    close $fh;

    return;
}

sub _want_diag {
    my ( $want, $diag ) = @_;
    foreach my $cat ( @{ $diag->[0] } ) {
	$want->{$cat}
	    and return 1;
    }
    return 0;
}

1;

__END__

=head1 NAME

App::Warning::Diagnostics - List diagnostics enabled for specified warning categories

=head1 SYNOPSIS

 use App::Warning::Diagnostics :all;
 print warning_diagnostics( qw{ uninitialized } );

or more simply

 $ warning-diagnostics uninitialized

=head1 DESCRIPTION

This Perl module parses F<perldiag.pod> and returns the diagnostics
associated with specified warnings categories.

=head1 CAVEAT

There are a number of reasons why the output of this module can never be
considered authoritative, and why the module itself may break.

=head2 Reliance on formatting of F<perldiag.pod>

This module relies on the formatting of F<perldiag.pod> more heavily
than the core L<diagnostics|diagnostics> module does. The following
assumptions are known to have been made:

=over

=item * Diagnostics are defined by first-level =item paragraphs

Consecutive C<=item> paragraphs are supported. This assumption is also
made by the L<diagnostics|diagnostics> module.

=item * The first text paragraph after the =item specifies warning categories

Specifically, this paragraph is assumed to begin with parenthesized text
consisting of a single letter defining the warning severity and a list
of warning categories related to that diagnostic, delimited by commas
and optional spaces.

This assumption is B<not> made by the L<diagnostics|diagnostics> module.

A real-life example of this formatting (as of Perl 5.34.0) is

 =item Use of tainted arguments in %s is deprecated

 (W taint, deprecated) ...

Such warnings are assumed to be enabled if either of the specified
warnings is enabled.

=back

=head2 Use of undocumented interfaces

This module uses the contents of C<%warnings::Bits> to combine warning
categories.  This is also used by L<B::Deparse|B::Deparse> and
L<Test::Warn|Test::Warn>, but is not documented.

This module initializes the bit mask used to combine warning categories
this module uses C<$warnings::NONE>. This is also used by
L<B::Deparse|B::Deparse>, but is not documented.

=head2 Custom warning categories

Perl has the ability to create user-added warning categories, and there
appears to be no way to positively distinguish these from Perl-native
categories using the data present in L<warnings|warnings>.

This should not be a problem for
L<warning_diagnostics()|/warning_diagnostics>, but is a potential
problem for L<builtins()|/builtins>. Various heuristics against
C<%warnings::Bits> were tried to mitigate this problem, but found to be
unsatisfactory. The current solution is to hard-code the list, and
maintain it using external code (see F<tools/extract-warnings>. This
means that new categories will not be recognized until I get around to
updating and releasing this module. This implementation will change if
something better comes along.

=head1 SUBROUTINES

This module supports the following subroutines. All are exportable, but
none is exported by default. They are also callable as static methods.

=head2 builtins

 say for sort builtins();

This subroutine returns an array of the names of built-in warning
categories. See L<CAVEAT|/CAVEAT> above for a caution about the data
returned by this subroutine.

=head2 pod_encoding

 say 'Encoding: ', pod_encoding();

This subroutine returns the encoding of the POD if specified by the POD
file; otherwise it returns C<undef>.

=head2 warning_diagnostics

 my $raw_pod = warning_diagnostics(
     qw{ uninitialized } );

Given warning categories as specified by L<warnings|warnings>, returns
the raw POD for the diagnostics enabled by these warning categories. If
called in scalar context, it returns a string containing one or more
C<=item> paragraphs enclosed in C<'=over'> and C<'=back'>, or C<undef>
if no categories are specified. If called in list context it returns the
individual C<=item> paragraphs, or nothing if no categories were
specified or no diagnostics were found.

Note that if you are interested in knowing how many diagnostics a
particular category or set of categories produces you can get it by
using the Saturn operator:

 my $count =()= warning_diagnostics( $category );

Categories are specified by name, and more than one can be specified.
Group categories such as C<'io'> will be expanded. You can negate a
category by prefixing C<'no-'> to its name. Categories are
combined in left-to-right order, so

 warning_diagnostics( qw{ io no-closed no-unopened } )

selects all diagnostics generated by

 no warnings;
 use warnings io;
 no warnings qw{ closed unopened };

If you specify an unknown warnings category an exception will be thrown.
Be aware that what the legal categories are depends on the version of
Perl under which you are running.

B<Note> that not all the C<experimental::> warnings correspond to
diagnostics in L<perldiag|perldiag>. I have no idea whether this is
intentional or an oversight.

=head1 SEE ALSO

L<diagnostics|diagnostics>

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-Warning-Diagnostics>,
L<https://github.com/trwyant/perl-App-Warning-Diagnostics/issues/>, or in
electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
