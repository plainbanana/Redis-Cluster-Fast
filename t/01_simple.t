use strict;
use warnings FATAL => 'all';
use Test::More;
use lib './t/lib';
use Test::RedisCluster qw/get_startup_nodes/;

use Redis::Cluster::Fast;
use Test::LeakTrace;

subtest "basic tests" => sub {
    my $redis = Redis::Cluster::Fast->new(
        startup_nodes => get_startup_nodes,
    );
    is $redis->ping, 'PONG';

    like $redis->CLUSTER_INFO(), qr/^cluster_state:ok/;

    my $res = $redis->eval(
        "return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}",
        2, '{key}1', '{key}2', 'first', 'second');
    is_deeply $res, [ '{key}1', '{key}2', 'first', 'second' ];

    is $redis->mset('{my}hoge', 'test', '{my}fuga', 'test2'), 'OK';

    my @res = $redis->mget('{my}hoge', '{my}fuga');
    is_deeply \@res, [ 'test', 'test2' ];
};

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
