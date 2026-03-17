#!/usr/bin/env perl
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Test::Most;
use Test::Warnings ':report_warnings';
use FindBin;
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../external/os-autoinst-common/lib";
use OpenQA::Utils
  qw(:DEFAULT random_string random_hex save_base64_png prjdir sharedir archivedir resultdir assetdir imagesdir effective_distri locate_asset find_labels find_flags find_bugref find_bugrefs bugurl url_from_label);
use OpenQA::Test::TimeLimit '10';
use Mojo::File 'path';

subtest 'human_readable_size' => sub {
    is human_readable_size(500), '500 Byte', 'bytes';
    is human_readable_size(3000), '2.9 KiB', 'KiB';
    is human_readable_size(3000 * 1024), '2.9 MiB', 'MiB';
    is human_readable_size(3000 * 1024 * 1024), '2.9 GiB', 'GiB';
    is human_readable_size(-500), '-500 Byte', 'negative bytes';
};

subtest 'change_sec_to_word' => sub {
    is change_sec_to_word(undef), undef, 'undef';
    is change_sec_to_word('abc'), undef, 'invalid';
    is change_sec_to_word(1), '1s', 'seconds';
    is change_sec_to_word(61), '1m 1s', 'minutes and seconds';
    is change_sec_to_word(3661), '1h 1m 1s', 'hours, minutes and seconds';
    is change_sec_to_word(86400 + 3661), '1d 1h 1m 1s', 'days, hours, minutes and seconds';
};

subtest 'any_array_item_contained_by_hash' => sub {
    ok OpenQA::Utils::any_array_item_contained_by_hash([qw(a b)], {a => 1}), 'found';
    ok !OpenQA::Utils::any_array_item_contained_by_hash([qw(a b)], {c => 1}), 'not found';
};

subtest 'random strings' => sub {
    like random_string(8), qr/^\w{8}$/, 'random_string';
    like random_hex(8), qr/^[0-9A-F]{8}$/, 'random_hex';
};

subtest 'git_commit_url' => sub {
    is git_commit_url(undef), '', 'undef';
    is git_commit_url('http://github.com/foo/bar.git'), 'http://github.com/foo/bar/commit/', 'http';
    is git_commit_url('git@github.com:foo/bar.git'), 'https://github.com/foo/bar/commit/', 'ssh';
    is git_commit_url('github.com:foo/bar.git'), '', 'invalid ssh';
};

subtest 'ensure_timestamp_appended' => sub {
    my $today = POSIX::strftime('%Y%m%d', gmtime time);
    is ensure_timestamp_appended('foo'), "foo-$today", 'append';
    is ensure_timestamp_appended('foo-20200101'), "foo-$today", 'replace';
};

subtest 'save_base64_png' => sub {
    my $tempdir = Mojo::File::tempdir;
    is save_base64_png($tempdir, 'test.png',
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=='),
      'test', 'saved';
    ok -f $tempdir->child('test.png'), 'file exists';
    is save_base64_png($tempdir, undef, undef), undef, 'undef args';
};

subtest 'dir functions' => sub {
    ok prjdir(), 'prjdir';
    ok sharedir(), 'sharedir';
    ok archivedir(), 'archivedir';
    ok resultdir(), 'resultdir';
    ok resultdir(1), 'resultdir archived';
    ok assetdir(), 'assetdir';
    ok imagesdir(), 'imagesdir';
};

subtest 'distri and asset functions' => sub {
    is effective_distri({CASEDIR => 'foo', DISTRI => 'bar'}), 'foo', 'effective_distri from casedir';
    is effective_distri({DISTRI => 'bar'}), 'bar', 'effective_distri from distri';
    ok locate_asset('iso', 'nonexistent'), 'locate_asset returns path even if not exists';
};

subtest 'find functions' => sub {
    is_deeply find_labels('label:foo label:bar'), ['foo', 'bar'], 'find_labels';
    is_deeply find_flags('flag:foo flag:bar'), ['foo', 'bar'], 'find_flags';
    is find_bugref('poo#123'), 'poo#123', 'find_bugref';
    is_deeply find_bugrefs('poo#123 gh#456'), ['poo#123', 'gh#456'], 'find_bugrefs';
};

subtest 'bugurl and labels' => sub {
    is bugurl('poo#123'), 'https://progress.opensuse.org/issues/123', 'bugurl';
    is url_from_label('linked:poo#123'), 'https://progress.opensuse.org/issues/123', 'url_from_label';
    is url_from_label('foo'), undef, 'url_from_label invalid';
};

done_testing();
