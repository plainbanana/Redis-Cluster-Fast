use strict;
use warnings FATAL => 'all';
use Test::More;
use lib './t/lib';
use Test::RedisCluster qw/get_startup_nodes/;

use Redis::Cluster::Fast;
use Test::LeakTrace;

no_leaks_ok {
    my $redis = Redis::Cluster::Fast->new(
        startup_nodes => get_startup_nodes,
    );
    $redis->ping;
    $redis->CLUSTER_INFO();
    $redis->eval(
        "return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}",
        2, '{key}1', '{key}2', 'first', 'second');
    $redis->mset('{my}hoge', 'test', '{my}fuga', 'test2');
    $redis->mget('{my}hoge', '{my}fuga');
} "No Memory leak";

done_testing;
