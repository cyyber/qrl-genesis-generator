# Multi-stage build: the Go stage builds the qrysm tooling, the venv stage
# builds the Python environment with its compilers, and the runtime stage
# keeps only what entrypoint.sh executes.
ARG QRYSM_GIT_REPO=https://github.com/cyyber/qrysm.git
ARG QRYSM_GIT_REF=main
ARG RUNTIME_BASE_IMAGE=debian:bookworm-slim

FROM golang:1.26-bookworm AS qrysm-builder

ARG QRYSM_GIT_REPO
ARG QRYSM_GIT_REF

# init+fetch instead of clone -b so the ref may be a branch, a tag, or a
# full commit SHA.
RUN git init /src/qrysm && \
    git -C /src/qrysm remote add origin "${QRYSM_GIT_REPO}" && \
    git -C /src/qrysm fetch --depth 1 origin "${QRYSM_GIT_REF}" && \
    git -C /src/qrysm checkout --detach FETCH_HEAD && \
    cd /src/qrysm && \
    go install ./cmd/qrysmctl \
        ./cmd/staking-deposit-cli/deposit \
        ./cmd/validator

# The virtual environment is built with the compiler toolchain in a stage
# that is thrown away; the identical runtime base keeps the interpreter
# paths valid.
FROM ${RUNTIME_BASE_IMAGE} AS venv-builder

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        build-essential ca-certificates python3 python3-dev python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/*

COPY apps /apps
RUN cd /apps/el-gen && \
    python3 -m venv .venv && \
    .venv/bin/pip install --no-cache-dir -r requirements.txt

FROM ${RUNTIME_BASE_IMAGE}

# Exactly what entrypoint.sh and the generator scripts execute: python for
# the generators, envsubst (gettext-base) for templating, jq for JSON, and
# openssl for the JWT secret.
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        ca-certificates gettext-base jq openssl python3 python3-venv && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /work
VOLUME ["/config", "/data"]
EXPOSE 8000/tcp

COPY --from=venv-builder /apps /apps
COPY --from=qrysm-builder /go/bin/qrysmctl /usr/local/bin/qrysmctl
COPY --from=qrysm-builder /go/bin/deposit /usr/local/bin/deposit
COPY --from=qrysm-builder /go/bin/validator /usr/local/bin/validator
COPY config-example /config
COPY defaults /defaults
COPY entrypoint.sh .

RUN /apps/el-gen/.venv/bin/pip check && \
    qrysmctl --help >/dev/null && \
    deposit --help >/dev/null && \
    validator --version >/dev/null

ENTRYPOINT ["/work/entrypoint.sh"]
