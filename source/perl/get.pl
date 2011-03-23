#!/usr/bin/perl
use warnings;
use strict;
use Net::Twitter::Lite;
use Time::Piece;
use Time::Seconds;
use JSON::XS;
use Cache::Memcached::Fast;

my $config = {
	auth => {
		consumer_key => '',
		consumer_secret => '',
		access_token => '',
		access_token_secret => '',
	},
	time_zone => 9,
	get_lines => 10,
	keep_time => 11,
	memcached => {
		namespace => 'xtw-cache:',
		servers => [qw/127.0.0.1:11211/],
		compress_threshold => 10000,
	},
};

my $json;

my $memd = Cache::Memcached::Fast->new($config->{memcached});
my $obj = $memd->get('obj');

if (defined $obj and $obj->{expires} >= time) {
	$json = $obj->{data};
}
else {
	my $nt = Net::Twitter::Lite->new(%{$config->{auth}});
	my @lines = ();
	foreach my $rs ( @{ $nt->home_timeline({ count => $config->{get_lines} }) } ) {
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

print "Content-Type: application/x-javascript; charset=utf-8\n\n";
print 'callback(',$json,');';
