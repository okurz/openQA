# Copyright (C) 2019 SUSE LINUX GmbH, Nuernberg, Germany
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

package OpenQA::WebAPI::Plugin::MIMETypes;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app) = @_;

    my $types = $app->types;
    $types->type(yaml => 'text/yaml;charset=UTF-8');
    $types->type(bz2  => 'application/x-bzip2');
    $types->type(xz   => 'application/x-xz');
}

1;
