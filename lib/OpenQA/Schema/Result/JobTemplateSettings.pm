# Copyright (C) 2019 SUSE LLC
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
# with this program; if not, see <http://www.gnu.org/licenses/>.

package OpenQA::Schema::Result::JobTemplateSettings;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table('job_template_settings');
__PACKAGE__->load_components(qw(Timestamps));
__PACKAGE__->add_columns(
    id => {
        data_type         => 'integer',
        is_auto_increment => 1,
    },
    job_template_id => {
        data_type      => 'integer',
        is_foreign_key => 1,
    },
    key => {
        data_type => 'text',
    },
    value => {
        data_type => 'text',
    },
);
__PACKAGE__->add_timestamps;
__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([qw(job_template_id key)]);
__PACKAGE__->belongs_to(
    job_template => 'OpenQA::Schema::Result::JobTemplates',
    {'foreign.id' => "self.job_template_id"},
    {
        is_deferrable => 1,
        join_type     => 'LEFT',
        on_delete     => 'CASCADE',
        on_update     => 'CASCADE',
    },
);

1;
