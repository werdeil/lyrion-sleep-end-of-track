# Minimal stand-in for LMS, only so `perl -c` can load the plugin in CI.
package Slim::Utils::Strings;
sub import {
	my $caller = caller;
	no strict 'refs';
	*{"${caller}::cstring"} = sub { $_[1] };
}
1;
