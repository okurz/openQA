#!/usr/bin/env perl

# Copyright (C) 2016-2020 SUSE LLC
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

# possible reasons why this tests might fail if you run it locally:
#  * the web UI or any other openQA daemons are still running in the background
#  * a qemu instance is still running (maybe leftover from last failed test
#    execution)

use Mojo::Base -strict;

BEGIN {
    # require the scheduler to be fixed in its actions since tests depends on timing
    $ENV{OPENQA_SCHEDULER_SCHEDULE_TICK_MS}   = 4000;
    $ENV{OPENQA_SCHEDULER_MAX_JOB_ALLOCATION} = 1;

    # ensure the web socket connection won't timeout
    $ENV{MOJO_INACTIVITY_TIMEOUT} = 10 * 60;
}

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use Test::Mojo;
use Test::Output 'stderr_like';
use Test::Warnings;
use autodie ':all';
use IO::Socket::INET;
use POSIX '_exit';
use OpenQA::CacheService::Client;
use Fcntl ':mode';
use DBI;
use Mojo::File 'path';
use Mojo::IOLoop::ReadWriteProcess::Session 'session';
use OpenQA::SeleniumTest;
session->enable;
# optional but very useful
eval 'use Test::More::Color';
eval 'use Test::More::Color "foreground"';

use File::Path qw(make_path remove_tree);
use Module::Load::Conditional 'can_load';
use OpenQA::Test::Utils
  qw(create_websocket_server create_live_view_handler setup_share_dir),
  qw(cache_minion_worker cache_worker_service setup_fullstack_temp_dir),
  qw(stop_service);
use OpenQA::Test::FullstackUtils;

plan skip_all => "set FULLSTACK=1 (be careful)"                                unless $ENV{FULLSTACK};
plan skip_all => 'set TEST_PG to e.g. DBI:Pg:dbname=test" to enable this test' unless $ENV{TEST_PG};

my $workerpid;
my $wspid;
my $livehandlerpid;

# skip if appropriate modules aren't available
unless (check_driver_modules) {
    plan skip_all => $OpenQA::SeleniumTest::drivermissing;
    exit(0);
}

# setup directories
my $tempdir  = setup_fullstack_temp_dir('full-stack.d');
my $sharedir = setup_share_dir($ENV{OPENQA_BASEDIR});

# initialize database, start daemons
my $schema = OpenQA::Test::Database->new->create(skip_fixtures => 1, schema_name => 'public', drop_schema => 1);
ok(Mojolicious::Commands->start_app('OpenQA::WebAPI', 'eval', '1+0'), 'assets are prefetched');
my $mojoport = Mojo::IOLoop::Server->generate_port;
$wspid = create_websocket_server($mojoport + 1, 0, 0);
my $driver       = call_driver(sub { }, {mojoport => $mojoport});
my $connect_args = OpenQA::Test::FullstackUtils::get_connect_args();
$livehandlerpid = create_live_view_handler($mojoport);

my $resultdir = path($ENV{OPENQA_BASEDIR}, 'openqa', 'testresults')->make_path;
ok(-d $resultdir, "resultdir \"$resultdir\" exists");

$driver->title_is("openQA", "on main page");
is($driver->find_element('#user-action a')->get_text(), 'Login', "no one logged in");
$driver->click_element_ok('Login', 'link_text', 'Login clicked');
# we're back on the main page
$driver->title_is("openQA", "back on main page");

# click away the tour
$driver->click_element_ok('dont-notify', 'id', 'Selected to not notify about tour');
$driver->click_element_ok('confirm',     'id', 'Clicked confirm about no tour');

my $JOB_SETUP
  = 'ISO=Core-7.2.iso DISTRI=tinycore ARCH=i386 QEMU=i386 QEMU_NO_KVM=1 '
  . 'FLAVOR=flavor BUILD=1 MACHINE=coolone QEMU_NO_TABLET=1 INTEGRATION_TESTS=1 '
  . 'QEMU_NO_FDC_SET=1 CDMODEL=ide-cd HDDMODEL=ide-drive VERSION=1 TEST=core PUBLISH_HDD_1=core-hdd.qcow2 '
  . 'UEFI_PFLASH_VARS=/usr/share/qemu/ovmf-x86_64.bin';

subtest 'schedule job' => sub {
    OpenQA::Test::FullstackUtils::client_call("jobs post $JOB_SETUP");
    OpenQA::Test::FullstackUtils::verify_one_job_displayed_as_scheduled($driver);
};

my $job_name = 'tinycore-1-flavor-i386-Build1-core@coolone';
$driver->find_element_by_link_text('core@coolone')->click();
$driver->title_is("openQA: $job_name test results", 'scheduled test page');
my $job_page_url = $driver->get_current_url();
like($driver->find_element('#result-row .card-body')->get_text(), qr/State: scheduled/, 'test 1 is scheduled');
javascript_console_has_no_warnings_or_errors;

sub start_worker {
    return fail "Unable to start worker, previous worker with PID '$workerpid' is still running" if defined $workerpid;

    $workerpid = fork();
    if ($workerpid == 0) {
        exec("perl ./script/worker --instance=1 $connect_args --isotovideo=../os-autoinst/isotovideo --verbose");
        die "FAILED TO START WORKER";
    }
    else {
        ok($workerpid, "Worker started as $workerpid");
        OpenQA::Test::FullstackUtils::schedule_one_job;
    }
}

start_worker;
OpenQA::Test::FullstackUtils::wait_for_job_running($driver, 'fail on incomplete');

subtest 'wait until developer console becomes available' => sub {
    # open developer console
    $driver->get('/tests/1/developer/ws-console');
    wait_for_ajax(msg => 'developer console available');

    OpenQA::Test::FullstackUtils::wait_for_developer_console_available($driver);
};

sleep 8;
subtest 'pause at certain test' => sub {
    # load Selenium::Remote::WDKeys module or skip this test if not available
    unless (can_load(modules => {'Selenium::Remote::WDKeys' => undef,})) {
        plan skip_all => 'Install Selenium::Remote::WDKeys to run this test';
        return;
    }

    my $log_textarea  = $driver->find_element('#log');
    my $command_input = $driver->find_element('#msg');

    # send command to pause at shutdown (hopefully the test wasn't so fast it is already in shutdown)
    $command_input->send_keys('{"cmd":"set_pause_at_test","name":"shutdown"}');
    $command_input->send_keys(Selenium::Remote::WDKeys->KEYS->{'enter'});
    OpenQA::Test::FullstackUtils::wait_for_developer_console_contains_log_message(
        $driver,
        qr/\"set_pause_at_test\":\"shutdown\"/,
        'response to set_pause_at_test'
    );

    # wait until the shutdown test is started and hence the test execution paused
    OpenQA::Test::FullstackUtils::wait_for_developer_console_contains_log_message($driver,
        qr/(\"paused\":|\"test_execution_paused\":\".*\")/, 'paused');

    # resume the test execution again
    $command_input->send_keys('{"cmd":"resume_test_execution"}');
    $command_input->send_keys(Selenium::Remote::WDKeys->KEYS->{'enter'});
    OpenQA::Test::FullstackUtils::wait_for_developer_console_contains_log_message($driver,
        qr/\"resume_test_execution\":/, 'resume');
};

$driver->get($job_page_url);
OpenQA::Test::FullstackUtils::wait_for_result_panel($driver, qr/Result: passed/, 'test 1 is passed');

ok(-s path($resultdir, '00000',   "00000001-$job_name")->make_path->child('autoinst-log.txt'), 'log file generated');
ok(-s path($sharedir,  'factory', 'hdd')->make_path->child('core-hdd.qcow2'),                  'image of hdd uploaded');
my $core_hdd_path = path($sharedir, 'factory', 'hdd')->child('core-hdd.qcow2');
my @core_hdd_stat = stat($core_hdd_path);
ok(@core_hdd_stat, 'can stat ' . $core_hdd_path);
is(S_IMODE($core_hdd_stat[2]), 420, 'exported image has correct permissions (420 -> 0644)');

my $post_group_res = OpenQA::Test::FullstackUtils::client_output "job_groups post name='New job group'";
my $group_id       = ($post_group_res =~ qr/{ *id *=> *([0-9]*) *}\n/);
ok($group_id, 'regular post via client script');
OpenQA::Test::FullstackUtils::client_call(
    "jobs/1 put --json-data '{\"group_id\": $group_id}'",
    qr/\Q{ job_id => 1 }\E/,
    'send JSON data via client script'
);
OpenQA::Test::FullstackUtils::client_call('jobs/1', qr/group_id *=> *$group_id/, 'group has been altered correctly');

OpenQA::Test::FullstackUtils::client_call(
    'jobs/1/restart post',
    qr|\Qtest_url => [{ 1 => "/tests/2\E|,
    'client returned new test_url'
);
#]| restore syntax highlighting
$driver->refresh();
like($driver->find_element('#result-row .card-body')->get_text(), qr/Cloned as 2/, 'test 1 is restarted');
$driver->click_element_ok('2', 'link_text', 'clicked link to test 2');

OpenQA::Test::FullstackUtils::schedule_one_job;
OpenQA::Test::FullstackUtils::wait_for_job_running($driver);

stop_worker;

OpenQA::Test::FullstackUtils::wait_for_result_panel($driver, qr/Result: incomplete/, 'test 2 crashed');
like(
    $driver->find_element('#result-row .card-body')->get_text(),
    qr/Cloned as 3/,
    'test 2 is restarted by killing worker'
);

OpenQA::Test::FullstackUtils::client_call("jobs post $JOB_SETUP MACHINE=noassets HDD_1=nihilist_disk.hda");

subtest 'cancel a scheduled job' => sub {
    $driver->click_element_ok('All Tests',    'link_text', 'Clicked All Tests');
    $driver->click_element_ok('core@coolone', 'link_text', 'clicked on 3');

    # it can happen that the test is assigned and needs to wait for the scheduler
    # to detect it as dead before it's moved back to scheduled
    OpenQA::Test::FullstackUtils::wait_for_result_panel(
        $driver,
        qr/State: scheduled/,
        'Test 3 is scheduled',
        undef, 0.2,
    );

    my @cancel_button = $driver->find_elements('cancel_running', 'id');
    $cancel_button[0]->click();
};

$driver->click_element_ok('All Tests',     'link_text', 'Clicked All Tests to go to test 4');
$driver->click_element_ok('core@noassets', 'link_text', 'clicked on 4');
$job_name = 'tinycore-1-flavor-i386-Build1-core@noassets';
$driver->title_is("openQA: $job_name test results", 'scheduled test page');
like($driver->find_element('#result-row .card-body')->get_text(), qr/State: scheduled/, 'test 4 is scheduled');

javascript_console_has_no_warnings_or_errors;
start_worker;

OpenQA::Test::FullstackUtils::wait_for_result_panel($driver, qr/Result: incomplete/, 'Test 4 crashed as expected');

# Slurp the whole file, it's not that big anyways
my $filename = $resultdir . "/00000/00000004-$job_name/autoinst-log.txt";
# give it some time to be created
for (my $i = 0; $i < 5; $i++) {
    last if -s $filename;
    sleep 1;
}
#  The worker is launched with --verbose, so by default in this test the level is always debug
if (!$ENV{MOJO_LOG_LEVEL} || $ENV{MOJO_LOG_LEVEL} =~ /DEBUG|INFO/i) {
    ok(-s $filename, 'Test 4 autoinst-log.txt file created');
    open(my $f, '<', $filename) or die "OPENING $filename: $!\n";
    my $autoinst_log = do { local ($/); <$f> };
    close($f);

    like($autoinst_log, qr/Result: setup failure/, 'Test 4 result correct: setup failure');

    like((split(/\n/, $autoinst_log))[0],  qr/\+\+\+ setup notes \+\+\+/,  'Test 4 correct autoinst setup notes');
    like((split(/\n/, $autoinst_log))[-1], qr/Uploading autoinst-log.txt/, 'Test 4: upload of autoinst-log.txt logged');
}

stop_worker;    # Ensure that the worker can be killed with TERM signal

done_testing;

END {
    turn_down_stack($tempdir);
}
