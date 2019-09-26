#!/usr/bin/env perl -w

# Copyright (C) 2014-2019 SUSE Linux Products GmbH
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use OpenQA::Resource::Jobs;
use OpenQA::Resource::Locks;
use OpenQA::Utils;
use OpenQA::Test::Database;
use OpenQA::Test::Utils 'embed_server_for_testing';
use OpenQA::WebSockets::Client;
use Test::More;
use Test::Warnings;
use Test::Output qw(stderr_like);

my $schema = OpenQA::Test::Database->new->create();

embed_server_for_testing(
    server_name => 'OpenQA::WebSockets',
    client      => OpenQA::WebSockets::Client->singleton,
);

sub list_jobs {
    [map { $_->to_hash() } $schema->resultset('Jobs')->all];
}

sub job_get_rs {
    my ($id) = @_;
    return $schema->resultset("Jobs")->find({id => $id});
}

sub job_get {
    my $job = job_get_rs(@_);
    return unless $job;
    return $job->to_hash;
}

ok($schema, "create database") || BAIL_OUT("failed to create database");

my $current_jobs = list_jobs();
ok(@$current_jobs, "have jobs");

my $job1 = job_get(99927);
is($job1->{state}, OpenQA::Jobs::Constants::SCHEDULED, 'trying to duplicate scheduled job');
my $job = job_get_rs(99927)->auto_duplicate;
ok(!defined $job, "duplication rejected");

$job1 = job_get(99926);
is($job1->{state}, OpenQA::Jobs::Constants::DONE, 'trying to duplicate done job');
is_deeply(
    job_get_rs(99926)->cluster_jobs,
    {
        99926 => {
            parallel_parents          => [],
            chained_parents           => [],
            directly_chained_parents  => [],
            parallel_children         => [],
            chained_children          => [],
            directly_chained_children => [],
        },
    },
    '99926 has no siblings'
);
$job = job_get_rs(99926)->auto_duplicate;
ok(defined $job, "duplication works");
isnt($job->id, $job1->{id}, 'clone id is different than original job id');

my $jobs = list_jobs();
is(@$jobs, @$current_jobs + 1, "one more job after duplicating one job");

$current_jobs = $jobs;

my $job2 = job_get($job->id);
is(delete $job2->{origin_id}, delete $job1->{id}, 'original job');
# delete the obviously different fields
delete $job2->{id};
delete $job1->{state};
delete $job2->{state};
delete $job1->{result};
delete $job2->{result};
delete $job1->{t_finished};
delete $job2->{t_finished};
delete $job1->{t_started};
delete $job2->{t_started};
# the name has job id as prefix, delete that too
delete $job1->{settings}->{NAME};
delete $job2->{settings}->{NAME};
# assets are assigned during job grab and not cloned
delete $job1->{assets};
is_deeply($job1, $job2, 'duplicated job equal');

my @ret = OpenQA::Resource::Jobs::job_restart(99926);
is(@ret, 0, "no job ids returned");

$jobs = list_jobs();
is_deeply($jobs, $current_jobs, "jobs unchanged after restarting scheduled job");

subtest 'cancel job' => sub {
    $job1 = job_get(99927);
    job_get_rs(99927)->cancel;
    $job1 = job_get(99927);
    is($job1->{state}, 'cancelled', 'scheduled job cancelled after cancel');
};

subtest 'restart with (directly) chained child' => sub {
    $schema->txn_begin;

    # check state before restarting (dependency is supposed to be chained as defined in the fixtures)
    is_deeply(
        job_get_rs(99937)->cluster_jobs,
        {
            99937 => {
                chained_parents           => [],
                chained_children          => [99938],
                parallel_parents          => [],
                parallel_children         => [],
                directly_chained_parents  => [],
                directly_chained_children => [],
            },
            99938 => {
                chained_parents           => [99937],
                chained_children          => [],
                parallel_parents          => [],
                parallel_children         => [],
                directly_chained_parents  => [],
                directly_chained_children => [],
            },
        },
        '99937 has one chained child'
    );
    my $job_before_restart = job_get(99937);

    # restart the job
    my @ret               = OpenQA::Resource::Jobs::job_restart(99937);
    my $job_after_restart = job_get(99937);

    # check new job and whether clone is tracked
    like($job_after_restart->{clone_id}, qr/\d+/, 'clone is tracked');
    delete $job_before_restart->{clone_id};
    delete $job_after_restart->{clone_id};
    is_deeply($job_before_restart, $job_after_restart, 'done job unchanged after restart');
    is(@ret, 1, 'one job id returned');
    $job_after_restart = job_get($ret[0]->{99937});
    isnt($job_before_restart->{id}, $job_after_restart->{id}, 'new job has a different id');
    is($job_after_restart->{state}, 'scheduled', 'new job is scheduled');

    # roll back and do the same once more for directly chained dependencies (which should not make a difference)
    $schema->txn_rollback;
    $schema->resultset('JobDependencies')->search({parent_job_id => 99937, child_job_id => 99938})
      ->update({dependency => OpenQA::JobDependencies::Constants::DIRECTLY_CHAINED});
    is_deeply(
        job_get_rs(99937)->cluster_jobs,
        {
            99937 => {
                chained_parents           => [],
                chained_children          => [],
                parallel_parents          => [],
                parallel_children         => [],
                directly_chained_parents  => [],
                directly_chained_children => [99938],
            },
            99938 => {
                chained_parents           => [],
                chained_children          => [],
                parallel_parents          => [],
                parallel_children         => [],
                directly_chained_parents  => [99937],
                directly_chained_children => [],
            },
        },
        '99937 has one directly chained child'
    );
    $job_before_restart = job_get(99937);

    # restart the job
    @ret               = OpenQA::Resource::Jobs::job_restart(99937);
    $job_after_restart = job_get(99937);

    # check new job and whether clone is tracked
    like($job_after_restart->{clone_id}, qr/\d+/, 'clone is tracked');
    delete $job_before_restart->{clone_id};
    delete $job_after_restart->{clone_id};
    is_deeply($job_before_restart, $job_after_restart, 'done job unchanged after restart');
    is(@ret, 1, 'one job id returned');
    $job_after_restart = job_get($ret[0]->{99937});
    isnt($job_before_restart->{id}, $job_after_restart->{id}, 'new job has a different id');
    is($job_after_restart->{state}, 'scheduled', 'new job is scheduled');

    $jobs = list_jobs();
    is(@$jobs, @$current_jobs + 2, 'two more job after restarting done job with chained child dependency');
    $current_jobs = $jobs;
};

# check state before restarting job with parallel dependencies (that dependency is set in fixtures)
is_deeply(
    job_get_rs(99963)->cluster_jobs,
    {
        99963 => {
            chained_parents           => [],
            chained_children          => [],
            parallel_parents          => [99961],
            parallel_children         => [],
            directly_chained_parents  => [],
            directly_chained_children => [],
        },
        99961 => {
            chained_parents           => [],
            chained_children          => [],
            parallel_parents          => [],
            parallel_children         => [99963],
            directly_chained_parents  => [],
            directly_chained_children => [],
        }
    },
    '99963 has one parallel parent'
);
OpenQA::Resource::Jobs::job_restart(99963);

$jobs = list_jobs();
is(@$jobs, @$current_jobs + 2, "two more job after restarting running job with parallel dependency");

$job1 = job_get(99963);
job_get_rs(99963)->cancel;
$job2 = job_get(99963);

is_deeply($job1, $job2, "running job unchanged after cancel");

my $job3 = job_get(99938)->{clone_id};
job_get_rs($job3)->done(result => OpenQA::Jobs::Constants::INCOMPLETE);
$job3 = job_get($job3);
my $round1 = job_get_rs($job3->{id})->auto_duplicate({dup_type_auto => 1});
ok(defined $round1, "auto-duplicate works");
$job3 = job_get($round1->id);
# need to change state from scheduled
$job3 = job_get($round1->id);
job_get_rs($job3->{id})->done(result => OpenQA::Jobs::Constants::INCOMPLETE);
$round1->discard_changes;
my $round2 = $round1->auto_duplicate({dup_type_auto => 1});
ok(defined $round2, "auto-duplicate works");
$job3 = job_get($round2->id);
# need to change state from scheduled
job_get_rs($job3->{id})->done(result => OpenQA::Jobs::Constants::INCOMPLETE);
$round2->discard_changes;
my $round3 = $round2->auto_duplicate({dup_type_auto => 1});
ok(defined $round3, "auto-duplicate works");
$job3 = job_get($round3->id);
# need to change state from scheduled
job_get_rs($job3->{id})->done(result => OpenQA::Jobs::Constants::INCOMPLETE);

# need to change state from scheduled
$job3 = job_get($round3->id);
job_get_rs($job3->{id})->done(result => OpenQA::Jobs::Constants::INCOMPLETE);
my $round5 = job_get_rs($round3->id)->auto_duplicate;
ok(defined $round5, "manual-duplicate works");
$job3 = job_get($round5->id);

done_testing;
