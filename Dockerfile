ARG TARGETARC
FROM        quay.io/prometheus/busybox-linux-${TARGETARCH}:latest
MAINTAINER  Daniel Qian <qsj.daniel@gmail.com>

ARG TARGETARCH
COPY .build/linux-${TARGETARCH}/kafka_exporter /bin/kafka_exporter

EXPOSE     9308
ENTRYPOINT [ "/bin/kafka_exporter" ]
