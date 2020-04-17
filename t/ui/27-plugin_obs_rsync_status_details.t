# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Test::Most;

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../../external/os-autoinst-common/lib";
use Mojo::Base -signatures;
use Test::Warnings;
use OpenQA::Test::TimeLimit '60';
use OpenQA::SeleniumTest;
use OpenQA::Test::ObsRsync 'setup_obs_rsync_test';

my ($t, $tempdir) = setup_obs_rsync_test(fixtures_glob => '01-jobs.pl 03-users.pl');
driver_missing unless my $driver = call_driver();
$driver->find_element_by_class('navbar-brand')->click;
$driver->find_element_by_link_text('Login')->click;

my %params = (
    'Proj1' => ['190703_143010', 'standard', '', '470.1', 99937, 'passed'],
    'Proj2::appliances' => ['no data', 'appliances', '', ''],
    'BatchedProj' => ['191216_150610', 'containers', '', '4704, 4703, 470.2, 469.1'],
    'Batch1' => ['191216_150610', 'containers', 'BatchedProj', '470.2, 469.1'],
);

<<<<<<< HEAD
||||||| parent of 18af4d2cc... WIP -- more aggressive tries to fix flaky, unstable ui tests
sub _wait_for_change ($selector, $break_cb, $refresh_cb = undef) {
    my $text;
    my $limit = int OpenQA::Test::TimeLimit::scale_timeout(10);
    for my $i (0 .. $limit) {

        # sometimes gru is not fast enough, so let's refresh the page and see if that helped
        if ($i > 0) {
            sleep 1;
            note qq{Refreshing page, waiting for "$selector" to change};
            $refresh_cb ? $refresh_cb->() : $driver->refresh;
        }

        wait_for_element(selector => $selector);
        $text = $driver->find_element($selector)->get_text();
        return $text if $break_cb->(local $_ = $text);
    }

    BAIL_OUT qq{Wait limit of $limit seconds exceeded for "$selector", no change: $text};    # uncoverable statement
}

=======
sub _wait_for_change ($selector, $break_cb, $refresh_cb = undef) {
    my $text;
    my $limit = int OpenQA::Test::TimeLimit::scale_timeout(10);
    for my $i (0 .. $limit) {

        # sometimes gru is not fast enough, so let's refresh the page and see if that helped
        if ($i > 0) {
            sleep 1;
            note qq{Refreshing page, waiting for "$selector" to change};
            $refresh_cb ? $refresh_cb->() : $driver->refresh;
        }

        wait_for_element(selector => $selector);
        $text = $driver->find_element($selector)->get_text();
        return $text if $break_cb->(local $_ = $text);
    }

    BAIL_OUT qq{Wait limit of $limit seconds exceeded for "$selector", no change: $text};    # uncoverable statement
}

# the following code is unreliable without relying on a longer timeout in
# the web driver as the timing behaviour of background tasks has not been
# mocked away
enable_timeout;

>>>>>>> 18af4d2cc... WIP -- more aggressive tries to fix flaky, unstable ui tests
foreach my $proj (sort keys %params) {
    my $ident = $proj;
    $ident =~ s/\W//g;    # remove special characters to refer UI, the same way as in template

    my ($dt, $repo, $parent, $builds_text, $test_id, $test_result) = @{$params{$proj}};
    my $projfull = $parent ? "$parent|$proj" : $proj;

    # navigate to page and mock AJAX requests
    $driver->get("/admin/obs_rsync/$parent");
    $driver->execute_script('
        window.skipObsRsyncDelay = true;
        window.ajaxRequests = [];
        $.ajax = function(data) { window.ajaxRequests.push(data); data.success({message: "fake response"}) };
    ');

    # check project name and other fields are displayed properly
    is $driver->find_element("tr#folder_$ident .project")->get_text, $projfull, "$proj name";
    like $driver->find_element("tr#folder_$ident .lastsync")->get_text, qr/$dt/, "$proj last sync";
    like $driver->find_element("tr#folder_$ident .testlink")->get_text, qr/$test_result/, "$proj last test result"
      if $test_result;
    is $driver->find_element("tr#folder_$ident .lastsyncbuilds")->get_text, $builds_text, "$proj sync builds";

    # at start no project fetches builds from obs
<<<<<<< HEAD
    is($driver->find_element("tr#folder_$ident .obsbuilds")->get_text, '', "$proj obs builds empty");
    my $status = $driver->find_element("tr#folder_$ident .dirtystatuscol .dirtystatus")->get_text;
    like $status, qr/dirty/, "$proj dirty status";
    like $status, qr/$repo/, "$proj repo in dirty status ($status)";
    like $status, qr/$repo/, "$proj dirty has repo";

    if ($proj eq 'Batch1') {
        # click on the various buttons within the table
        $driver->find_element("tr#folder_$ident .obsbuildsupdate")->click;
        is $driver->find_element("tr#folder_$ident .obsbuilds")->get_text, 'fake response',
          'builds update response shown';

        $driver->find_element("tr#folder_$ident .lastsyncforget")->click;
||||||| parent of 18af4d2cc... WIP -- more aggressive tries to fix flaky, unstable ui tests
    is($driver->find_element("tr#folder_$ident .obsbuilds")->get_text(), '', "$proj obs builds empty");
    my $status = $driver->find_element("tr#folder_$ident .dirtystatuscol .dirtystatus")->get_text();
    like($status, qr/dirty/, "$proj dirty status");
    like($status, qr/$repo/, "$proj repo in dirty status ($status)");
    like($status, qr/$repo/, "$proj dirty has repo");

    # the following code is unreliable without relying on a longer timeout in
    # the web driver as the timing behaviour of background tasks has not been
    # mocked away
    enable_timeout;

    $builds_text = ($builds_text ? $builds_text : 'No data');
    # now request fetching builds from obs
    $driver->find_element("tr#folder_$ident .obsbuildsupdate")->click();
    my $obsbuilds = _wait_for_change(
        "tr#folder_$ident .obsbuilds",
        sub { $_ eq $builds_text },
        sub { $driver->find_element("tr#folder_$ident .obsbuildsupdate")->click() });
    is($obsbuilds, $builds_text, "$proj obs builds");

    if ($dt ne 'no data') {
        # now we call forget_run_last() and refresh_last_run() and check once again corresponding columns
        $driver->find_element("tr#folder_$ident .lastsyncforget")->click();
=======
    is($driver->find_element("tr#folder_$ident .obsbuilds")->get_text(), '', "$proj obs builds empty");
    my $status = $driver->find_element("tr#folder_$ident .dirtystatuscol .dirtystatus")->get_text();
    like($status, qr/dirty/, "$proj dirty status");
    like($status, qr/$repo/, "$proj repo in dirty status ($status)");
    like($status, qr/$repo/, "$proj dirty has repo");

    $builds_text = ($builds_text ? $builds_text : 'No data');
    # now request fetching builds from obs
    $driver->find_element("tr#folder_$ident .obsbuildsupdate")->click();
    my $obsbuilds = _wait_for_change(
        "tr#folder_$ident .obsbuilds",
        sub { $_ eq $builds_text },
        sub { $driver->find_element("tr#folder_$ident .obsbuildsupdate")->click() });
    is($obsbuilds, $builds_text, "$proj obs builds");

    if ($dt ne 'no data') {
        # now we call forget_run_last() and refresh_last_run() and check once again corresponding columns
        $driver->find_element("tr#folder_$ident .lastsyncforget")->click();
>>>>>>> 18af4d2cc... WIP -- more aggressive tries to fix flaky, unstable ui tests
        $driver->accept_alert;
        is $driver->find_element("tr#folder_$ident .lastsync")->get_text, 'fake response', 'forget response shown';

        $driver->find_element("tr#folder_$ident .dirtystatusupdate")->click;
        is $driver->find_element("tr#folder_$ident .dirtystatuscol .dirtystatus")->get_text, 'fake response',
          'dirty status update response shown';

        my $actual_requests = $driver->execute_script('return window.ajaxRequests;');
        my @expected_requests = (
            {method => 'POST', url => '/admin/obs_rsync/BatchedProj%7CBatch1/obs_builds_text', dataType => 'json'},
            {method => 'GET', url => '/admin/obs_rsync/BatchedProj%7CBatch1/obs_builds_text'},
            {method => 'POST', url => '/admin/obs_rsync/BatchedProj%7CBatch1/run_last', dataType => 'json'},
            {method => 'GET', url => '/admin/obs_rsync/BatchedProj%7CBatch1/run_last'},
            {method => 'POST', url => '/admin/obs_rsync/BatchedProj/dirty_status', dataType => 'json'},
            {method => 'GET', url => '/admin/obs_rsync/BatchedProj/dirty_status'},
        );
        ok delete $_->{success} && delete $_->{error}, 'request has success and error handlers' for @$actual_requests;
        is_deeply $actual_requests, \@expected_requests, 'ajax requests done as expected'
          or diag explain $actual_requests;
    }
    elsif ($proj eq 'Proj1') {
        # follow link to project page and click the sync button
        $driver->find_element_by_link_text($proj)->click;
        my $sync_button = $driver->find_element_by_class('btn-warning');
        is $sync_button->get_attribute('data-posturl'), '/admin/obs_rsync/Proj1/runs', 'post URL for sync as expected';
        $sync_button->click;
        wait_for_ajax msg => 'redirection target loaded';
        is $driver->get_title, 'openQA: OBS synchronization jobs', 'redirected to obs gru jobs page';
    }
}

done_testing();
