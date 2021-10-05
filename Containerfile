ARG ALPINE_TAG=3.14.1
FROM alpine:$ALPINE_TAG as config-alpine

RUN apk add --no-cache tzdata

RUN cp -v /usr/share/zoneinfo/America/New_York /etc/localtime
RUN echo "America/New_York" > /etc/timezone

FROM alpine:$ALPINE_TAG

COPY --from=config-alpine /etc/localtime /etc/localtime
COPY --from=config-alpine /etc/timezone  /etc/timezone

EXPOSE 22

ARG VERSION=1.1.1
RUN echo $VERSION
RUN apk add --no-cache buildah podman=$VERSION git iputils openssh fuse-overlayfs shadow slirp4netns sudo

RUN mv /etc/containers/storage.conf /etc/containers/storage.conf~ \
 && sed 's/#mount_program/mount_program/' /etc/containers/storage.conf~ > /etc/containers/storage.conf \
 && mv /etc/ssh/sshd_config /etc/ssh/sshd_config~ \
 && sed 's/AllowTcpForwarding no/AllowTcpForwarding all/' /etc/ssh/sshd_config~ > /etc/ssh/sshd_config \
 && mkdir -p /opt/podman-data

COPY podman-prune /etc/periodic/15min/podman-prune
COPY entrypoint /entrypoint

ARG USER=podman
RUN addgroup $USER \
 && adduser -D -s /bin/sh -G $USER $USER \
 && echo "$USER:$USER" | chpasswd \
 && usermod --add-subuids 100000-165535 $USER \
 && usermod --add-subgids 100000-165535 $USER

RUN chown $USER:$USER -R /opt/podman-data \
 && echo "%wheel         ALL = (ALL) NOPASSWD: /usr/sbin/sshd,/usr/bin/ssh-keygen,/usr/sbin/crond" >> /etc/sudoers \
 && usermod -aG wheel $USER

USER $USER
WORKDIR /home/$USER

RUN mkdir -p ~/.ssh
# RUN ln -s /opt/podman-data/authorized_keys ~/.ssh/authorized_keys
# RUN chmod 0400 -R ~/.ssh

RUN podman system connection add local --identity /home/$USER/.ssh/podman_key ssh://localhost:22/tmp/podman-run-1000/podman/podman.sock \
 && podman system connection add x86 --identity /home/$USER/.ssh/podman_key_x86 ssh://$USER@podman-x86.cicd.svc.cluster.local:22/tmp/podman-run-1000/podman/podman.sock \
 && podman system connection add arm --identity /home/$USER/.ssh/podman_key_arm ssh://$USER@podman-arm.cicd.svc.cluster.local:22/tmp/podman-run-1000/podman/podman.sock 
 
ENTRYPOINT ["/entrypoint"]


