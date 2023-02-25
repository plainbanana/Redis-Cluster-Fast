use strict;
use warnings FATAL => 'all';
use lib './t/lib';
use Test::More;
eval {
    use Test::Valgrind (extra_supps => [ './t/lib/memcheck-extra.supp' ]);
};
plan skip_all => 'Test::Valgrind is required to test your distribution with valgrind' if $@;

use Test::RedisCluster qw/get_startup_nodes/;
use Redis::Cluster::Fast;

my $redis = Redis::Cluster::Fast->new(
    startup_nodes => get_startup_nodes,
    connect_timeout => 0.5,
    command_timeout => 0.5,
    max_retry => 10,
);

$redis->set('valgrind', 123);

done_testing;
