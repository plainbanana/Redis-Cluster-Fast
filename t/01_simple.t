use strict;
use warnings FATAL => 'all';
use Test::More;
use lib './t/lib';
use Test::RedisCluster qw/get_startup_nodes/;
use Redis::Cluster::Fast;

my $redis = Redis::Cluster::Fast->new(
    startup_nodes => get_startup_nodes,
);
is $redis->ping, 'PONG';

done_testing;
