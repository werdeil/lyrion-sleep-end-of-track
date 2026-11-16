# Minimal stand-in for LMS, only so `perl -c` can load the plugin in CI.
package Slim::Plugin::OPMLBased;
sub initPlugin {}
sub _pluginDataFor {}
1;
