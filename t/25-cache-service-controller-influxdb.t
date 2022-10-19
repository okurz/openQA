#!/usr/bin/env perl
# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Test::Most;
use Mojo::Base -strict, -signatures;
use FindBin;
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../external/os-autoinst-common/lib";
use Test::Warnings ':report_warnings';
use Test::Mojo;
use OpenQA::CacheService::Controller::Influxdb;

subtest 'Minion monitoring with InfluxDB' => sub {
    my $app = OpenQA::CacheService->new;
    my $rate = $app->cache->metrics->{download_rate};
    ok $rate > 0, 'download rate is higher than 0 bytes per second';

    my $url = $cache_client->url('/influxdb/minion');
    my $ua = $cache_client->ua;
    my $res = $ua->get($url)->result;
    is $res->body, <<"EOF", 'three workers still running';
openqa_minion_jobs,url=http://127.0.0.1:9530 active=0i,delayed=0i,failed=0i,inactive=0i
openqa_minion_workers,url=http://127.0.0.1:9530 active=0i,inactive=2i,registered=2i
openqa_download_rate,url=http://127.0.0.1:9530 bytes=${rate}i
EOF

    my $minion = $app->minion;
    my $worker = $minion->repair->worker->register;
    $res = $ua->get($url)->result;
    is $res->body, <<"EOF", 'four workers running now';
openqa_minion_jobs,url=http://127.0.0.1:9530 active=0i,delayed=0i,failed=0i,inactive=0i
openqa_minion_workers,url=http://127.0.0.1:9530 active=0i,inactive=3i,registered=3i
openqa_download_rate,url=http://127.0.0.1:9530 bytes=${rate}i
EOF

    $minion->add_task(test => sub { });
    my $job_id = $minion->enqueue('test');
    my $job_id2 = $minion->enqueue('test');
    my $job = $worker->dequeue(0);
    $res = $ua->get($url)->result;
    is $res->body, <<"EOF", 'two jobs';
openqa_minion_jobs,url=http://127.0.0.1:9530 active=1i,delayed=0i,failed=0i,inactive=1i
openqa_minion_workers,url=http://127.0.0.1:9530 active=1i,inactive=2i,registered=3i
openqa_download_rate,url=http://127.0.0.1:9530 bytes=${rate}i
EOF

    $job->fail('test');
    $res = $ua->get($url)->result;
    is $res->body, <<"EOF", 'one job failed';
openqa_minion_jobs,url=http://127.0.0.1:9530 active=0i,delayed=0i,failed=1i,inactive=1i
openqa_minion_workers,url=http://127.0.0.1:9530 active=0i,inactive=3i,registered=3i
openqa_download_rate,url=http://127.0.0.1:9530 bytes=${rate}i
EOF

    $job->retry({delay => ONE_HOUR});
    $res = $ua->get($url)->result;
    is $res->body, <<"EOF", 'job is being retried';
openqa_minion_jobs,url=http://127.0.0.1:9530 active=0i,delayed=1i,failed=0i,inactive=2i
openqa_minion_workers,url=http://127.0.0.1:9530 active=0i,inactive=3i,registered=3i
openqa_download_rate,url=http://127.0.0.1:9530 bytes=${rate}i
EOF
};
done_testing;
