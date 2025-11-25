# ARG QRYSM_GIT_REPO=https://github.com/theQRL/qrysm.git
ARG QRYSM_GIT_REPO=https://github.com/rgeraldes24/qrysm.git
ARG QRYSM_GIT_BRANCH=main

FROM golang:1.22 AS builder

ARG QRYSM_GIT_REPO
ARG QRYSM_GIT_BRANCH

# RUN git clone -b ${QRYSM_GIT_BRANCH} ${QRYSM_GIT_REPO}  \
RUN git clone ${QRYSM_GIT_REPO}  \
    && cd qrysm \
    && go install ./cmd/qrysmctl \
    && go install ./cmd/staking-deposit-cli/deposit \ 
    && go install ./cmd/validator

FROM debian:12
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

ENV PATH="/root/.cargo/bin:${PATH}"
RUN cd /apps/el-gen && python3 -m venv .venv && /apps/el-gen/.venv/bin/pip3 install -r /apps/el-gen/requirements.txt
COPY --from=builder /go/bin/qrysmctl /usr/local/bin/qrysmctl
COPY --from=builder /go/bin/deposit /usr/local/bin/deposit
COPY --from=builder /go/bin/validator /usr/local/bin/validator
COPY config-example /config
COPY defaults /defaults
COPY entrypoint.sh .
ENTRYPOINT [ "/work/entrypoint.sh" ]
