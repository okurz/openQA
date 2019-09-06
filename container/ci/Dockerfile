#!BuildTag: openqa_dev
FROM opensuse/leap:15.3

RUN zypper -n in openQA-devel

# Define environment variable
ENV NAME openQA test environment
ENV LANG en_US.UTF-8

VOLUME ["/sys/fs/cgroup", "/run"]

CMD ["/sbin/init"]

ENV OPENQA_DIR /opt/openqa
ENV NORMAL_USER squamata

RUN echo "$NORMAL_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    mkdir -p /home/$NORMAL_USER && \
    useradd -r -d /home/$NORMAL_USER -g users --uid=1000 $NORMAL_USER && \
    chown $NORMAL_USER:users /home/$NORMAL_USER
VOLUME [ "/opt/openqa" ]

# explicitly set user/group IDs
RUN mkdir -p /opt/testing_area && \
    chown -R $NORMAL_USER:users /opt/testing_area

ENTRYPOINT ["/bin/bash"]
WORKDIR $OPENQA_DIR
