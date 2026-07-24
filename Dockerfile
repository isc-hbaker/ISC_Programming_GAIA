FROM ubuntu:24.04

RUN apt-get update && apt-get install -y curl build-essential && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/gaia

COPY . /opt/gaia

CMD ["/bin/bash"]
