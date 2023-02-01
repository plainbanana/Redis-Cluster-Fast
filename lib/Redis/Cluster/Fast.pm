package Redis::Cluster::Fast;
use 5.008001;
use strict;
use warnings;
use Carp qw/croak confess/;

our $VERSION = "0.01";

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

sub new {
    my ($class, %args) = @_;
    my $self = $class->_new;

    $self->__set_debug($args{debug} ? 1 : 0);

    croak 'need startup_nodes' unless defined $args{startup_nodes};
    if (my $servers = join(',', @{$args{startup_nodes}})) {
        $self->__set_servers($servers);
    }

    my $connect_timeout = $args{connect_timeout};
    $connect_timeout = 10 unless $connect_timeout;
    $self->__set_connect_timeout($connect_timeout);

    my $command_timeout = $args{command_timeout};
    $command_timeout = 10 unless $command_timeout;
    $self->__set_command_timeout($command_timeout);

    my $max_retry = $args{max_retry_count};
    $max_retry = 10 unless $max_retry;
    $self->__set_max_retry($max_retry);

    croak "failed to connect redis servers"
        if $self->connect();
    return $self;
}

### Deal with common, general case, Redis commands
our $AUTOLOAD;

sub AUTOLOAD {
    my $command = $AUTOLOAD;
    $command =~ s/.*://;
    my @command = split /_/, uc $command;

    my $method = sub {
        my $self = shift;
        my ($reply, $error) = $self->__std_cmd(@command, @_);
        confess "[$command] $error" if defined $error;
        return (wantarray && ref $reply eq 'ARRAY') ? @$reply : $reply;
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
        max_retry => 10,
    );

    # 'OK'
    my $res = $redis->set('test', 123);
    # '123'
    my $str = $redis->get('test');
    # 'OK'
    $res = $redis->mset('{my}foo', 'hoge', '{my}bar', 'fuga');
    # get as array
    my @array = $redis->mget('{my}foo', '{my}bar');
    # get as array-ref
    my $array_ref = $redis->mget('{my}foo', '{my}bar');

=head1 DESCRIPTION

Redis::Cluster::Fast is like L<Redis::Fast|https://github.com/shogo82148/Redis-Fast> but support Redis Cluster by L<hiredis-cluster|https://github.com/Nordix/hiredis-cluster>.

Require Redis 6 or higher to support L<RESP3|https://github.com/antirez/RESP3/blob/master/spec.md>.

=head1 METHODS

=head2 new(%args)

Following arguments are available.

=over 1

=item startup_nodes

Specifies the list of Redis Cluster nodes.

=item connect_timeout

A fractional seconds. (default: 10)

Connection timeout to connect to a Redis node.

=item command_timeout

A fractional seconds. (default: 10)

Redis Command execution timeout.

=item max_retry

A integer value. (default: 10)

=back

=head2 <command>(@args)

To run Redis command with arguments.

=head1 LICENSE

Copyright (C) plainbanana.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

plainbanana E<lt>plainbanana@mustardon.tokyoE<gt>

=cut

