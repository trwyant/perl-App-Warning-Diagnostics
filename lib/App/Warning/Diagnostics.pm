package App::Warning::Diagnostics;

use 5.010;

use strict;
use warnings;

use Carp;
use Config;
use Exporter qw{ import };

our $VERSION = '0.000_003';

our @EXPORT_OK = qw{ bash_completion pod_encoding warning_diagnostics };
our %EXPORT_TAGS = (
    all	=> \@EXPORT_OK,
);

use constant COMP_WORDBREAKS	=> qr/ ( \s+ | ["'\@><=;|&(:] ) /smx;	# )
use constant COUNT_SET_BITS	=> '%32b*';	# Unpack template

my $diagnostic;	# Array of diagnostics.
my $encoding;	# =encoding if any, undef if none
my @primitive;	# Primitive (=non-compoosite) warning categories
my %builtin;	# All builtin warnings (a guess)

# The problem we need to solve is that we want to consider only built-in
# warnings categories. But it is possible to add categories, and this
# may already have been done by the time we get loaded. So we do the
# best we can by:
#
# * Masking out bits that are not in $warnings::NONE. This does not get
#   updated when categories are added, but because a category only takes
#   two bits we will still accept zero to three added categories as a
#   result of this check.
# * Requiring categories occupying the last byte of $warnings::NONE
#   to be all lower-case or colons. This is an heuristic based on the
#   fact that added categories are qualified by the name space that
#   added them. which is typically mixed-case. This also catches
#   built-in primitives defined in the last byte, and built-in
#   composites that include primitives defined in the last byte, but so
#   far (as of Perl 5.34.0) those are all lower-case or colons.
#
# Only the first check is guaranteed, so we may still get as many as
# three added categories, but the second check makes more than zero
# unlikely. I hope.
{
    my $all = ~ $warnings::NONE;
    my $suspicious = $warnings::NONE;
    substr $suspicious, -1, 1, "\xFF";
    foreach ( sort keys %warnings::Bits ) {
	my $bit_mask = $warnings::Bits{$_};
	my $set_bits = unpack COUNT_SET_BITS, $bit_mask & $all
	    or next;
	unpack COUNT_SET_BITS, $bit_mask & $suspicious
	    and m/ [[:upper:]] /smx
	    and next;
	$builtin{$_} = $bit_mask;
	1 == $set_bits
	    and push @primitive, $_;
    }
}

sub bash_completion {
    my @option = @_;

    # Maybe called as static method.
    @option
	and $option[0]->isa( __PACKAGE__ )
	and shift @option;

    my $line = $ENV{COMP_LINE};
    my $point = $ENV{COMP_POINT} // length $line;

    my @words = split COMP_WORDBREAKS, substr $line, 0, $point;
    $line =~ m/ @{[ COMP_WORDBREAKS ]} \z /smx
	and push @words, '';

    @words
	or return;

    my @rslt;

    my $complete = $words[-1];

    # NOTE to the curious: I believe nothing below this point is
    # specific to bash. If there is need for a readline_completion() the
    # below code could be factored into a separate subroutine to be
    # called by bash_completion(), readline_completion(), or potentially
    # any other completion code.

    if ( my ( $prefix ) = $complete =~ m/ \A ( --? ) /smx ) {

	my @opts;
	foreach my $o ( @option ) {
	    my ( $names, $kind ) = split qr< ( [:=!] ) >smx, $o;
	    $kind //= '';
	    @opts = split qr< [|] >smx, $names;
	    if ( '!' eq $kind ) {
		push @rslt, grep { ! index $_, $complete }
		    map {; ( "$prefix$_", "${prefix}no$_", "${prefix}no-$_" ) }
		    @opts;
	    } else {
		push @rslt, grep { ! index $_, $complete }
		    map { "$prefix$_" } @opts;
	    }
	}

    } else {
	push @rslt, grep {! index $_, $complete }
	    map {; ( $_, "no$_", "no-$_" ) } keys %builtin;
    }

    @rslt = sort @rslt;

    wantarray
	and return @rslt;
    defined wantarray
	and return \@rslt;

    say for @rslt;

    return;
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
	} elsif ( m/ \A no-? ( .* ) /smx && exists $builtin{$1} ) {
	    $mask &= ~ $builtin{$1};
	} else {
	    croak "Unknown warnings category $_";
	}
    }

    unpack COUNT_SET_BITS, $mask
	or return undef;	## no critic (ProhibitExplicitReturnUndef)

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

    my $raw_pod = join '', "=over\n\n", (
	map { $_->[1] }
	grep { $want_diag{$_->[0]} } @{ $diagnostic }
    ),
    "=back\n";

    return $raw_pod;
}

sub __builtins {
    return keys %builtin;
}

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
		    if ( m/ \A \( [[:upper:]] \s+ ( [\w:]+ ) \) /smx ) {
			$_ = $leader;
			push @{ $diagnostic ||= [] }, [ "$1", $leader ];
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

=head2 Use of undocumented interfaces

In order to find out what the warning categories are, this module
consults C<%warnings::Bits>. This hash is also used by
L<B::Deparse|B::Deparse> and L<Test::Warn|Test::Warn>, but is not
documented.

This module initialize the bit mask used to combine warning categories
this module uses C<$warnings::NONE>. This is also used by
L<B::Deparse|B::Deparse>, but is not documented.

=head2 Custom warning categories

Perl has the ability to create user-added warning categories, and there
appears to be no way to positively distinguish these from Perl-native
categories using the data present in L<warnings|warnings>.

This should not be a problem for
L<warning_diagnostics()|/warning_diagnostics>, but is a potential
problem for L<bash_completion()|/bash_completion>.
Heuristics are applied to try to mitigate this problem:

=over

=item * Items whose bit mask contains no set bits after a bitwise 'and'
with the complement of C<$warnings::NONE> are not considered for
completion. This works because the current (Perl 5.34.0) implementation
of C<warnings|warnings> does not not extend
C<$warnings::NONE>) when custom categories are added. But this
may accept as many as three custom categories, since each uses two bits.

=item * Mixed-case category names are not considered if their bit mask
contains only bits corresponding to the last byte of C<$warnings::NONE>.
This is because added categories are named after the name space that
created them, which is typically mixed-case. The restriction of this
check to only those categories defined in the last byte is pure paranoia
on my part.

=back

=head1 SUBROUTINES

This module supports the following subroutines. All are exportable, but
none is exported by default. They are also callable as static methods.

=head2 bash_completion

 print bash_completion( qw{ foo! bar=s } );

This static method performs C<bash> completion. Its arguments are
L<Getopt::Long|Getopt::Long> option specs, which are used if the word to
be completed starts with C<->. The results are returned differently
depending on the context in which it is called:

=over

=item * list context

The results array is returned.

=item * scalar context

A reference to the results array is returned.

=item * void context

The results are printed to C<STDOUT>. This how C<bash> wants completions
reported.

=back

=head2 pod_encoding

 say 'Encoding: ', pod_encoding();

This method returns the encoding of the POD if specified by the POD
file; otherwise it returns C<undef>.

=head2 warning_diagnostics

 my $raw_pod = warning_diagnostics(
     qw{ uninitialized } );

Given warning categories as specified by L<warnings|warnings>, returns
the raw POD for the diagnostics enabled by these warning categories. The
output will be a string containing one or more C<=item> paragraphs
enclosed in C<'=over'> and C<'=back'>, or C<undef> if no categories are
specified.

Categories are specified by name, and more than one can be specified.
Group categories such as C<'io'> will be expanded. You can negate a
category by prefixing C<'no'> or C<'no-'> to its name. Categories are
combined in left-to-right order, so

 APP->warning_diagnostics( qw{ io noclosed no-unopened } )

selects all diagnostics generated by

 no warnings;
 use warnings io;
 no warnings qw{ closed unopened };

If you specify an unknown warnings category an exception will be thrown.
Be aware that what the legal categories are depends on the version of
Perl under which you are running.

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
