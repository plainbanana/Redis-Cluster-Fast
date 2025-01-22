package Redis::Cluster::Fast;
use 5.008001;
use strict;
use warnings;
use Carp 'croak';

our $VERSION = "0.093";

use constant {
    DEFAULT_COMMAND_TIMEOUT => 1.0,
    DEFAULT_CONNECT_TIMEOUT => 1.0,
    DEFAULT_CLUSTER_DISCOVERY_RETRY_TIMEOUT => 1.0,
    DEFAULT_MAX_RETRY_COUNT => 5,
    DEBUG_REDIS_CLUSTER_FAST => $ENV{DEBUG_PERL_REDIS_CLUSTER_FAST} ? 1 : 0,
};

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

sub srandom {
    my $seed = shift;
    __PACKAGE__->__srandom($seed);
}

sub new {
    my ($class, %args) = @_;
    my $self = $class->_new;

    $self->__set_debug(DEBUG_REDIS_CLUSTER_FAST);

    croak 'need startup_nodes' unless defined $args{startup_nodes} && @{$args{startup_nodes}};
    if (my $servers = join(',', @{$args{startup_nodes}})) {
        $self->__set_servers($servers);
    }

    my $connect_timeout = $args{connect_timeout};
    $connect_timeout = DEFAULT_CONNECT_TIMEOUT unless defined $connect_timeout;
    $self->__set_connect_timeout($connect_timeout);

    my $command_timeout = $args{command_timeout};
    $command_timeout = DEFAULT_COMMAND_TIMEOUT unless defined $command_timeout;
    $self->__set_command_timeout($command_timeout);

    my $discovery_timeout = $args{cluster_discovery_retry_timeout};
    $discovery_timeout = DEFAULT_CLUSTER_DISCOVERY_RETRY_TIMEOUT unless defined $discovery_timeout;
    $self->__set_cluster_discovery_retry_timeout($discovery_timeout);

    my $max_retry = $args{max_retry_count};
    $max_retry = DEFAULT_MAX_RETRY_COUNT unless defined $max_retry;
    $self->__set_max_retry($max_retry);

    $self->__set_route_use_slots($args{route_use_slots} ? 1 : 0);

    $self->connect();
    return $self;
}

sub wait_one_response {
    my $self = shift;
    my $result = $self->__wait_one_response();
    return undef if $result == -1;
    return $result;
}

sub wait_all_responses {
    my $self = shift;
    my $result = $self->__wait_all_responses();
    return undef if $result == -1;
    return $result;
}

sub disconnect {
    my $self = shift;
    my $error = $self->__disconnect();
    croak $error if $error;
}

sub connect {
    my $self = shift;
    my $error = $self->__connect();
    croak $error if $error;
    $error = $self->__wait_until_event_ready();
    croak $error if $error;
}

### Deal with common, general case, Redis commands
our $AUTOLOAD;

sub AUTOLOAD {
    my $command = $AUTOLOAD;
    $command =~ s/.*://;
    my @command = split /_/, $command;

    my $method = sub {
        my $self = shift;
        my @arguments = @_;
        for my $index (0 .. $#arguments) {
            next if ref $arguments[$index] eq 'CODE';

            utf8::downgrade($arguments[$index], 1)
                or croak 'command sent is not an octet sequence in the native encoding (Latin-1).';
        }

        my ($reply, $error) = $self->__std_cmd(@command, @arguments);
        croak "[$command] $error" if defined $error;
        if (wantarray) {
            my $type = ref $reply;
            if ($type eq 'ARRAY') {
                return @$reply;
            } elsif ($type eq 'HASH') {
                return %$reply;
            }
        }
        return $reply;
    };

    # Save this method for future calls
    no strict 'refs';
    *$AUTOLOAD = $method;

    goto $method;
}

1;
__END__

=encoding utf-8

=head1 NAME

Redis::Cluster::Fast - A fast perl binding for Redis Cluster

=head1 SYNOPSIS

    use Redis::Cluster::Fast;

    Redis::Cluster::Fast::srandom(100);

    my $redis = Redis::Cluster::Fast->new(
        startup_nodes => [
            'localhost:9000',
            'localhost:9001',
            'localhost:9002',
            'localhost:9003',
            'localhost:9004',
            'localhost:9005',
        ],
        connect_timeout => 0.05,
        command_timeout => 0.05,
        max_retry_count => 10,
    );

    $redis->set('test', 123);

    # '123'
    my $str = $redis->get('test');

    $redis->mset('{my}foo', 'hoge', '{my}bar', 'fuga');

    # get as array-ref
    my $array_ref = $redis->mget('{my}foo', '{my}bar');
    # get as array
    my @array = $redis->mget('{my}foo', '{my}bar');

    $redis->hset('mymap', 'field1', 'Hello');
    $redis->hset('mymap', 'field2', 'ByeBye');

    # get as hash-ref
    my $hash_ref = { $redis->hgetall('mymap') };
    # get as hash
    my %hash = $redis->hgetall('mymap');

=head1 DESCRIPTION

Redis::Cluster::Fast is like L<Redis::Fast|https://github.com/shogo82148/Redis-Fast> but support Redis Cluster by L<hiredis-cluster|https://github.com/Nordix/hiredis-cluster>.

To build and use this module you need libevent-dev >= 2.x is installed on your system.

Recommend Redis 6 or higher.

Since Redis 6, it supports new version of Redis serialization protocol, L<RESP3|https://github.com/antirez/RESP3/blob/master/spec.md>.
This client start to connect using RESP2 and currently it has no option to upgrade all connections to RESP3.

=head2 MICROBENCHMARK

Simple microbenchmark comparing PP and XS.
The benchmark script used can be found under examples directory.

    Redis::Cluster::Fast is 0.084
    Redis::ClusterRider is 0.26
    ### mset ###
                            Rate  Redis::ClusterRider Redis::Cluster::Fast
    Redis::ClusterRider  13245/s                   --                 -34%
    Redis::Cluster::Fast 20080/s                  52%                   --
    ### mget ###
                            Rate  Redis::ClusterRider Redis::Cluster::Fast
    Redis::ClusterRider  14641/s                   --                 -40%
    Redis::Cluster::Fast 24510/s                  67%                   --
    ### incr ###
                            Rate  Redis::ClusterRider Redis::Cluster::Fast
    Redis::ClusterRider  18367/s                   --                 -44%
    Redis::Cluster::Fast 32879/s                  79%                   --
    ### new and ping ###
                           Rate  Redis::ClusterRider Redis::Cluster::Fast
    Redis::ClusterRider   146/s                   --                 -96%
    Redis::Cluster::Fast 3941/s                2598%                   --

=head1 METHODS

=head2 srandom($seed)

hiredis-cluster uses L<random()|https://linux.die.net/man/3/random> to select a node used for requesting cluster topology.

C<$seed> is expected to be an unsigned integer value,
and is used as an argument for L<srandom()|https://linux.die.net/man/3/srandom>.

These are different implementations of Perl's rand and srand.
In this client, Perl's Drand01 is also used to determine the destination node for executing a command that is not a cluster command.

=head2 new(%args)

Following arguments are available.

=head3 startup_nodes

Specifies the list of Redis Cluster nodes.

=head3 connect_timeout

A fractional seconds. (default: 1.0)

Connection timeout to connect to a Redis node.

=head3 command_timeout

A fractional seconds. (default: 1.0)

Specifies the timeout value for each read/write event to execute a Redis Command.

=head3 max_retry_count

A integer value. (default: 5)

The client will retry calling the Redis Command only if it successfully get one of the following error responses.
MOVED, ASK, TRYAGAIN, CLUSTERDOWN.

C<max_retry_count> is the maximum number of retries and must be 1 or above.

=head3 cluster_discovery_retry_timeout

A fractional value. (default: 1.0)

Specify the number of seconds to treat a series of cluster topology requests as timed out without retrying the operation.
At least one operation will be attempted, and the time taken for the initial operation will also be measured.

=head3 route_use_slots

A value used as boolean. (default: undef)

The client will call CLUSTER SLOTS instead of CLUSTER NODES.

=head2 <command>(@args)

To run a Redis command with arguments.

The command can also be expressed by concatenating the subcommands with underscores.

    e.g. cluster_info

It does not support (Sharded) Pub/Sub family of commands and should not be run.

It is recommended to issue C<disconnect> in advance just to be safe when executing fork() after issuing the command.

=head2 <command>(@args, sub {})

To run a Redis command in pipeline with arguments and a callback.

The command can also be expressed by concatenating the subcommands with underscores.

Commands issued to the same node are sent and received in pipeline mode.
In pipeline mode, commands are not sent to Redis until C<wait_one_response> or C<wait_all_responses> is issued.

The callback is executed with two arguments.
The first is the result of the command, and the second is the error message.
C<$result> will be a scalar value or an array reference, and C<$error> will be an undefined value if no errors occur.
Also, C<$error> may contain an error returned from Redis or an error that occurred on the client (e.g. Timeout).

You cannot call any client methods inside the callback.

After issuing a command in pipeline mode,
do not execute fork() without issuing C<disconnect> if all callbacks are not executed completely.

    $redis->get('test', sub {
        my ($result, $error) = @_;
        # some operations...
    });

=head2 wait_one_response()

If there are any unexcuted callbacks, it will block until at least one is executed.
The return value can be either 1 for success, 0 for no callbacks remained, or undef for other errors.

=head2 wait_all_responses()

If there are any unexcuted callbacks, it will block until all of them are executed.
The return value can be either 1 for success, 0 for no callbacks remained, or undef for other errors.

=head2 disconnect()

Normally you should not call C<disconnect> manually.
If you want to call fork(), C<disconnect> should be call before fork().

It will be blocked until all unexecuted commands are executed, and then it will disconnect.

=head2 connect()

Normally you should not call C<connect> manually.
If you want to call fork(), C<connect> should be call after fork().

=head1 LICENSE

Copyright (C) plainbanana.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

plainbanana E<lt>plainbanana@mustardon.tokyoE<gt>

=head1 SEE ALSO

=over 4

=item L<Redis::ClusterRider|https://github.com/iph0/Redis-ClusterRider>

=item L<Redis::Fast|https://github.com/shogo82148/Redis-Fast>

=back

=cut

