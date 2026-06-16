package My::Updater;

use 5.006;

use strict;
use warnings;

use Carp;

our $VERSION = '0.000_001';

sub new {
    my ( $class, %arg ) = @_;
    defined $arg{file}
	or croak "'file' argument required";
    defined $arg{mark}
	or $arg{mark} = '# $$';
    defined $arg{encoding}
	or $arg{encoding} = 'utf-8';
    $arg{_encoding} = $arg{encoding} eq '' ?
	'' :
	":encoding($arg{encoding})";
    return bless \%arg, $class;
}

sub update {
    my ( $self, $tag, $mod, $mark ) = @_;
    my ( @preamble, @postamble );

    defined $mark
	or $mark = $self->{mark};

    my $mark_begin = "$mark BEGIN $tag\n";
    my $mark_end   = "$mark END\n";

    open my $fh, "<$self->{_encoding}", $self->{file}
	or croak "Failed to open $self->{file} for input: $!";
    local $_ = undef;	# while ( <$fh> ) does not localize
    while ( <$fh> ) {
	push @preamble, $_;
	$_ eq $mark_begin
	    and last;
    }
    defined $_
	or croak "Failed to find '$mark BEGIN $tag' in $self->{file}";
    push @preamble, "\n";
    while ( <$fh> ) {
	$_ eq $mark_end
	    and last;
    }
    defined $_
	or croak "Failed to find '$mark END' in $self->{file}";
    push @postamble, "\n", $_;
    push @postamble, <$fh>;
    close $fh;

    open $fh, ">$self->{_encoding}", $self->{file}
	or croak "Failed to open $self->{file} for output: $!";
    print { $fh } @preamble, $mod, @postamble;
    close $fh;

    return;
}

1;

__END__

=head1 NAME

My::Updater - Update marked chunks of files.

=head1 SYNOPSIS

 my $upd = My::Updater->new( file => 'file.txt' );
 $upd->update( limerick => <<'EOD' );
 There was a young lady named Bright,
 Who could travel much faster than light.
     She set out one day
     In a relative way,
 And returned the previous night.
 EOD

=head1 DESCRIPTION

This Perl class replaces marked chunks of data in text files. The
example in the synopsis (which takes all the defaults) replaces
everything between

 # $$ BEGIN limerick
 ...
 # $$ END

with the given limmerick.

=head1 METHODS

This class supports the following public methods:

=head2 new

This static method instantiats the object. It takes the following
arguments as name/value pairs:

=over

=item encoding

This argument specifies the file encoding. Specify C<''> to use the
system encoding.

The default is 'utf-8'.

=item file

This argument specifies the name of the file to update. It is required,
and an exception will be thrown if it is not specified.

=item marker

This argument specifies the leading part of the string that brackets the
text to replace. Where code is involved, it should look like a comment.
In POD, the recommended marker is C<'=for comment'>.

The default is C<'# $$'>.

=back

=head2 update

 $upd->update( tag => $content );

This method replaces the tagged chunk of text in the file. See
L<SYNOPSIS|/SYNOPSIS> for an example of its use. The arguments are the
tag of the chunk to replace and the new content. An optional third
argument overrides the L<marker|/marker> specified when the object was
instantiated.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://github.com/trwyant/perl-Astro-Coord-ECI/issues> or in
electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2026 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the files F<LICENSE-Artistic> and F<LICENSE-GPL>.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
