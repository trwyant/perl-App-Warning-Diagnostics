package main;

use 5.006;

use strict;
use warnings;

use App::Warning::Diagnostics qw{ :all };
use Test::More;

use constant CLASS	=> 'App::Warning::Diagnostics';

{
    # DANGER WILL ROBINSON!
    # Do not try this at home.
    no warnings qw{ redefine };
    sub App::Warning::Diagnostics::__find_pod {
	return 't/data/perldiag.pod';
    }
}

if ( "$]" >= 5.008 ) {
    is pod_encoding(), 'utf-8', 'POD encoding';
}

is warning_diagnostics(), undef, 'No arguments';

if ( eval { CLASS->warning_diagnostics( 'fubar' ); 1 } ) {
    fail 'Warning category fubar should produce an exception';
} else {
    like $@, qr<Unknown warnings category fubar\b>, 'fubar';
}

is warning_diagnostics( 'exiting' ), <<'EOD', 'exiting';
=over

=item No Exit

(W exiting) Because this is Hell -- or the MTA.

=back
EOD

is CLASS->warning_diagnostics( 'unopened' ), <<'EOD', 'unopened';
=over

=item Vulcan mind meld interface not active

(W unopened) I do not understand the intention of this code because I
can not read your mind.

=back
EOD

is warning_diagnostics( 'io' ), <<'EOD', 'io';
=over

=item Vulcan mind meld interface not active

(W unopened) I do not understand the intention of this code because I
can not read your mind.

=item You can check out any time you like but you can never leave

(W closed) Because the doors are locked.

=back
EOD

is CLASS->warning_diagnostics( qw{ io no-closed } ),
    <<'EOD', 'io no-closed';
=over

=item Vulcan mind meld interface not active

(W unopened) I do not understand the intention of this code because I
can not read your mind.

=back
EOD

is warning_diagnostics( qw{ closed no-closed } ),
    undef, 'closed no-closed';

is CLASS->warning_diagnostics( qw{ syntax } ),
    <<'EOD', q<syntax can find things assigned directly to 'syntax'>;
=over

=item Not valid Perl

(W syntax) This code makes no sense at all.

=item This code is ambiguous

=item This code has more than one valid parse

(W ambiguous) This code is valid Perl, but I do not know what you
actually mean by it.

=back
EOD

is CLASS->warning_diagnostics_exact( qw{ syntax } ),
    <<'EOD', q<warning_diagnostics_exact() excludes sub-categories>;
=over

=item Not valid Perl

(W syntax) This code makes no sense at all.

=back
EOD

is warning_diagnostics( { exact => 1 }, qw{ syntax } ),
    <<'EOD', q/warning_diagnostics( { exact => 1 } ) excludes sub-categories/;
=over

=item Not valid Perl

(W syntax) This code makes no sense at all.

=back
EOD

is CLASS->warning_diagnostics( qw{ ambiguous } ),
    <<'EOD', 'empty =item';
=over

=item This code is ambiguous

=item This code has more than one valid parse

(W ambiguous) This code is valid Perl, but I do not know what you
actually mean by it.

=back
EOD

done_testing;

1;

# ex: set textwidth=72 :
