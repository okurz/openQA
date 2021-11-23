# Copyright 2014-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package OpenQA::Test::Database;
use Test::Most;
use Mojo::Base -base, -signatures;

use Date::Format;    # To allow fixtures with relative dates
use DateTime;    # To allow fixtures using InflateColumn::DateTime
use Carp;
use Cwd qw( abs_path getcwd );
use English;
use Feature::Compat::Try;
use OpenQA::Schema;
use OpenQA::Log 'log_info';
use OpenQA::Utils 'random_string';
use Mojo::File 'path';

has fixture_path => 't/fixtures';

sub generate_schema_name () { 'tmp_' . random_string() }

sub spawn_postgres {
    $ENV{TEST_PG_PATH} //= '/dev/shm/tpg';
    # this times out in `prove -l -v t/03-auth.t` and I don't see any output.
    # Maybe it's better to use IPC::Run and show the output unbuffered or
    # something
    my $out = qx{test -d $ENV{TEST_PG_PATH} && (pg_ctl -D $ENV{TEST_PG_PATH} -s status >&/dev/null || pg_ctl -D $ENV{TEST_PG_PATH} -s start) || ./t/test_postgresql $ENV{TEST_PG_PATH}};
    diag $out;
    $ENV{TEST_PG} = "DBI:Pg:dbname=openqa_test;host=$ENV{TEST_PG_PATH}";
}

sub create ($self, %options) {
    spawn_postgres;

    # create new database connection
    my $schema = OpenQA::Schema::connect_db(mode => 'test', deploy => 0);

    # ensure the time zone is set consistently to UTC for this session
    my $storage = $schema->storage;
    my $dbh;
    try { $dbh = $storage->dbh }
    catch ($e) {
        diag $e;
        plan skip_all => 'set TEST_PG to e.g. "DBI:Pg:dbname=test" to enable this test'
          if $e =~ /DBI Connection failed.*No such file or directory/ && !$ENV{TEST_PG};
    }
    $dbh->do('SET TIME ZONE "utc"');

    # create a new schema or use an existing one
    unless (defined $options{skip_schema}) {
        my $schema_name = $options{schema_name} // generate_schema_name;
        log_info("using database schema \"$schema_name\"");

        if ($options{drop_schema}) {
            $dbh->do('set client_min_messages to WARNING;');
            $dbh->do("drop schema if exists $schema_name cascade;");
        }
        $schema->search_path_for_tests($schema_name);
        $dbh->do("create schema \"$schema_name\"");
        $schema->set_search_path($schema_name);
    }

    $schema->deploy;
    $self->insert_fixtures($schema, $options{fixtures_glob}) if $options{fixtures_glob};
    return $schema;
}

END {
    qx{pg_ctl -D $ENV{TEST_PG_PATH} stop} unless $ENV{USE_EXTERNAL_PG} || $ENV{KEEP_DB};
}
sub insert_fixtures ($self, $schema, $fixtures_glob = '*.pl') {
    # Store working dir
    my $cwd = getcwd;

    chdir $self->fixture_path;
    my %ids;
    foreach my $fixture (glob "$fixtures_glob") {

        my $info = eval path($fixture)->slurp;    ## no critic (BuiltinFunctions::ProhibitStringyEval)
        chdir $cwd, croak "Could not insert fixture $fixture: $EVAL_ERROR" if $EVAL_ERROR;
        # Arrayrefs of rows, (dbic syntax) table defined by fixture filename
        if (ref $info->[0] eq 'HASH') {
            my $rs_name = (split /\./, $fixture)[0];
            $rs_name =~ s/s$//;

            # list context, so that populate uses dbic ->insert overrides
            my @noop = $schema->resultset(ucfirst $rs_name)->populate($info);

            next;
        }

        # Arrayref of hashrefs, multiple tables per file
        for (my $i = 0; $i < @$info; $i++) {
            my $class = $info->[$i];
            my $ri = $info->[++$i];
            try {
                my $row = $schema->resultset($class)->create($ri);
                $ids{$row->result_source->from} = $ri->{id} if $ri->{id};
            }
            catch ($e) {
                croak 'Could not insert fixture ' . path($fixture)->to_rel($cwd) . ": $e";    # uncoverable statement
            }
        }
    }

    # Restore working dir
    chdir $cwd;
    my $dbh = $schema->storage->dbh;

    for my $table (keys %ids) {
        my $max = $dbh->selectrow_arrayref("select max(id) from $table")->[0] + 1;
        $schema->storage->dbh->do("alter sequence $table\_id_seq restart with $max");
    }
}

1;

=head1 NAME

OpenQA::Test::Database

=head1 DESCRIPTION

Deploy schema & load fixtures

=head1 USAGE

    # Creates an test database from DBIC OpenQA::Schema with or without fixtures
    my $schema = Test::Database->new->create;
    my $schema = Test::Database->new->create(fixtures_glob => '01-jobs.pl 02-foo.pl');

=head1 METHODS

=head2 create (%args)

Create new database from DBIC schema.
Use fixtures_glob to select fixtures to load from files.

=head2 insert_fixtures

Insert fixtures into database

=cut
