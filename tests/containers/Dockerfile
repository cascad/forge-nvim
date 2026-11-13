# Ubuntu для консольного регресса на Windows/Linux/macOS.
# GUI WezTerm и clipboard проверяются отдельно в нативной GUI-сессии.
FROM ubuntu:24.04@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git python3 python3-venv libpython3.12 procps ripgrep fd-find unzip gcc libc6-dev \
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
RUN GOMAXPROCS=2 GOFLAGS=-p=2 GOTOOLCHAIN=local GOBIN=/opt/forge/bin go install github.com/go-delve/delve/cmd/dlv@v1.26.3 \
    && go version && dlv version
# Rust готовится только при явном build образа; Desktop/WSL runner не запускает.
# SHA: static.rust-lang.org/rustup/archive/1.28.2/<target>/rustup-init.sha256.
ENV RUSTUP_HOME=/opt/forge/rustup CARGO_HOME=/opt/forge/cargo
ENV PATH="/opt/forge/cargo/bin:${PATH}"
RUN set -eu; \
    case "$TARGETARCH" in \
      amd64) target=x86_64-unknown-linux-gnu; sha=20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c ;; \
      arm64) target=aarch64-unknown-linux-gnu; sha=e3853c5a252fca15252d07cb23a1bdd9377a8c6f3efa01531109281ae47f841c ;; \
      *) exit 2 ;; \
    esac; \
    curl --fail --location --retry 3 \
      "https://static.rust-lang.org/rustup/archive/1.28.2/${target}/rustup-init" -o /tmp/rustup-init; \
    echo "$sha  /tmp/rustup-init" | sha256sum -c -; \
    chmod +x /tmp/rustup-init; \
    /tmp/rustup-init -y --no-modify-path --profile minimal --default-toolchain 1.96.1; \
    rustup component add --toolchain 1.96.1 rust-analyzer rustfmt clippy rust-src; \
    rm /tmp/rustup-init
ENV LANG=C.UTF-8
RUN git config --system --add safe.directory /workspace && nvim --version
COPY nvim_forge/lazy-lock.json /opt/forge/nvim_forge/lazy-lock.json
COPY nvim_forge/patches/ /opt/forge/nvim_forge/patches/
COPY nvim_forge/lua/ide/backports.lua /opt/forge/nvim_forge/lua/ide/backports.lua
COPY nvim_forge/scripts/prepare-plugins.lua /opt/forge/nvim_forge/scripts/prepare-plugins.lua
COPY tests/e2e/prepare_editor.py tests/e2e/prepare_tests.py tests/e2e/plugin-sources.json /opt/forge/tests/e2e/
RUN python3 /opt/forge/tests/e2e/prepare_editor.py --download --output /opt/forge/editor-deps
ENV FORGE_E2E_DEPS=/opt/forge/editor-deps
RUN python3 /opt/forge/tests/e2e/prepare_tests.py --download --output /opt/forge/test-deps
ENV FORGE_E2E_TEST_DEPS=/opt/forge/test-deps
ENV PATH="/opt/forge/test-deps/bin:${PATH}"
COPY tests/e2e/prepare_lsp.py /opt/forge/tests/e2e/
RUN python3 /opt/forge/tests/e2e/prepare_lsp.py --download --output /opt/forge/lsp-deps
ENV FORGE_E2E_LSP_DEPS=/opt/forge/lsp-deps
COPY tests/e2e/prepare_node.py /opt/forge/tests/e2e/
COPY tests/e2e/node-tools/ /opt/forge/tests/e2e/node-tools/
RUN python3 /opt/forge/tests/e2e/prepare_node.py --download --output /opt/forge/node-deps
ENV FORGE_E2E_NODE_DEPS=/opt/forge/node-deps
COPY tests/e2e/prepare_python.py /opt/forge/tests/e2e/
COPY tests/e2e/python-tools/ /opt/forge/tests/e2e/python-tools/
COPY tests/e2e/fixtures/python-language/dependency/ /opt/forge/tests/e2e/fixtures/python-language/dependency/
RUN python3 /opt/forge/tests/e2e/prepare_python.py --download --output /opt/forge/python-deps --node-deps /opt/forge/node-deps
ENV FORGE_E2E_PYTHON_DEPS=/opt/forge/python-deps
COPY tests/e2e/prepare_rust.py /opt/forge/tests/e2e/
COPY tests/e2e/rust-tools/ /opt/forge/tests/e2e/rust-tools/
RUN python3 /opt/forge/tests/e2e/prepare_rust.py --download --output /opt/forge/rust-deps
ENV FORGE_E2E_RUST_DEPS=/opt/forge/rust-deps
COPY tests/e2e/prepare_bash.py /opt/forge/tests/e2e/
COPY tests/e2e/bash-tools/ /opt/forge/tests/e2e/bash-tools/
RUN python3 /opt/forge/tests/e2e/prepare_bash.py --download --output /opt/forge/bash-deps --node-deps /opt/forge/node-deps
ENV FORGE_E2E_BASH_DEPS=/opt/forge/bash-deps
COPY tests/e2e/prepare_sql.py tests/e2e/sql_sdk.py /opt/forge/tests/e2e/
COPY tests/e2e/sql-tools/ /opt/forge/tests/e2e/sql-tools/
COPY scripts/sdk/sqls.json scripts/sdk/sqls-query-comments.patch /opt/forge/scripts/sdk/
RUN python3 /opt/forge/tests/e2e/prepare_sql.py --download --output /opt/forge/sql-deps
ENV FORGE_E2E_SQL_DEPS=/opt/forge/sql-deps
COPY scripts/sdk/sql-test/ /opt/forge/scripts/sdk/sql-test/
COPY tests/e2e/prepare_sql_test.py /opt/forge/tests/e2e/
RUN python3 /opt/forge/tests/e2e/prepare_sql_test.py --download --output /opt/forge/sql-test-deps
ENV FORGE_E2E_SQL_TEST_DEPS=/opt/forge/sql-test-deps
RUN useradd --create-home --uid 10001 forge
ENV HOME=/home/forge
USER forge
WORKDIR /workspace

# Optional native sorter: поздний слой сохраняет cache SDK остальных языков.
USER root
COPY tests/e2e/prepare_fzf.py /opt/forge/tests/e2e/
RUN apt-get update && apt-get install -y --no-install-recommends cmake make \
    && rm -rf /var/lib/apt/lists/* \
    && python3 /opt/forge/tests/e2e/prepare_fzf.py --editor-deps /opt/forge/editor-deps --build-root /tmp/forge-fzf
USER forge

# Bash DAP — поздний маленький слой, cache остальных SDK сохраняется.
# Native bundle делает chmod при launch; payload принадлежит test user.
USER root
COPY tests/e2e/prepare_bash_dap.py /opt/forge/tests/e2e/
COPY nvim_forge/lua/forge/bash_debug_patch.json /opt/forge/nvim_forge/lua/forge/bash_debug_patch.json
RUN mkdir -p /opt/forge/bash-dap-deps && chown forge:forge /opt/forge/bash-dap-deps
USER forge
RUN python3 /opt/forge/tests/e2e/prepare_bash_dap.py --download --output /opt/forge/bash-dap-deps
ENV FORGE_E2E_BASH_DAP_DEPS=/opt/forge/bash-dap-deps
