# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Test::Most;
# We need :no_end_test here because otherwise it would output a no warnings
# test for each of the modules, but with the same test number
use Test::Warnings qw(:no_end_test :report_warnings);
use Test::Compile;
use File::Which;
use FindBin;
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../external/os-autoinst-common/lib";
use OpenQA::Test::TimeLimit '400';

use Test::Strict;
use Test2::IPC;
use Parallel::ForkManager;

my $SKIP = [
    # skip test module which would require test API from os-autoinst to be present
    't/data/openqa/share/tests/opensuse/tests/installation/installer_timezone.pm',
    # Skip data files which are supposed to resemble generated output which has no 'use' statements
    't/data/40-templates.pl',
    't/data/40-templates-jgs.pl',
    't/data/40-templates-more.pl',
    't/data/openqa-trigger-from-obs/Proj2::appliances/.api_package',
    't/data/openqa-trigger-from-obs/Proj2::appliances/.dirty_status',
    't/data/openqa-trigger-from-obs/Proj3::standard/empty.txt',
];
my @files = Test::Strict::_all_perl_files(qw(lib script t));

my $workers = 8;
if ($ENV{HARNESS_OPTIONS} && $ENV{HARNESS_OPTIONS} =~ /j(\d+)/) {
    $workers = $1;
}

my $pm = Parallel::ForkManager->new($workers);

for my $file (@files) {
    $pm->start and next;

    syntax_ok($file) if $Test::Strict::TEST_SYNTAX;
    strict_ok($file) if $Test::Strict::TEST_STRICT;
    warnings_ok($file) if $Test::Strict::TEST_WARNINGS;

    $pm->finish;
}

$pm->wait_all_children;
done_testing();
