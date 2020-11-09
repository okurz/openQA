#!BuildTag: base
#!UseOBSRepositories
# preserve layers to avoid failures in CircleCI while it downloads a big blob
# in one go
# see https://progress.opensuse.org/issues/67855
#!NoSquash
FROM opensuse/leap:15.3

# only dependencies for CircleCI to be able to load/save the package cache
# and fix permissions for the unprivileged user we use
RUN zypper -n in tar gzip sudo

ENV LANG en_US.UTF-8
