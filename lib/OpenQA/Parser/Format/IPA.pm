# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package OpenQA::Parser::Format::IPA;
use Mojo::Base 'OpenQA::Parser::Format::Base', -signatures;

# Translates to JSON IPA format -> OpenQA internal representation
# The parser results will be a collection of OpenQA::Parser::Result::IPA::Test
use Carp qw(croak confess);
use Mojo::JSON;
use OpenQA::Parser::Result::Test;

sub _add_single_result ($self, @args) { $self->results->add(OpenQA::Parser::Result::OpenQA->new(@args)) }

# Parser
sub parse ($self, $json) {
    confess 'No JSON given/loaded' unless $json;
    my $decoded_json = Mojo::JSON::from_json($json);
    my %unique_names;

    # may be optional since format result_array:v2
    $self->generated_tests_extra->add(OpenQA::Parser::Result::IPA::Info->new($decoded_json->{info}))
      if $decoded_json->{info};

    foreach my $res (@{$decoded_json->{tests}}) {
        my $result = {};
        my $t_name = $res->{nodeid} // $res->{name};
        die 'IPA result misses test name / node ID' unless $t_name;

        if ($t_name =~ /^(?<path>[\w\/]+\/)?(?<file>\w+)\.py::(?<method>\w+)\[\w+:\/\/(\d+\.){3}\d+(-(?<param>.+))?\]$/)
        {
            $t_name = '';
            $t_name .= $+{path} if ($+{path});
            $t_name .= $+{file};
            $t_name .= '_' . $+{method} if ($+{file} ne $+{method});
            if ($+{param}) {
                my $param = $+{param};
                $param =~ s/\.service$//;
                $t_name .= '_' . $param;
            }
        }

        # If a test was triggered twice, we need to unique the name
        if (exists $unique_names{$t_name}) {
            $t_name .= sprintf '_%02d', ++$unique_names{$t_name};
        }
        else {
            $unique_names{$t_name} = 0;
        }

        # replace everything which confuses the web api routes
        $t_name =~ s/[:\/\[\]\.]/_/g;

        $result->{result} = 'fail';
        $result->{result} = 'ok' if $res->{outcome} =~ /passed/i;
        $result->{result} = 'skip' if $res->{outcome} =~ /skipped/i;

        $result->{name} = $t_name;

        my $details = {result => $result->{result}};
        my $text_fn = "IPA-$t_name.txt";
        my $content = CORE::join "\n", $t_name, $result->{result};

        $details->{text} = $text_fn;
        $details->{title} = $t_name;

        push @{$result->{details}}, $details;

        $self->_add_output(
            {
                file => $text_fn,
                content => $content
            });

        my $t = OpenQA::Parser::Result::Test->new(
            flags => {},
            category => 'IPA',
            name => $t_name,
            log => $res->{test}->{log},
            duration => $res->{test}->{duration},
            script => undef,
            result => $result->{result});
        $self->tests->add($t);
        $result->{test} = $t if $self->include_results();
        $self->_add_single_result($result);
    }

    $self;
}

package OpenQA::Parser::Result::IPA::Info {
    use Mojo::Base 'OpenQA::Parser::Result', -signatures;

    has [qw(distro platform image instance region results_file log_file timestamp)];
}

1;
