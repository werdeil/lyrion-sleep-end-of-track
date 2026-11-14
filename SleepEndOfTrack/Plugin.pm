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

	# Un item_id signifie que Material ouvre un sous-élément (le message-bouton) :
	# XMLBrowser rappelle alors ce feed, il ne faut pas reprogrammer la veille.
	my $itemId   = $args && $args->{params} && $args->{params}->{item_id};
	my $subLevel = defined $itemId && length $itemId;

	my $title;    # titre du morceau visé, undef si rien n'est programmé
	if ($client && $subLevel) {
		# Jamais de programmation ici, même sans appel précédent en mémoire
		# (page restée ouverte pendant un redémarrage de LMS, par exemple).
		$title = $lastRun{$client->id} && $lastRun{$client->id}->{title};
	}
	elsif ($client) {
		$title = _scheduleSleep($client);
	}

	# Un seul élément : confirmation et temps restant avant la veille (calculé
	# à l'ouverture, la page est statique).
	my $remaining = $client ? $client->sleepTime - Time::HiRes::time() : 0;
	my $text = !defined $title ? cstring($client, 'PLUGIN_SLEEPENDOFTRACK_NOTHING')
	         : $remaining > 0  ? cstring($client, 'PLUGIN_SLEEPENDOFTRACK_SCHEDULED_IN', $title, _formatDuration($remaining))
	         :                   cstring($client, 'PLUGIN_SLEEPENDOFTRACK_SCHEDULED', $title);

	my @items = ( {
		# Le message lui-même sert de bouton de retour. 'redirect' + nextWindow :
		# Material le traite comme un élément « texte » (isTextItem) qui exécute
		# l'action, affiche son titre en toast et revient à l'écran précédent,
		# sans ouvrir de page.
		name       => $text,
		type       => 'redirect',
		url        => sub { _backFeed($text, @_) },
		nextWindow => 'parent',
	} );

	$callback->({ items => \@items });
}

# Réponse du message-bouton, jamais affichée (Material revient en arrière).
# Deux éléments exprès : avec un seul élément texte, Material l'entoure d'un
# <div> de mise en page et le toast affiche ce HTML brut ; avec plusieurs,
# le toast reprend le titre du bouton tapé, en texte simple. (Une liste vide
# ne marche pas non plus : LMS la remplace par un élément « Vide ».)
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
	my $controller = $client->controller;
	my $duration   = $client->isPlaying ? $controller->playingSongDuration : 0;

	if ( $duration && $duration > 0 ) {
		$title = _currentTitle($client);

		# Commande native : sleep (durée - position courante)
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
