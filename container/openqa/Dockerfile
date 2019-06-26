# hadolint ignore=DL3007
FROM registry.opensuse.org/devel/openqa/containers/openqa_dev:latest
ENV LANG en_US.UTF-8
COPY dependencies /dependencies.new
RUN diff -q /dependencies{,.new} || sudo xargs -a /dependencies.new zypper --no-gpg-checks --no-refresh -n in -C
# call zypper again ontop of the base layer in case of new dependencies. This
# is a noop otherwise
# this would be an alternative by reading from an environment variable.
# However keep in mind that the env variable from the base layer has the *old*
# content. So this will not work for any new added dependencies because the
# environment variable DEPENDENCIES is actually only defined in the *built*
# base image which we would only get from OBS *after* a PR is merged, not as
# long as it is open
#RUN [ -z "${DEPENDENCIES}" ] || zypper --gpg-auto-import-keys in -n -C ${DEPENDENCIES}
COPY entrypoint.sh /usr/bin/entrypoint
# don't know how to replace sudo with other calls right now
# hadolint ignore=DL3004
RUN ["sudo","chmod","+x","/usr/bin/entrypoint"]
USER ${NORMAL_USER}
ENTRYPOINT ["entrypoint"]
