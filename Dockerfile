ARG ARCH="amd64"
ARG OS="linux"
FROM        quay.io/prometheus/busybox-${OS}-${ARCH}:latest
MAINTAINER  Daniel Qian <qsj.daniel@gmail.com>

ARG ARCH="amd64"
ARG OS="linux"
COPY build/${OS}-${ARCH}/kafka_exporter /bin/kafka_exporter

EXPOSE     9308
ENTRYPOINT [ "/bin/kafka_exporter" ]