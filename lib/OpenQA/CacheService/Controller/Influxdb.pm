# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package OpenQA::CacheService::Controller::Influxdb;
use Mojo::Base 'OpenQA::Influxdb';

sub _output_measure {
    my ($url, $key, $states) = @_;
    my $line = "$key,url=$url ";
    $line .= join(',', map { "$_=$states->{$_}i" } sort keys %$states);
    return $line . "\n";
}

1;
