ARG IMAGE=intersystemsdc/iris-community
FROM $IMAGE

USER root
RUN apt-get update && \
    apt-get install -y curl build-essential && \
    rm -rf /var/lib/apt/lists/*

# Build Rust engine
COPY src/rust /tmp/rust_build
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    . $HOME/.cargo/env && \
    cd /tmp/rust_build && \
    cargo build --release && \
    mkdir -p /home/irisowner/dev/build/rust && \
    cp target/release/gaia_engine /home/irisowner/dev/build/rust/gaia_engine && \
    chmod +x /home/irisowner/dev/build/rust/gaia_engine && \
    rm -rf /tmp/rust_build

USER irisowner
WORKDIR /home/irisowner/dev

RUN --mount=type=bind,src=.,dst=/home/irisowner/dev \
    iris start IRIS && \
    iris session IRIS < iris.script && \
    iris stop IRIS quietly
