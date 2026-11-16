package Plugins::SleepEndOfTrack::Plugin;

# App that, when opened, puts the player to sleep at the end of the current
# track, using SqueezePlay's native `jiveendoftracksleep` command.

use strict;
use base qw(Slim::Plugin::OPMLBased);

use Time::HiRes;

use Slim::Utils::Log;
use Slim::Utils::Strings qw(cstring);

# Material may reload the menu (back navigation, refresh).
use constant DEBOUNCE_SECONDS => 5;

# install.xml's icon is for the plugin manager; the apps menu gets a glyph
# that Material swaps for the theme-tinted icon.svg (*_svg.png convention).
use constant APP_MENU_ICON => 'plugins/SleepEndOfTrack/html/images/icon_svg.png';

my $log = Slim::Utils::Log->addLogCategory({
	category     => 'plugin.sleependoftrack',
	defaultLevel => 'INFO',
	description  => 'PLUGIN_SLEEPENDOFTRACK',
});

my %lastRun;    # client id => { time, title }

sub initPlugin {
	my $class = shift;

	$class->SUPER::initPlugin(
		feed   => \&handleFeed,
		tag    => 'sleependoftrack',
		is_app => 1,
		weight => 1,
	);
}

sub getDisplayName { 'PLUGIN_SLEEPENDOFTRACK' }

# OPMLBased reads the apps menu icon through this method.
sub _pluginDataFor {
	my ($class, $key) = @_;
	return APP_MENU_ICON if $key && $key eq 'icon';
	return $class->SUPER::_pluginDataFor($key);
}

sub handleFeed {
	my ($client, $callback, $args) = @_;

	# Tapping the item re-runs this feed with an item_id: never reschedule then.
	my $itemId   = $args && $args->{params} && $args->{params}->{item_id};
	my $subLevel = defined $itemId && length $itemId;

	my $title;
	if ($client && $subLevel) {
		$title = $lastRun{$client->id} && $lastRun{$client->id}->{title};
	}
	elsif ($client) {
		$title = _scheduleSleep($client);
	}

	my $remaining = $client ? $client->sleepTime - Time::HiRes::time() : 0;
	my $text = !defined $title ? cstring($client, 'PLUGIN_SLEEPENDOFTRACK_NOTHING')
	         : $remaining > 0  ? cstring($client, 'PLUGIN_SLEEPENDOFTRACK_SCHEDULED_IN', $title, _formatDuration($remaining))
	         :                   cstring($client, 'PLUGIN_SLEEPENDOFTRACK_SCHEDULED', $title);

	# redirect + nextWindow: Material runs it, shows the title as a toast and
	# goes back instead of opening a page.
	my @items = ( {
		name       => $text,
		type       => 'redirect',
		url        => sub { _backFeed($text, @_) },
		nextWindow => 'parent',
	} );

	# Always offered on a sub-level call so the tapped index keeps existing
	# even if the timer fired in the meantime.
	if ( $client && ($remaining > 0 || $subLevel) ) {
		push @items, {
			name       => cstring($client, 'PLUGIN_SLEEPENDOFTRACK_CANCEL'),
			type       => 'redirect',
			url        => \&_cancelFeed,
			nextWindow => 'parent',
		};
	}

	$callback->({ items => \@items });
}

sub _cancelFeed {
	my ($client, $callback, $args) = @_;

	if ($client) {
		$client->execute( ['sleep', 0] );
		# Reopening the app right after must schedule again, not be debounced.
		delete $lastRun{$client->id};
		main::INFOLOG && $log->is_info && $log->info($client->name . ': sleep cancelled');
	}

	_backFeed(cstring($client, 'PLUGIN_SLEEPENDOFTRACK_CANCELLED'), $client, $callback, $args);
}

# Never displayed. Two items on purpose: Material wraps a single text item in
# a <div> that would show up raw in the toast, and LMS turns an empty list
# into an "Empty" item.
sub _backFeed {
	my ($label, $client, $callback, $args) = @_;
	$callback->({ items => [
		{ name => $label, type => 'text' },
		{ name => $label, type => 'text' },
	] });
}

sub _formatDuration {
	my $seconds = int(shift() + 0.5);
	my $h = int($seconds / 3600);
	my $m = int(($seconds % 3600) / 60);
	my $s = $seconds % 60;
	return $h ? sprintf('%d:%02d:%02d', $h, $m, $s) : sprintf('%d:%02d', $m, $s);
}

# Returns the title of the track sleep was scheduled on, undef if none.
sub _scheduleSleep {
	my $client = shift;

	my $id  = $client->id;
	my $now = Time::HiRes::time();

	if ( my $last = $lastRun{$id} ) {
		if ( $now - $last->{time} < DEBOUNCE_SECONDS ) {
			main::INFOLOG && $log->is_info && $log->info("Ignoring repeated call for " . $client->name);
			return $last->{title};
		}
	}

	my $title;
	my $duration = $client->isPlaying ? $client->controller->playingSongDuration : 0;

	if ( $duration && $duration > 0 ) {
		$title = _currentTitle($client);
		$client->execute( ['jiveendoftracksleep'] );

		main::INFOLOG && $log->is_info && $log->info(sprintf(
			'%s: sleep scheduled in %.0fs (end of "%s")',
			$client->name, $client->sleepTime - $now, $title
		));
	}
	else {
		main::INFOLOG && $log->is_info && $log->info($client->name . ': nothing playing with a known duration');
	}

	$lastRun{$id} = { time => $now, title => $title };

	return $title;
}

sub _currentTitle {
	my $client = shift;

	my $song  = $client->playingSong or return '';
	my $track = $song->currentTrack || $song->track or return '';
	my $url   = $track->url;

	if ( $track->remote ) {
		my $handler = Slim::Player::ProtocolHandlers->handlerForURL($url);
		if ( $handler && $handler->can('getMetadataFor') ) {
			my $meta = $handler->getMetadataFor($client, $url);
			return $meta->{title} if $meta && $meta->{title};
		}
	}

	return $track->title || Slim::Music::Info::getCurrentTitle($client, $url) || '';
}

1;
