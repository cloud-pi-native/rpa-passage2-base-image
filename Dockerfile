FROM docker.io/bitnami/apache:2.4-debian-11 as base
RUN rm -Rf /var/www/html/*

FROM base as mellon

# Change user to perform privileged actions
USER 0

ENV APACHE_LOGS_DIR="/opt/bitnami/apache2/logs"
ENV APACHE_CONF_EXTRA="/opt/bitnami/apache/conf/extra"
ENV MELLON_ROOT_PATH="/opt/bitnami/mellon"

# Installation mellon et curl pour récupérer metadata IdP
RUN install_packages curl unzip jq vim libapache2-mod-auth-mellon curl libxml2-utils gettext-base &&\
    rm -rf /var/lib/apt/lists/* &&\
    apt purge &&\
    apt autoremove -y
RUN ln -s /usr/lib/apache2/modules/mod_auth_mellon.so /opt/bitnami/apache/modules/mod_auth_mellon.so

# Création des repertoires de travail mellon
RUN mkdir -p $MELLON_ROOT_PATH/saml &&\
    mkdir -p $MELLON_ROOT_PATH/scripts && \
    chmod a+w $MELLON_ROOT_PATH/saml

# Création des fichiers de logs
RUN touch "${APACHE_LOGS_DIR}/mellon_diagnostics"
RUN touch "${APACHE_LOGS_DIR}/mellon-error_log"
RUN touch "${APACHE_LOGS_DIR}/mellon-access_log" 
RUN chmod -R g+rwX "${APACHE_LOGS_DIR}" && chmod a+rwx ${APACHE_LOGS_DIR}/mellon*

RUN ln -sf "/dev/stdout" "${APACHE_LOGS_DIR}/mellon-access_log"
RUN ln -sf "/dev/stderr" "${APACHE_LOGS_DIR}/mellon_diagnostics"
RUN ln -sf "/dev/stderr" "${APACHE_LOGS_DIR}/mellon-error_log"

# Gestion du health_check pour le deploiement Kube
COPY conf/httpd.conf /opt/bitnami/apache/conf/httpd.conf
RUN mkdir /opt/bitnami/apache/cgi-bin
COPY conf/health_check.cgi /opt/bitnami/apache/cgi-bin/health_check.cgi
RUN chmod +x /opt/bitnami/apache/cgi-bin/health_check.cgi

# Modify the default container user
USER 1001

# Execution de notre entrypoint qui appelle le entrypoint par defaut apache
CMD [ "/opt/bitnami/scripts/apache/run.sh" ]
