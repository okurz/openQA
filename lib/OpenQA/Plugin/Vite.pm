# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package OpenQA::Plugin::Vite;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::File qw(path);
use JSON::PP qw(decode_json);

sub register ($self, $app, $conf = {}) {
    my $dist_path = $app->home->child('public', 'dist');
    my $manifest_file = $dist_path->child('.vite', 'manifest.json');
    my $manifest;

    # Helper to get the correct asset URL
    $app->helper(
        vite => sub ($c, $name) {
            # In development mode, proxy to the Vite dev server
            if ($app->mode eq 'development' && !$ENV{OPENQA_VITE_PRODUCTION}) {
                # Add test suffix if needed
                my $test_name = $name;
                if ($app->mode eq 'test' || $c->stash('mode') eq 'test') {
                    $test_name =~ s/\.(js|css)$/.test.$1/;
                }
                # Vite dev server serves from / (root) which we've set to 'assets/'
                # But we need to point to our entry points
                if ($test_name =~ /\.js$/) {
                    return "/entry/$test_name";
                }
                elsif ($test_name =~ /\.css$/) {
                    # Vite processes .scss but we'll request them as .css or .scss?
                    # Actually, we should probably point to the entry scss files.
                    my $scss_name = $test_name;
                    $scss_name =~ s/\.css$/.scss/;
                    return "/entry/$scss_name";
                }
                else {
                    # For images, etc.
                    return "/images/$name";
                }
            }

            # In production, use the manifest
            unless ($manifest) {
                if (-e $manifest_file) {
                    $manifest = decode_json($manifest_file->slurp);
                }
                else {
                    $app->log->warn("Vite manifest not found at $manifest_file. Did you run 'npm run build'?");
                    $manifest = {};
                }
            }

            my $test_name = $name;
            if ($app->mode eq 'test' || $c->stash('mode') eq 'test') {
                $test_name =~ s/\.(js|css)$/.test.$1/;
            }

            my $entry = $manifest->{$test_name} || $manifest->{$name};
            if ($entry) {
                return $c->url_for('/dist/' . $entry->{file});
            }

            # Fallback to public/
            return $c->url_for('/' . $name);
        });

    # Override the 'asset' helper for backward compatibility
    $app->helper(
        asset => sub ($c, $name) {
            my $url = $c->vite($name);
            if ($name =~ /\.js$/) {
                return $c->javascript($url);
            }
            elsif ($name =~ /\.css$/) {
                return $c->stylesheet($url);
            }
            else {
                return $url;
            }
        });
}

1;
