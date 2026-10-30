FROM prom/prometheus:v2.52.0 AS prometheus-validation

COPY prometheus /etc/prometheus
RUN promtool check config /etc/prometheus/prometheus.yml
# Unit tests for the alert rules. Every rule added for the 2026-08-15 log explosion
# (and the ones fixed because they could never fire) has a case that makes it fire
# and one that must stay quiet; see prometheus/tests/.
RUN promtool test rules /etc/prometheus/tests/*.test.yml

FROM prom/alertmanager:v0.27.0 AS alertmanager-validation

COPY alertmanager/alertmanager.yml /etc/alertmanager/alertmanager.yml
RUN amtool check-config /etc/alertmanager/alertmanager.yml

# The log and trace stores carry the limits that bound their disk use, and a typo in
# one is only found when the container refuses to start. All three parse strictly:
# an unknown or misspelled key fails the build.
FROM grafana/loki:3.1.0 AS loki-validation

COPY loki/loki-config.yml /etc/loki/loki-config.yml
RUN ["/usr/bin/loki", "-config.file=/etc/loki/loki-config.yml", "-verify-config"]

FROM grafana/promtail:3.1.0 AS promtail-validation

COPY promtail/promtail-config.yml /etc/promtail/promtail-config.yml
RUN ["/usr/bin/promtail", "-config.file=/etc/promtail/promtail-config.yml", "-check-syntax"]

FROM grafana/tempo:2.5.0 AS tempo-validation

COPY tempo/tempo-config.yml /etc/tempo/tempo-config.yml
RUN ["/tempo", "-config.file=/etc/tempo/tempo-config.yml", "-config.verify=true"]
