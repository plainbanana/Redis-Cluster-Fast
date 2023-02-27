use strict;
use warnings FATAL => 'all';

use lib "./_build/lib";
use lib "./blib/arch";
use lib "./blib/lib";
use lib "./t/lib";

use Benchmark;
use Redis::Cluster::Fast;
use Redis::ClusterRider;
use Test::More; # for Test::RedisCluster
use Test::RedisCluster qw/get_startup_nodes/;
my $nodes = get_startup_nodes;

print "Redis::Cluster::Fast is " . $Redis::Cluster::Fast::VERSION . "\n";
print "Redis::ClusterRider is " . $Redis::ClusterRider::VERSION . "\n";

my $xs = Redis::Cluster::Fast->new(
    startup_nodes => $nodes,
);

my $pp = Redis::ClusterRider->new(
    startup_nodes => $nodes,
);

my $cc = 0;
my $dd = 0;

my $loop = 100000;
print "### mset ###\n";
Benchmark::cmpthese($loop, {
    "Redis::ClusterRider" => sub {
        $cc++;
        $pp->mset("{pp$cc}atest", $cc, "{pp$cc}btest", $cc, "{pp$cc}ctest", $cc);
    },
    "Redis::Cluster::Fast" => sub {
        $dd++;
        $xs->mset("{xs$dd}atest", $dd, "{xs$dd}btest", $dd, "{xs$dd}ctest", $dd);
    },
});

$cc = 0;
$dd = 0;

print "### mget ###\n";
Benchmark::cmpthese($loop, {
    "Redis::ClusterRider" => sub {
        $cc++;
        $pp->mget("{pp$cc}atest", "{pp$cc}btest", "{pp$cc}ctest");
    },
    "Redis::Cluster::Fast" => sub {
        $dd++;
        $xs->mget("{xs$dd}atest", "{xs$dd}btest", "{xs$dd}ctest");
    },
});

print "### incr ###\n";
Benchmark::cmpthese(-2, {
    "Redis::ClusterRider" => sub {
        $pp->incr("incr_1");
    },
    "Redis::Cluster::Fast" => sub {
        $xs->incr("incr_2");
    },
});

print "### new ###\n";
Benchmark::cmpthese(-2, {
    "Redis::ClusterRider" => sub {
        my $tmp = Redis::ClusterRider->new(
            startup_nodes => $nodes,
        );
        $tmp->ping;
    },
    "Redis::Cluster::Fast" => sub {
        my $tmp = Redis::Cluster::Fast->new(
            startup_nodes => $nodes,
        );
        $tmp->ping;
    },
});

is 1, 1;
done_testing;
__END__
% perl ./examples/benchmark-simple.pl
Redis::Fast is 0.082
Redis::ClusterRider is 0.26
### mset ###
                        Rate  Redis::ClusterRider Redis::Cluster::Fast
Redis::ClusterRider  13477/s                   --                 -26%
Redis::Cluster::Fast 18182/s                  35%                   --
### mget ###
                        Rate  Redis::ClusterRider Redis::Cluster::Fast
Redis::ClusterRider  14347/s                   --                 -40%
Redis::Cluster::Fast 23923/s                  67%                   --
### incr ###
                        Rate  Redis::ClusterRider Redis::Cluster::Fast
Redis::ClusterRider  16654/s                   --                 -51%
Redis::Cluster::Fast 34037/s                 104%                   --
### new ###
                       Rate  Redis::ClusterRider Redis::Cluster::Fast
Redis::ClusterRider   157/s                   --                 -96%
Redis::Cluster::Fast 3801/s                2328%                   --
ok 1
1..1
