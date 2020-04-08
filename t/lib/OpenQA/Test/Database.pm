#
# Stolen from https://github.com/tempire/MojoExample
# TODO: Contact author to make sure that's OK
#

package OpenQA::Test::Database;
use Mojo::Base -base;

use Date::Format;    # To allow fixtures with relative dates
use DateTime;        # To allow fixtures using InflateColumn::DateTime
use Carp;
use Cwd qw( abs_path getcwd );
use OpenQA::Schema;
use OpenQA::Log 'log_info';
use OpenQA::Utils 'random_string';
use Mojo::File 'path';

has fixture_path => 't/fixtures';

use Test::More;
plan skip_all => 'set TEST_PG to e.g. DBI:Pg:dbname=test" to enable this test' unless $ENV{TEST_PG};

sub generate_schema_name {
    return 'tmp_' . random_string();
}

sub create {
    my ($self, %options) = @_;

    # create new database connection
    my $schema = OpenQA::Schema::connect_db(mode => 'test', check => 0);

    # create a new schema or use an existing one
    unless (defined $options{skip_schema}) {
        my $storage     = $schema->storage;
        my $dbh         = $storage->dbh;
        my $schema_name = $options{schema_name} // generate_schema_name;
        log_info("using database schema \"$schema_name\"\n");

        if ($options{drop_schema}) {
            $dbh->do('set client_min_messages to WARNING;');
            $dbh->do("drop schema if exists $schema_name cascade;");
        }
        $schema->search_path_for_tests($schema_name);
        $dbh->do("create schema \"$schema_name\"");
        $dbh->do("SET search_path TO \"$schema_name\"");
        # handle reconnects
        $storage->on_connect_do("SET search_path TO \"$schema_name\"");
    }

    OpenQA::Schema::deployment_check($schema) unless $options{skip_deployment_check};
    $self->insert_fixtures($schema) unless $options{skip_fixtures};

    return $schema;
}

sub insert_fixtures {
    my ($self, $schema) = @_;

    # Store working dir
    my $cwd = getcwd;

    chdir $self->fixture_path;
    my %ids;

    foreach my $fixture (glob "*.pl") {
        my $info = eval path($fixture)->slurp;    ## no critic
        chdir $cwd, croak "Could not insert fixture $fixture: $@" if $@;

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
            my $ri    = $info->[++$i];
            my $row = $schema->resultset($class)->create($ri);
            $ids{$row->result_source->from} = $ri->{id} if $ri->{id};
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

sub disconnect {
    my $schema = shift;
    my $dbh    = $schema->storage->dbh;
    if (my $search_path = $schema->search_path_for_tests) { $dbh->do("drop schema $search_path") }
    return $dbh->disconnect;
}

1;

=head1 NAME

Test::Database

=head1 DESCRIPTION

Deploy schema & load fixtures

=head1 USAGE

    # Creates an test database from DBIC OpenQA::Schema with or without fixtures
    my $schema = Test::Database->new->create;
    my $schema = Test::Database->new->create(skip_fixtures => 1);

=head1 METHODS

=head2 create (%args)

Create new database from DBIC schema.
Use skip_fixtures to prevent loading fixtures.

=head2 insert_fixtures

Insert fixtures into database

=head2 disconnect ($schema)

Disconnect from database handle

=cut
