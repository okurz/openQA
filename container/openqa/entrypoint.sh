#!/bin/sh -e

cp -rd /opt/openqa /opt/testing_area
cd /opt/testing_area/openqa
eval "$(t/test_postgresql | grep TEST_PG=)"
echo ">> Running tests"
sh -c "$*"
