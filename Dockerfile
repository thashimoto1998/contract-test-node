# Based from https://github.com/paritytech/substrate/blob/master/.maintain/Dockerfile
# ===== FIRST STAGE =====
FROM phusion/baseimage:0.10.2 as builder
LABEL maintainer="hashimoto19980924@gmail.com"
LABEL description="This is the build stage for Canvas Node. Here we create the binary."

ENV DEBIAN_FRONTEND=noninteractive

ARG PROFILE=release
WORKDIR /canvas

COPY . /canvas

RUN apt-get update && \
	apt-get dist-upgrade -y -o Dpkg::Options::="--force-confold" && \
	apt-get install -y cmake cmake pkg-config libssl-dev git clang libclang-dev

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y && \
	export PATH="$PATH:$HOME/.cargo/bin" && \
	rustup toolchain install nightly && \
	rustup toolchain install nightly-2020-09-30 && \
	rustup override set nightly-2020-09-30 && \
	rustup target add wasm32-unknown-unknown --toolchain nightly-2020-09-30 && \
	cargo build "--$PROFILE"
	
# ===== SECOND STAGE ======
FROM phusion/baseimage:0.10.2
LABEL maintainer="hashimoto19980924@gmail.com"
LABEL description="This is the 2nd stage: a very small image where we copy the Canvas Node binary."
ARG PROFILE=release

RUN mv /usr/share/ca* /tmp && \
	rm -rf /usr/share/*  && \
	mv /tmp/ca-certificates /usr/share/ && \
	useradd -m -u 1000 -U -s /bin/sh -d /canvas canvas

COPY --from=builder /canvas/target/$PROFILE/canvas-node /usr/local/bin

# checks
RUN ldd /usr/local/bin/canvas-node && \
	/usr/local/bin/canvas-node --version

# Shrinking
RUN rm -rf /usr/lib/python* && \
	rm -rf /usr/bin /usr/sbin /usr/share/man

USER celer
EXPOSE 30333 9933 9944 9615

RUN mkdir /canvas/data

VOLUME ["/canvas/data"]

ENTRYPOINT ["/usr/local/bin/canvas-node"]
CMD ["--base-path", "/tmp/alice", "--chain=dev", "--port", "30333", "--validator", "--alice", "--unsafe-ws-external", "--unsafe-rpc-external", "--no-telemetry", "--rpc-cors", "all"]