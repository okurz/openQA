#!/usr/bin/env perl

# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use strict;
use warnings;

use Test::Most;
use Test::Mojo;
use Mojo::Server::Daemon;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib", "$FindBin::Bin/../../external/os-autoinst-common/lib";
use OpenQA::Test::Case;

OpenQA::Test::Case->new->init_data(fixtures_glob => '03-users.pl');
my $port = 3000 + int(rand(1000));
my $url = "http://127.0.0.1:$port";

my $pid = fork();
if ($pid == 0) {
    # Child process: run the daemon
    my $daemon = Mojo::Server::Daemon->new(listen => ["http://127.0.0.1:$port"], silent => 1);
    my $app = $daemon->build_app('OpenQA::WebAPI');
    $app->log->level('error');
    $daemon->start;
    Mojo::IOLoop->start;
    exit 0;
}

# Parent process: run the tests
# Give the daemon a moment to start
sleep 2;

# Get a valid key/secret from fixtures (Arther is an admin in 03-users.pl)
my $key = 'ARTHURKEY01';
my $secret = 'EXCALIBUR';

my $script = "$FindBin::Bin/../script/openqa-create-api-key";

subtest 'Success case' => sub {
    my $cmd = "$script --host $url --apikey $key --apisecret $secret";
    my $output = `$cmd`;
    is $?, 0, 'Script exited successfully';
    like $output, qr/\[127\.0\.0\.1:\d+\]/, 'Output contains host section';
    like $output, qr/key = [0-9A-F]{16}/, 'Output contains key';
    like $output, qr/secret = [0-9A-F]{16}/, 'Output contains secret';
};

subtest 'JSON output' => sub {
    my $cmd = "$script --host $url --apikey $key --apisecret $secret --json";
    my $output = `$cmd`;
    is $?, 0, 'Script exited successfully';
    like $output, qr/"id":\d+/, 'JSON contains id';
    like $output, qr/"key":"[0-9A-F]{16}"/, 'JSON contains key';
    like $output, qr/"secret":"[0-9A-F]{16}"/, 'JSON contains secret';
    like $output, qr/"t_expiration":".*"/, 'JSON contains t_expiration';
};

subtest 'Environment variables' => sub {
    local $ENV{OPENQA_API_KEY} = $key;
    local $ENV{OPENQA_API_SECRET} = $secret;
    my $cmd = "$script --host $url --json";
    my $output = `$cmd`;
    is $?, 0, 'Script exited successfully using env vars';
    like $output, qr/"key":"[0-9A-F]{16}"/, 'JSON contains key';
};

subtest 'Failure case' => sub {
    my $cmd = "$script --host $url --apikey INVALID --apisecret INVALID 2>&1";
    my $output = `$cmd`;
    isnt $?, 0, 'Script failed with invalid credentials';
    like $output, qr/Error: .* \(403\)/, 'Error message indicates 403';
};

# Cleanup daemon
kill 'TERM', $pid;
waitpid($pid, 0);

done_testing();
