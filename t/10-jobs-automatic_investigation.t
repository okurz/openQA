#!/usr/bin/env perl

# Copyright (C) 2020 SUSE LLC
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
# with this program; if not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use autodie ':all';
use OpenQA::Test::Case;
use OpenQA::Jobs::Constants;
use OpenQA::Test::Utils qw(redirect_output job_create);
use Test::More;
use Test::Mojo;
use Test::Warnings;

my $schema = OpenQA::Test::Case->new->init_data(skip_fixtures => 1);
my $t      = Test::Mojo->new('OpenQA::WebAPI');
my $rs     = $t->app->schema->resultset('Jobs');

my %settings = (
    DISTRI  => 'Unicorn',
    FLAVOR  => 'pink',
    VERSION => '42',
    BUILD   => '666',
    ISO     => 'whatever.iso',
    MACHINE => "RainbowPC",
    ARCH    => 'x86_64',
    TEST    => 'my_test'
);

my $job_mock     = Test::MockModule->new('OpenQA::Schema::Result::Jobs', no_auto => 1);
my $called;
$job_mock->redefine(trigger_investigation_jobs => sub { $called++ });
my $job = job_create(\%settings);
$job->done(result => OpenQA::Jobs::Constants::FAILED);
is $job->result, OpenQA::Jobs::Constants::FAILED, 'result is set';
is $called, 1, 'investigation jobs triggered';
my $old_job = $job;
$job = $job->auto_duplicate;
$job->done(result => OpenQA::Jobs::Constants::FAILED);
is $called, 1, 'no further investigation jobs for externally duplicated';
$old_job->discard_changes;
$old_job->done(result => OpenQA::Jobs::Constants::FAILED);
is $called, 1, 'no further investigation jobs for repeated done on old';

# TODO continue here with state changes and check if method is called, then
# unmock and continue with internal details

#ok $rs->find({name => 'my_test:retry'}), 'retry test was triggered';

TODO: {
    local $TODO = 'todo';

    fail 'TODO only trigger investigation jobs if first fail after pass';
    fail 'TODO only trigger if mandatory assets available or retrigger parent if available';
    fail 'probably we only want to trigger on "fail", not "incomplete"';
};

done_testing();
