# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package OpenQA::Assets;
use Mojo::Base -strict, -signatures;

# This file contains helpers to setup handling of assets of the web UI. The list function is used at install-time.

use Mojolicious;
use Mojo::File qw(path);
use Mojo::Home;
use OpenQA::Plugin::Vite;
use YAML::PP qw(LoadFile);
use Feature::Compat::Try;

use constant ASSET_PACK_VERSION_NO_RETRY => 2.13;

sub setup ($server) {
    # setup Vite plugin for asset management
    $server->plugin('OpenQA::Plugin::Vite');
}

sub _path ($url) { path('assets', ref $url eq 'Mojo::URL' ? $url->path : $url)->realpath->to_rel }

sub list ($server = Mojolicious->new(home => Mojo::Home->new('.'))) {
    # This function is used at install-time to list assets that need to be packaged.
    # We should return all files in public/dist.
    my $dist = path('public', 'dist');
    return unless -d $dist;
    $dist->list_tree->each(
        sub ($file, $) {
            say $file->to_rel;
        });
}



1;
