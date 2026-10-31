# Ubuntu для консольного регресса на Windows/Linux/macOS.
# GUI WezTerm и clipboard проверяются отдельно в нативной GUI-сессии.
FROM ubuntu:24.04@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git python3 ripgrep fd-find unzip gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*
# Официальные assets v0.12.2 и SHA256:
# https://github.com/neovim/neovim/releases/expanded_assets/v0.12.2
RUN set -eu; \
    case "$TARGETARCH" in \
      amd64) arch=x86_64; sha=31cf85945cb600d96cdf69f88bc68bec814acbff50863c5546adef3a1bcef260 ;; \
      arm64) arch=arm64; sha=f697d4e4582b6e4b5c3c26e76e06ce26efa08ba1768e03fd2733fcc422bb0490 ;; \
      *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 2 ;; \
    esac; \
    curl --fail --location --retry 3 \
      "https://github.com/neovim/neovim/releases/download/v0.12.2/nvim-linux-${arch}.tar.gz" \
      -o /tmp/nvim.tar.gz; \
    echo "$sha  /tmp/nvim.tar.gz" | sha256sum -c -; \
    mkdir -p /opt/nvim; \
    tar xzf /tmp/nvim.tar.gz --strip-components=1 -C /opt/nvim; \
    rm /tmp/nvim.tar.gz
ENV PATH="/opt/nvim/bin:${PATH}"
# Только явная подготовка тестового окружения. SHA256 — https://go.dev/dl/.
RUN set -eu; \
    case "$TARGETARCH" in \
      amd64) arch=amd64; sha=aac1b08a0fb0c4e0a7c1555beb7b59180b05dfc5a3d62e40e9de90cd42f88235 ;; \
      arm64) arch=arm64; sha=bd03b743eb6eb4193ea3c3fd3956546bf0e3ca5b7076c8226334afe6b75704cd ;; \
      *) exit 2 ;; \
    esac; \
    curl --fail --location --retry 3 "https://go.dev/dl/go1.26.0.linux-${arch}.tar.gz" -o /tmp/go.tar.gz; \
    echo "$sha  /tmp/go.tar.gz" | sha256sum -c -; \
    tar xzf /tmp/go.tar.gz -C /opt; rm /tmp/go.tar.gz
ENV PATH="/opt/go/bin:/opt/forge/bin:${PATH}"
RUN GOTOOLCHAIN=local GOBIN=/opt/forge/bin go install github.com/go-delve/delve/cmd/dlv@v1.26.3 \
    && go version && dlv version
ENV LANG=C.UTF-8
RUN git config --system --add safe.directory /workspace && nvim --version
COPY nvim_forge/lazy-lock.json /opt/forge/nvim_forge/lazy-lock.json
COPY tests/e2e/prepare_editor.py tests/e2e/prepare_tests.py tests/e2e/plugin-sources.json /opt/forge/tests/e2e/
RUN python3 /opt/forge/tests/e2e/prepare_editor.py --download --output /opt/forge/editor-deps
ENV FORGE_E2E_DEPS=/opt/forge/editor-deps
RUN python3 /opt/forge/tests/e2e/prepare_tests.py --download --output /opt/forge/test-deps
ENV FORGE_E2E_TEST_DEPS=/opt/forge/test-deps
ENV PATH="/opt/forge/test-deps/bin:${PATH}"
RUN useradd --create-home --uid 10001 forge
ENV HOME=/home/forge
USER forge
WORKDIR /workspace
