ARG VERSION=current

FROM cimg/node:${VERSION} AS builder

LABEL maintainer="Michael Mok"

# For compatibility reasons, we need to use the root user -
# older versions of cimg/node does not have a working sudo installation.
USER root

COPY ./install-chromium-deps.js /tmp

# All Ubuntu dependencies related actions should be handled here -
# it has to be a single RUN instruction for cacheability and image size.
# - Add the Universe repository
# - Update the apt repository list files
# - Upgrade outdated packages on the image and pull in additional ones if needed
# - Install gosu for deescalation during docker build
# - Ensure sudo is installed (it is not for older versions)
# - Install necessary dependencies for Chromium
# - Remove apt repository list files
# - Remove Chromium dependencies installation script
RUN add-apt-repository universe; \
  apt-get update; \
  apt-get install --no-install-recommends -y gosu sudo; \
  "$(which node)" /tmp/install-chromium-deps.js; \
  rm -rf /var/lib/apt/lists/*; \
  rm /tmp/install-chromium-deps.js

# In older versions of cimg/node, the circleci user does not exist.
# We will create and switch to it here for the sake of consistency and security.
# The steps below are copied from the CircleCI-Public/cimg-base repo.
RUN if ! id -u circleci; then \
  useradd --uid=3434 --user-group --create-home circleci; \
	echo "circleci ALL=NOPASSWD: ALL" >>/etc/sudoers.d/50-circleci; \
	echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >>/etc/sudoers.d/env_keep; \
	gosu circleci mkdir /home/circleci/project; \
	fi

# Globally enable unprivileged user namespaces for Chromium's sandboxing.
# NOTE: This will only have effect if the user is running with kernel privileges enabled.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN echo "kernel.unprivileged_userns_clone=1" | tee -a /etc/sysctl.d/99-enable-user-namespaces.conf > /dev/null

# Older versions of cimg/node mutates this variable, which in turn breaks npm/yarn.
# We will patch it here to ensure it is correctly set.
ENV HOME=/home/circleci/project
USER circleci
WORKDIR /home/circleci/project
