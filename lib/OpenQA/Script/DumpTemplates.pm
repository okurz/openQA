# Copyright (C) 2015-2021 SUSE LLC
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
# You should have received a copy of the GNU General Public License

package OpenQA::Script::DumpTemplates;

use Mojo::Base -strict, -signatures;

use Exporter 'import';

our @EXPORT = qw(
  run
);

sub handle_error ($target, $url, $res) {
    my $code    = $res->code    // 'unknown error code - host ' . $url->host . ' unreachable?';
    my $message = $res->message // 'no error message';
    printf STDERR "ERROR requesting %s via %s: %s - %s\n", $target, $url, $code, $message;
    dd($res->json || $res->body) if $res->body;
    exit(1);
}

sub parse_options ($options) {
    if ($options->{group}) {
        $options->{group}       = {map { $_ => 1 } @{$options->{group}}};
        $tables{JobTemplates} = 1;
        $tables{JobGroups}    = 1;
    }
    if ($options->{test}) {
        $options->{test}      = {map { $_ => 1 } @{$options->{test}}};
        $tables{TestSuites} = 1;
    }
    if ($options->{machine}) {
        $options->{machine} = {map { $_ => 1 } @{$options->{machine}}};
        $tables{Machines} = 1;
    }
    if ($options->{product}) {
        $options->{product} = {map { $_ => 1 } @{$options->{product}}};
        $tables{Products} = 1;
    }

    $options->{host}    ||= 'localhost';
    $options->{apibase} ||= '/api/v1';
    return undef;
}

sub tables (@args) {
    my %tables = map { $_ => 1 } qw(Machines TestSuites Products JobTemplates JobGroups);
    return %tables unless @args;
    my %want = map { $_ => 1 } @args;
    # Show an error and refer to usage if a non-existing table name is passed
    for my $t (keys %want) {
        if (!exists $tables{$t}) {
            printf STDERR "Invalid table name $t\n\n";
            usage(1);
        }
    }
    return map { $_ => !!$want{$_} } (keys %tables);
}

sub delete_all_settings ($settings) {
    delete $settings->[$_]->{id} for (0 .. $#{$settings});
}

sub product_key ($product_table) {
    join('-', map { $product_table->{$_} } qw(distri version flavor arch));
}

sub output_result ($result) {
    return dd \%result unless $options->{json};
    use Mojo::JSON;    # booleans
    use Cpanel::JSON::XS;
    print Cpanel::JSON::XS->new->ascii->pretty->encode($result);
}

sub run ($options, @args) {
    parse_options($options);
    my %tables = tables(@args);
    my $url    = OpenQA::Client::url_from_host($options->{host});
    my $client = OpenQA::Client->new(apikey => $options->{apikey}, apisecret => $options->{apisecret}, api => $url->host);
    my %result;

    if ($tables{'JobGroups'}) {
        my $group = (keys %{$options->{group}})[0];
        $url->path($options->{apibase} . '/job_templates_scheduling/' . ($group // ''));
        my $res = $client->get($url)->res;
        handle_error($group // 'all groups', $url, $res) unless $res->code && $res->code == 200;

        # For a single group we already have the YAML document at first level
        #my %templates = $group ? ($group => $res->json) : map { $_ => $yaml->{$_} } (sort keys %$yaml);
        #$result{JobGroups} = map { group_name => $_, template => $templates{$_} } sort keys %templates;
        if ($group) {
            push @{$result{JobGroups}}, {group_name => $group, template => $res->json};
        }
        else {
            my $yaml = $res->json;
            foreach my $group (sort keys %$yaml) {
                push @{$result{JobGroups}}, {group_name => $group, template => $yaml->{$group}};
            }
        }
    }

    for my $table (qw(Machines TestSuites Products JobTemplates)) {
        next unless $tables{$table};

        $url->path($options->{apibase} . '/' . decamelize($table));
        my $res = $client->get($url)->res;
        handle_error($table, $url, $res) unless $res->code && $res->code == 200;
        %result = (%result, %{$res->json});
    }

    # special trick to dump all TestSuites used by specific JobTemplates
    if ($tables{JobTemplates} && $options->{full}) {
        for my $r (@{$result{JobTemplates}}) {
            next if $options->{group} && !$options->{group}->{$r->{group_name}};
            $options->{test}->{$r->{test_suite}->{name}} = 1;
            $options->{machine}->{$r->{machine}->{name}} = 1;
            $options->{product}->{product_key($r->{product})} = 1;
        }
    }

    for my $table (keys %result) {
        my @r;
        while (my $r = shift @{$result{$table}}) {
            if ($table eq 'JobTemplates') {
                next if $options->{group} && $r->{group_name} && !$options->{group}->{$r->{group_name}};
                next if $options->{product} && !$options->{product}->{product_key($r->{product})};
            }
            next if $table eq 'TestSuites' && $options->{test}    && $r->{name} && !$options->{test}->{$r->{name}};
            next if $table eq 'Machines'   && $options->{machine} && $r->{name} && !$options->{machine}->{$r->{name}};
            next if $table eq 'Products'   && $options->{product}) && !$options->{product}->{product_key($r)};
            delete $r->{id};
            delete_all_settings($r->{settings}) if $r->{settings};
            delete $r->{product}->{id}          if $r->{product};
            delete $r->{machine}->{id}          if $r->{machine};
            delete $r->{test_suite}->{id}       if $r->{test_suite};
            push @r, $r;
        }
        $result{$table} = [@r];
    }

    output_result(\%result);
}

1;
