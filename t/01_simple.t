use strict;
use Test::More;

use Redis::Cluster::Fast;

is(Redis::Cluster::Fast::hello(), 'Hello, world!');

done_testing;

