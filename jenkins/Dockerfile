# Jenkins LTS (versión fija) con el cliente de Docker y Docker Compose,
# para que los pipelines puedan construir imágenes y levantar contenedores.
FROM docker:28.5.2-cli AS dockercli

FROM jenkins/jenkins:2.580.2-lts-jdk21

USER root
# Cliente docker + plugins compose y buildx (binarios estáticos de la imagen oficial docker:cli)
COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=dockercli /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins
USER jenkins
