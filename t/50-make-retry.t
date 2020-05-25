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

use Test::Most;
use Test::Warnings;
use FileHandle;
use IPC::Run qw(run start timeout pump signal);

# Ensure there is output from prove calls showing the status on test
# executions as soon as test modules start
STDOUT->autoflush(1);
STDERR->autoflush(1);

my ($out, $err);

sub start_once {
   my ($cmd, %args) = @_;
   ($out, $err) = ('', '');
   $args{timeout} //= 4;
   start $cmd, \undef, \$out, \$err, timeout($args{timeout})
}

ok run(qw(tools/retry true)), 'tools/retry can be called with success';
#ok run(qw(make help)), 'make can be called with success';
my @simple_test = qw(make test KEEP_DB=1 TESTS=t/config.t);
my $h = start_once \@simple_test;
ok $h->finish, 'simple test with make successful';
like $out, qr/All tests successful/, 'internal test successful';
# if I remove "unbuffer" then this test is hard aborted as soon as
# long_test_1s is aborted on timeout. If I keep it then unbuffer is left
# around as a zombie process when I signal long test later.
my @long_test = qw(unbuffer make test KEEP_DB=1 TESTS=t/ui/01-list.t);
my @long_test_1s = (@long_test, qw(TIMEOUT_RETRIES=1s));
$h = start_once \@long_test_1s;
ok $h, 'long test started';
ok ! $h->finish, 'test could not succeed within given time' or diag "out: $out\nerr: $err";
note "out: $out\nerr: $err";
is $h->result, 2, 'test exceeding timeout is aborted with timeout failure';
# old variant using GNU "timeout" command which has problems to be aborted
# with Ctrl-C
like $out, qr/timeout: sending signal TERM/, 'timeout terminated test';
#like $out, qr/Timed out/, 'timeout terminated test';
note "ps: " . qx{ps Tf | tail -n 10};
#$h = start_once \@long_test, timeout => 10;
# TODO check first if the low-level tools/retry call can be aborted with
# ctrl-c
my @long_test_low_level = qw(setsid unbuffer tools/retry prove -l t/ui/01-list.t);
$h = start_once \@long_test_low_level;
#$h = start_once \@long_test;
# TODO check for "unbuffer" again at the right location
ok $h, 'started long test to abort it with signal later';
pump $h until $out =~ qr{t/ui/01-list.t \.\.};
note "ps: " . qx{ps Tf -o '%p %P %r %y %x %a'};
note "out: $out\nerr: $err";
pass 'long test has started t/ui/01-list.t, simulating ctrl-C on test run';
$SIG{INT} = sub { diag "50-make-retry.t: Found INT" };
$h->signal('INT');
#ok signal($h, 'INT'), 'simulating ctrl-C on test run';
#ok signal($h, 'QUIT'), 'QUIT';
#ok signal($h, 'HUP'), 'HUP';
#ok signal($h, 'TERM'), 'TERM';
#ok signal($h, 'KILL'), 'KILL';
note "ps: " . qx{ps Tf -o '%p %P %r %y %x %a'};
ok ! $h->finish, 'test was aborted due to simulated ctrl-c';
#is $h->result, 2, 'test aborted with corresponding exit code';
is $h->full_result, 2, 'test aborted with corresponding exit code';
#is_deeply @{$h->full_results}, [2], 'test aborted with corresponding exit code';
#note "result/results/full_result/full_results: " . join('/', $h->result, $h->results, $h->full_result, $h->full_results);
$h = start_once \@long_test;
ok $h, 'started long test with make to abort it with signal later';
pump $h until $out =~ qr{t/ui/01-list.t \.\.};
note "ps after start: " . qx{ps Tf -o '%p %P %r %y %x %a'};
note "pgrep: after start " . qx{pgrep -f -a perl};
note "out: $out\nerr: $err";
pass 'long test with make has started t/ui/01-list.t, simulating ctrl-C on test run';
$h->signal('INT');
# just sending INT to the parent process is not the same as on terminal, we
# need to simulate an interactive bash session behaviour by sending INT to all
# processes in the process group
#kill '-INT', $h->{KIDS}->[0]->{PID};
# TODO there seem to be no processes left in tree but pgrep still reports left
# overs, I need to find the relation between left-over processes the tree.
# maybe iterate over children as well and crosscheck behaviour in interactive
# bash
kill '-INT', $$;
note "ps after int: " . qx{ps Tf -o '%p %P %r %y %x %a'};
note "pgrep: " . qx{pgrep -f -a perl};
note 'before finish, pumping';
pump_nb $h;
note 'before finish, cleaning up potential defunct children that would block finish';
$h->reap_nb;
note "ps after reap: " . qx{ps Tf -o '%p %P %r %y %x %a'};
note "pgrep after reap: " . qx{pgrep -f -a perl};
$h->kill_kill(grace => 1);
note "result/results/full_result/full_results: " . join('/', $h->result, $h->results, $h->full_result, $h->full_results);
#ok ! $h->finish, 'test with make was aborted due to simulated ctrl-c';
#is $h->result, 2, 'test with make aborted with corresponding exit code';
is $h->full_result, 2, 'test with make aborted with corresponding exit code';

done_testing;

END {
note "ps: " . qx{ps Tf -o '%p %P %r %y %x %a' | tail -n 10};
    
    defined $h and kill_kill $h, grace => 1 }
