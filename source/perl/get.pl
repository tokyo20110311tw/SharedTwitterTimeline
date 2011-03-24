#!/usr/bin/perl
use warnings;
use strict;
use Net::Twitter::Lite;
use Time::Piece;
use Time::Seconds;
use JSON::XS;
use Cache::Memcached::Fast;

our $config;
our $memd;

BEGIN {
	$config = {
		auth => {
			consumer_key => '',
			consumer_secret => '',
			access_token => '',
			access_token_secret => '',
		},
		time_zone => 9,
		get_lines => 10,
		keep_time => 13,
		memcached => {
			namespace => 'xtw-cache:',
			servers => [qw/127.0.0.1:11211/],
			compress_threshold => 10000,
		},
	};
	$memd = Cache::Memcached::Fast->new($config->{memcached});
	$memd->set('lock',0) unless (defined $memd->get('lock'));
}

my $json;
my $obj = $memd->get('obj');

if ($memd->get('lock') or defined $obj and $obj->{expires} >= time) {
	$json = $obj->{data};
}
else {
	$memd->set('lock',1);
	my $timeline = eval {
		Net::Twitter::Lite->new(%{$config->{auth}})->home_timeline({count => $config->{get_lines}});
	};
	if ($@) {
		$json = $obj->{data};
		warn "$@\n";
	}
	else {
		my @lines = ();
		foreach my $rs (@$timeline) {
			my $t = Time::Piece->strptime($rs->{created_at}, "%a %b %d %H:%M:%S %z %Y");
			$t += ONE_HOUR * $config->{time_zone};
			push @lines, {
				time => $t->hms,
				user => $rs->{user}{name},
				text => $rs->{text},
			};
		}
		$json = JSON::XS->new->utf8->encode(\@lines);

		my $expires = time + $config->{keep_time};
		$memd->set('obj',{ expires => $expires, data => $json });
	}
	$memd->set('lock',0);
}

print "Content-Type: application/x-javascript; charset=utf-8\n\n";
print 'callback(',$json,');';
