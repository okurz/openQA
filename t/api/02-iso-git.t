#! /usr/bin/perl

# Copyright (C) 2014-2020 SUSE LLC
# Copyright (C) 2016 Red Hat
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

use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
#use Test::More;
use Test::Most;
use Test::Mojo;
use Test::Warnings;
use OpenQA::Test::Case;
use OpenQA::Client;

#die_on_fail;

OpenQA::Test::Case->new->init_data;
my $t = Test::Mojo->new('OpenQA::WebAPI');
my $app = $t->app;
my @client_config = (apikey => 'PERCIVALKEY02', apisecret => 'PERCIVALSECRET02');
$t->ua(OpenQA::Client->new(@client_config)->ioloop(Mojo::IOLoop->singleton));
$t->app($app);

my $schema = $t->app->schema;
my $job_templates = $schema->resultset('JobTemplates');
my $jobs = $schema->resultset('Jobs');

sub schedule_iso {
    my ($args, $status, $query_params) = @_;
    $status //= 200;

    my $url = Mojo::URL->new('/api/v1/isos');
    $url->query($query_params);

    $t->post_ok($url, form => $args)->status_is($status);
    return $t->tx->res;
}

my $iso = 'openSUSE-13.1-DVD-i586-Build0091-Media.iso';
# TODO create git repo in temp dir
my $distri_url = 'file:///path/to/temp/foo.git';
my %iso = (ISO => $iso, DISTRI_URL => $distri_url, VERSION => '13.1', FLAVOR => 'DVD', ARCH => 'i586', BUILD => '0091');

subtest 'job templates defined dynamically from VCS checkout' => sub {
    #TODO: {
    #    local $TODO = 'not implemented';
    #    my $res = schedule_iso({%iso});
    #    is($res->json->{count}, 2, 'Amount of jobs scheduled as defined in the evaluated schedule');
    #    is_deeply($res->json->{failed_job_info}, [], 'no failed jobs');
    #    is($jobs->find($res->json->{ids}->[0])->settings_hash->{DISTRI}, 'foo', 'distri computed from URL');
    #    $res = schedule_iso({%iso, DISTRI => 'my_distri'});
    #    is_deeply($res->json->{failed_job_info}, [], 'no failed jobs for custom distri name');
    #    is($jobs->find($res->json->{ids}->[0])->settings_hash->{DISTRI}, 'my_distri', 'distri customized');
    #};
    my $res = schedule_iso({%iso, DISTRI_URL => 'invalid://unknown/protocol'}, 400);
    is_deeply($res, {}) or diag explain $res;
    like($res->json->{error}, qr/Error on distri handling/, 'Error trying to checkout from unknown git protocol');
};

subtest 'async flag is unaffected by remote distri parameter' => sub {
    my $res = schedule_iso(\%iso, 200, {async => 1});
};

done_testing();
