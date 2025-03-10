package App::Warning::Diagnostics;

use 5.006;

use strict;
use warnings;

use Carp;
use Config;

use base qw{ Exporter };	# Because of use 5.006.

our $VERSION = '0.000_017';

our @EXPORT_OK = qw{
    builtins
    complete completion_words
    pod_encoding
    warning_diagnostics warning_diagnostics_exact
};
our %EXPORT_TAGS = (
    all	=> \@EXPORT_OK,
);

use constant COUNT_SET_BITS	=> '%32b*';	# Unpack template

my $diagnostic;	# Array of diagnostics.
my $encoding;	# =encoding if any, undef if none
my %my_bits;	# Adjusted warning bits.
my @primitive;	# Primitive (=non-compoosite) warning categories
my @composite;	# Composite warning categories.
my %builtin;	# All builtin warnings (a guess)

# The problem we need to solve is that we want to consider only built-in
# warnings categories. But it is possible to add categories, and this
# may already have been done by the time we get loaded.
#
# The following is brute-force, but exerts the force just once to
# produce the following table. The drawback of this implementation is
# that the addition of a warning category requires re-release of this
# module. Sigh.

## BEGIN REPLACEMENT

# The following code is replaced by tools/extract-warnings. Do not edit.
# Generated 2025-03-09 by Perl v5.40.1 using warnings 1.70

my @possible_builtins = qw{
    all
    ambiguous
    bareword
    chmod
    closed
    closure
    debugging
    deprecated
    deprecated::apostrophe_as_package_separator
    deprecated::delimiter_will_be_paired
    deprecated::dot_in_inc
    deprecated::goto_construct
    deprecated::missing_import_called_with_args
    deprecated::smartmatch
    deprecated::subsequent_use_version
    deprecated::unicode_property_name
    deprecated::version_downgrade
    digit
    exec
    exiting
    experimental
    experimental::alpha_assertions
    experimental::args_array_with_signatures
    experimental::autoderef
    experimental::bitwise
    experimental::builtin
    experimental::class
    experimental::const_attr
    experimental::declared_refs
    experimental::defer
    experimental::extra_paired_delimiters
    experimental::for_list
    experimental::isa
    experimental::lexical_subs
    experimental::lexical_topic
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
    scalar
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
    umask
    uninitialized
    unopened
    unpack
    untie
    utf8
    void
    y2k
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
    if ( 1 == unpack COUNT_SET_BITS, $bit_mask ) {
	push @primitive, "$_";
	$my_bits{$_} = $warnings::Bits{$_};
    } else {
	push @composite, $_;
    }
}

# Adjust the warning bits
# We jump through this hoop because there are group categories that
# nonetheless have their own bits assigned to them, over and above the
# bits associated with member categories.
# FIXME I only really need this if --exact is not asserted. Except for
# $mask, which may be needed irregardless.
{
    my $all_primitive = $warnings::NONE;
    $all_primitive |= $warnings::Bits{$_} for @primitive;
    my $not_primitive = ~ $all_primitive;
    foreach my $category ( @composite ) {
	my $m = $warnings::Bits{$category} & $not_primitive;
	my $bits = unpack COUNT_SET_BITS, $m;
	if ( $bits == 1 ) {
	    $my_bits{$category} = $m;
	}
    }
}


sub builtins {
    return keys %builtin;
}

sub complete {
    my ( $comp_line, $comp_point, @opt_spec ) = @_;

    my $word = completion_words( $comp_line, $comp_point );

    my @match;

    if ( '' eq $word ) {
	@match = ( _complete_category( $word ), _complete_option(
		$word, @opt_spec ) );
    } elsif ( $word =~ s/ \A --? //smx ) {
	@match = _complete_option( $word, @opt_spec );
    } else {
	@match = _complete_category( $word );
    }

    return( sort @match );
}

sub _complete_category {
    my ( $word ) = @_;
    my @match;
    my $re = qr< \A \Q$word\E >smx;
    foreach my $category ( builtins() ) {
	foreach ( $category, "no-$category" ) {
	    $_ =~ $re
		and push @match, $_;
	}
    }
    return @match;
}

sub _complete_option {
    my ( $word, @opt_spec ) = @_;
    my @match;
    my $re = qr< \A \Q$word\E >smx;
    foreach my $option ( @opt_spec ) {
	my @alias = split qr< [|] >smx, $option;
	if ( $alias[-1] =~ s/ ! \z //smx ) {
	    push @match, map { "--$_" } grep { $_ =~ $re } map { $_
		=> "no-$_" } @alias;
	} elsif ( $alias[-1] =~ s/ ( [:=] ) ( .* ) //smx ) {
	    push @match, map { "--$_$1" } grep { $_ =~ $re } @alias;
	} else {
	    push @match, map { "--$_" } grep { $_ =~ $re } @alias;
	}
    }
    return @match;
}

sub completion_words {
    my ( $comp_line, $comp_point ) = @_;

    defined $comp_point
	or $comp_point = length $comp_line;

    my @word = split qr/ \s+ /smx,
	substr( $comp_line, 0, $comp_point ), -1;

    return wantarray ? @word : $word[-1];
}

sub pod_encoding {
    $diagnostic
	or __read_pod();
    return $encoding;
}

sub warning_diagnostics {
    unless ( ref $_[0] ) {
	@_
	    and $_[0]->isa( __PACKAGE__ )
	    and shift @_;
	unshift @_, {};
    }
    goto &_warning_diagnostics;
}

sub warning_diagnostics_exact {	## no critic (RequireArgUnpacking)
    ref $_[0]
	and croak 'First argument may not be a reference';
    @_
	and $_[0]->isa( __PACKAGE__ )
	and shift @_;
    unshift @_, { exact => 1 };
    goto &_warning_diagnostics;
}

sub _warning_diagnostics {
    my ( $opt, @warning ) = @_;

    my $bits = $opt->{exact} ? \%my_bits : \%builtin;

    my $mask = $warnings::NONE;

    foreach ( @warning ) {
	if ( exists $bits->{$_} ) {
	    $mask |= $bits->{$_};
	} elsif ( m/ \A no- ( .* ) /smx && exists $bits->{$1} ) {
	    $mask &= ~ $bits->{$1};
	} else {
	    croak "Unknown warnings category $_";
	}
    }

    unpack COUNT_SET_BITS, $mask
	or return;

    my %want_diag;
    foreach ( keys %my_bits ) {
	# NOTE: Can't just test $mask & $my_bits{$_}, because
	# they are non-empty strings, so the result will also be a
	# non-empty string, which is always true whatever its contents.
	if ( unpack COUNT_SET_BITS, $mask & $my_bits{$_} ) {
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
			my @category = split qr< \s* , \s* | \s+ >smx, $1;
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
	} elsif ( ! defined $encoding &&
	    m/ \A =encoding \s+ ( \S+ ) /smx &&
	    "$]" >= 5.008
	) {
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

App::Warning::Diagnostics - List diagnostics enabled by specified warning categories

=head1 SYNOPSIS

 use App::Warning::Diagnostics :all;
 print warning_diagnostics( qw{ uninitialized } );

or more simply

 $ warning-diagnostics uninitialized

=head1 DESCRIPTION

This Perl module parses F<perldiag.pod> and returns the diagnostics
associated with specified warning categories.

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
of warning categories related to that diagnostic, delimited by spaces or
by commas and optional spaces.

This assumption is B<not> made by the L<diagnostics|diagnostics> module.

Real-life examples of this formatting (as of Perl 5.34.0) are:

 =item Code point 0x%X is not Unicode, and not portable
 
 (S non_unicode portable) ...

and

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
this module uses to C<$warnings::NONE>. This is also used by
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
maintain it using external code (see F<tools/extract-warnings>). This
means that new categories will not be recognized until I get around to
updating and releasing this module. This implementation will change
without prior notice if something better comes along.

B<Note> that categories in the hard-coded list that are not present in
C<%warnings::Bits> are removed before use, to try to eliminate
not-yet-implemented warnings under older Perls.

=head1 SUBROUTINES

This module supports the following subroutines. All are exportable, but
none is exported by default. They are also callable as static methods.

=head2 builtins

 say for sort builtins();

This subroutine returns an array of the names of built-in warning
categories. See L<CAVEAT|/CAVEAT> above for a caution about the data
returned by this subroutine.

=head2 complete

 say sort( complete( $ENV{COMP_LINE}, $ENV{COMP_POINT},
     qw{ foo! bar=s } ) );

This subroutine generates command line completions. The arguments are
the line being completed and the location of the cursor in that line.
Only the first argument is required; the second defaults to the length
of the first. The third and subsequent arguments are optional
L<Getopt::Long|Getopt::Long>-style option specifications.

If the word to be completed begins with a dash (C<'-'>), option
completion is done on it provided any specifications are provided;
otherwise nothing is returned.

If the word to be completed does not begin with a dash, it is assumed to
be the name of a warnings category, possibly prefixed by C<'no-'>.

Either way, possible completions are returned as a list (which may be
empty), sorted in ASCIIbetical order.

=head2 completion_words

 say for completion_words( $ENV{COMP_LINE}, $ENV{COMP_POINT} );

This subroutine breaks the line being completed into words, up to the
specified completion point. If called in scalar context, you get just
the word being completed.

This is used by L<complete()|/complete>, but exposed because it was
found to be useful in performing completion under C<bash>.

=head2 pod_encoding

 say 'Encoding: ', pod_encoding();

This subroutine returns the encoding of the POD if specified by the POD
file; otherwise it returns C<undef>.

B<Note> that this always returns C<undef> if run under Perl 5.6, even if
the POD being analyzed has an C<'=encoding'> paragraph.

=head2 warning_diagnostics

This subroutine takes as arguments an optional reference to an options
hash, and the names of one or more warning categories as specified by
L<warnings|warnings>, and returns the raw POD for the diagnostics
enabled by these warning categories. If called in scalar context, it
returns a string containing one or more C<=item> paragraphs enclosed in
C<'=over'> and C<'=back'>, or C<undef> if no categories are specified.
If called in list context it returns the individual C<=item> paragraphs,
or nothing if no categories were specified or no diagnostics were found.

Note that if you are interested in knowing how many diagnostics a
particular category or set of categories produces you can get it by
using the Saturn operator:

 my $count =()= warning_diagnostics( $category );

Categories are specified by name, and more than one can be specified.
Group categories such as C<'io'> will be expanded. You can negate a
category by prefixing C<'no-'> to its name. Categories are
combined in left-to-right order, so

 warning_diagnostics( qw{ io no-closed no-unopened } )

selects all diagnostics enabled by

 no warnings;
 use warnings io;
 no warnings qw{ closed unopened };

If you specify an unknown warnings category an exception will be thrown.
Be aware that what the legal categories are depends on the version of
Perl under which you are running.

B<Note> that C<experimental::*> warnings tend to be removed from
F<perldiag.pod> once the feature becomes no longer experimental, though
the warnings categories themselves are retained for backward
compatibility. Such categories will return no diagnostics. This looks
like an empty C<=over/=back> if in scalar context, but an empty list in
list context.

The following options are supported:

=over

=item exact

This causes sub-categories of specified warnings to be excluded from the
return.

=back

=head2 warning_diagnostics_exact

This B<deprecated> subroutine is equivalent to

 warning_diagnostics( { exact => 1 }. ... );

The latter is preferred, and this subroutine will eventually be removed.

It is an error to pass a hash reference as the first argument.

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

Copyright (C) 2021-2022, 2025 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
