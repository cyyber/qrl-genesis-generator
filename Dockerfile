ARG QRYSM_GIT_REPO=https://github.com/cyyber/qrysm.git
ARG QRYSM_GIT_REF=main

FROM golang:1.26.5-bookworm AS builder

ARG QRYSM_GIT_REPO
ARG QRYSM_GIT_REF

RUN git init /qrysm && \
    git -C /qrysm remote add origin "${QRYSM_GIT_REPO}" && \
    git -C /qrysm fetch --depth 1 origin "${QRYSM_GIT_REF}" && \
    git -C /qrysm checkout --detach FETCH_HEAD && \
    cd /qrysm && \
    GOTOOLCHAIN=local go install -mod=readonly \
        ./cmd/qrysmctl \
        ./cmd/staking-deposit-cli/deposit \
        ./cmd/validator

FROM debian:bookworm-slim
WORKDIR /work
VOLUME ["/config", "/data"]
EXPOSE 8000/tcp
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    ca-certificates build-essential python3 python3-dev python3.11-venv python3-venv python3-pip gettext-base jq wget curl && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY apps /apps

RUN cd /apps/el-gen && python3 -m venv .venv && /apps/el-gen/.venv/bin/pip3 install -r /apps/el-gen/requirements.txt
COPY --from=builder /go/bin/qrysmctl /usr/local/bin/qrysmctl
COPY --from=builder /go/bin/deposit /usr/local/bin/deposit
COPY --from=builder /go/bin/validator /usr/local/bin/validator
COPY config-example /config
COPY defaults /defaults
COPY entrypoint.sh .
ENTRYPOINT [ "/work/entrypoint.sh" ]
