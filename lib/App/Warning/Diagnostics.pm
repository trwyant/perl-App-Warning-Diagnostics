package App::Warning::Diagnostics;

use 5.010;

use strict;
use warnings;

use Carp;
use Config;
use List::Util qw{ max };

our $VERSION = '0.000_001';

use constant COUNT_SET_BITS	=> '%32b*';	# Unpack template

my $diagnostic;	# Hash of diagnostics by warning category
my $encoding;	# =encoding if any, undef if none
my @primitive;	# Primitive (=non-compoosite) warning categories

my $vector_len = 0;

foreach ( sort keys %warnings::Bits ) {
    my $bits = unpack COUNT_SET_BITS, $warnings::Bits{$_};
    if ( $bits == 1 ) {
	push @primitive, $_;
	$vector_len = max( $vector_len, length $warnings::Bits{$_} );
    }
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

    my $mask = "\x00" x $vector_len;

    foreach ( @warning ) {
	if ( exists $warnings::Bits{$_} ) {
	    $mask |= $warnings::Bits{$_};
	} elsif ( m/ \A no-? ( .* ) /smx && exists $warnings::Bits{$1} ) {
	    $mask &= ~ $warnings::Bits{$1};
	} else {
	    croak "Unknown warnings category $_";
	}
    }

    unpack COUNT_SET_BITS, $mask
	or return undef;	## no critic (ProhibitExplicitReturnUndef)

    my %want_diag;
    foreach ( @primitive ) {
	# NOTE: Can't just test $mask & $warnings::Bits{$_}, because
	# they are non-empty strings, so the result will also be a
	# non-empty string, which is always true whatever its contents.
	if ( unpack COUNT_SET_BITS, $mask & $warnings::Bits{$_} ) {
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

 use App::Warning::Diagnostics;
 use constant APP => 'App::Warning::Diagnostics';
 print APP->warning_diagnostics( qw{ uninitialized } );

or more simply

 $ warning-diagnostics uninitialized

=head1 DESCRIPTION

This Perl module parses F<perldiag.pod> and returns the diagnostics
associated with specified warnings categories.

=head1 METHODS

This class supports the following public methods:

=head2 warning_diagnostics

 use constant APP => 'App::Warning::Diagnostics';
 my $raw_pod = APP->warning_diagnostics(
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

=head2 pod_encoding

 say 'Encoding: ', APP->pod_encoding();

This method returns the encoding of the POD if specified; otherwise it
returns C<undef>.

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
