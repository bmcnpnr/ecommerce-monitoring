FROM prom/prometheus:v2.52.0 AS prometheus-validation

COPY prometheus /etc/prometheus
RUN promtool check config /etc/prometheus/prometheus.yml

FROM prom/alertmanager:v0.27.0 AS alertmanager-validation

COPY alertmanager/alertmanager.yml /etc/alertmanager/alertmanager.yml
RUN amtool check-config /etc/alertmanager/alertmanager.yml
