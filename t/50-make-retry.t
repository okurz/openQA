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
#use Test::Output;
use IPC::Run qw(run start timeout pump signal);


my ($out, $err);

sub start_once {
   my ($cmd, @args) = @_;
   ($out, $err) = ('', '');
   start $cmd, \undef, \$out, \$err, timeout(4)
}

my @simple_test = qw(make test KEEP_DB=1 TESTS=t/config.t);
my @long_test = qw(make test KEEP_DB=1 TESTS=t/ui/01-list.t);
my $h = start_once \@simple_test;
ok $h->finish, 'simple test with make successful';
like $out, qr/All tests successful/, 'internal test successful';
my @long_test_1s = (@long_test, qw(TIMEOUT_RETRIES=1s));
$h = start_once \@long_test_1s;
ok ! $h->finish, 'test could not succeed within given time' or diag "out: $out\nerr: $err";
note "out: $out\nerr: $err";
is $h->result, 2, 'test exceeding timeout is aborted with timeout failure';
like $err, qr/timeout: sending signal TERM/, 'timeout terminated test';

done_testing;

END { defined $h and kill_kill $h, grace => 1 }
