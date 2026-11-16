# Minimal stand-in for LMS, only so `perl -c` can load the plugin in CI.
package Slim::Utils::Log;
sub import {}
sub addLogCategory { bless {}, shift }
1;
