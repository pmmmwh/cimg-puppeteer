ARG VERSION=current

FROM cimg/node:${VERSION} as builder

COPY ./scripts/install-chromium-deps.js /tmp

RUN add-apt-repository universe && \
  apt-get update && \
  "$(which node)" /tmp/install-chromium-deps.js && \
  rm /tmp/install-chromium-deps.js && \
  rm -rf /var/lib/apt/lists/*

FROM builder

RUN sudo sysctl -w kernel.unprivileged_userns_clone=1 && \
  sudo sysctl -w kernel.yama.ptrace_scope=1 || true
