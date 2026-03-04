# Copyright 2014-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package OpenQA::Scheduler::Client;
use Mojo::Base -base, -signatures;

use OpenQA::Client;
use OpenQA::Log 'log_debug';
use OpenQA::Utils 'service_port';

has host => sub { $ENV{OPENQA_SCHEDULER_HOST} };
has client => sub { OpenQA::Client->new(api => shift->host // 'localhost') };
has port => sub { service_port('scheduler') };

my $IS_SCHEDULER_ITSELF;
sub mark_current_process_as_scheduler { $IS_SCHEDULER_ITSELF = 1; }    # no:style:signatures
sub is_current_process_the_scheduler { return $IS_SCHEDULER_ITSELF; }    # no:style:signatures

sub new ($class, @args) {    # no:style:signatures
    die 'creating an OpenQA::Scheduler::Client from the scheduler itself is forbidden'
      if is_current_process_the_scheduler;
    $class->SUPER::new(@args);
}

sub wakeup ($self) {    # no:style:signatures
    return if $self->{wakeup};
    $self->{wakeup}++;
    $self->client->max_connections(0)->request_timeout(5)->get_p($self->_api('wakeup'))
      ->catch(sub { log_debug("Unable to wakeup scheduler: $_[0]. Retry scheduled") })
      ->finally(sub { delete $self->{wakeup} })->wait;
}

sub singleton { state $client ||= __PACKAGE__->new }    # no:style:signatures

sub _api ($self, $method) {    # no:style:signatures
    my ($host, $port) = ($self->host // '127.0.0.1', $self->port);
    return "http://$host:$port/api/$method";
}

1;
