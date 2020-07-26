ARG VERSION=current

FROM cimg/node:${VERSION} as builder

# For compatibility reasons, we need to use the root user -
# older versions of cimg/node does not have a working sudo installation.
USER root

COPY ./scripts/install-chromium-deps.js /tmp

# ALL Ubuntu dependencies related actions should be handled here:
# - Add the Universe repository
# - Update the apt repository list files
# - Ensure sudo is installed
# - Install necessary dependencies for Chromium
# - Remove apt repository list files
RUN add-apt-repository universe && \
  apt-get update && \
  apt-get install -y sudo && \
  "$(which node)" /tmp/install-chromium-deps.js && \
  rm -rf /var/lib/apt/lists/* && \
  rm /tmp/install-chromium-deps.js

# In older versions of cimg/node, the circleci user does not exist.
# We will create and switch to it here for the sake of consistency and security.
# The steps below are copied from the CircleCI-Public/cimg-base repo.
RUN useradd --uid=3434 --user-group --create-home circleci && \
	echo 'circleci ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci && \
	echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep && \
	-u circleci mkdir /home/circleci/project || true
USER circleci
WORKDIR /home/circleci/project

FROM builder

# Enable user namespace cloning for Chromium's sandboxing.
# For security, we also ensure ptrace debugging is only allowed for parent processes.
# This command will fail when building from incompatible kernels (e.g. macOS).
# For development purposes, one could make it fail gracefully by appending `|| true`.
RUN sudo sysctl -w kernel.unprivileged_userns_clone=1 && \
  sudo sysctl -w kernel.yama.ptrace_scope=1
