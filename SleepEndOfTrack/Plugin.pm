package Plugins::SleepEndOfTrack::Plugin;

# App « Veille fin du morceau » : ouvrir l'app programme immédiatement la
# veille du player à la fin du morceau en cours, via la commande native
# `jiveendoftracksleep` (Slim::Control::Jive), celle de SqueezePlay / Radio.

use strict;
use base qw(Slim::Plugin::OPMLBased);

use Time::HiRes;

use Slim::Utils::Log;
use Slim::Utils::Strings qw(string cstring);

# Fenêtre anti-rebond : Material peut recharger le menu (retour, refresh).
use constant DEBOUNCE_SECONDS => 5;

my $log = Slim::Utils::Log->addLogCategory({
	category     => 'plugin.sleependoftrack',
	defaultLevel => 'INFO',
	description  => 'PLUGIN_SLEEPENDOFTRACK',
});

# clientId => { time => epoch, text => dernier message affiché }
my %lastRun;

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

# Deux icônes :
# - install.xml / repo.xml : vignette en couleur (icon.png) pour la vue Plugins ;
# - menu des apps (Material, Jive) : glyphe icon_svg.png, que Material remplace
#   par icon.svg teinté selon le thème (convention "*_svg.png").
# OPMLBased lit l'icône du menu via _pluginDataFor('icon') ; la page Plugins
# lit install.xml directement et n'est pas concernée par cette surcharge.
use constant APP_MENU_ICON => 'plugins/SleepEndOfTrack/html/images/icon_svg.png';

sub _pluginDataFor {
	my ($class, $key) = @_;
	return APP_MENU_ICON if $key && $key eq 'icon';
	return $class->SUPER::_pluginDataFor($key);
}

sub handleFeed {
	my ($client, $callback, $args) = @_;

	my $text = $client ? _scheduleSleep($client) : cstring($client, 'PLUGIN_SLEEPENDOFTRACK_NOTHING');

	$callback->({
		items => [ {
			name => $text,
			type => 'text',
		} ],
	});
}

sub _scheduleSleep {
	my $client = shift;

	my $id  = $client->id;
	my $now = Time::HiRes::time();

	if ( my $last = $lastRun{$id} ) {
		if ( $now - $last->{time} < DEBOUNCE_SECONDS ) {
			main::INFOLOG && $log->is_info && $log->info("Ignoring repeated call for " . $client->name);
			return $last->{text};
		}
	}

	my $text;
	my $controller = $client->controller;
	my $duration   = $client->isPlaying ? $controller->playingSongDuration : 0;

	if ( $duration && $duration > 0 ) {
		my $title = _currentTitle($client);

		# Commande native : sleep (durée - position courante)
		$client->execute( ['jiveendoftracksleep'] );

		$text = cstring($client, 'PLUGIN_SLEEPENDOFTRACK_SCHEDULED', $title);

		main::INFOLOG && $log->is_info && $log->info(sprintf(
			'%s: sleep scheduled in %.0fs (end of "%s")',
			$client->name, $client->sleepTime - $now, $title
		));
	}
	else {
		$text = cstring($client, 'PLUGIN_SLEEPENDOFTRACK_NOTHING');
		main::INFOLOG && $log->is_info && $log->info($client->name . ': nothing playing with a known duration');
	}

	$lastRun{$id} = { time => $now, text => $text };

	return $text;
}

sub _currentTitle {
	my $client = shift;

	my $song  = $client->playingSong or return '';
	my $track = $song->currentTrack || $song->track or return '';
	my $url   = $track->url;

	# Flux distants (Deezer, Bandcamp...) : métadonnées fournies par le handler
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
