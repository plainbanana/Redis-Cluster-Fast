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

Redis::Cluster::Fast - It's new $module

=head1 SYNOPSIS

    use Redis::Cluster::Fast;

=head1 DESCRIPTION

Redis::Cluster::Fast is ...

=head1 LICENSE

Copyright (C) plainbanana.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

plainbanana E<lt>plainbanana@mustardon.tokyoE<gt>

=cut

