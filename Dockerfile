FROM docker.io/bitnami/apache:2.4-debian-11 as base
RUN rm -Rf /var/www/html/*

FROM base as mellon

# Change user to perform privileged actions
USER 0

ENV APACHE_LOGS_DIR="/opt/bitnami/apache2/logs"
ENV APACHE_CONF_EXTRA="/opt/bitnami/apache/conf/extra"
ENV MELLON_ROOT_PATH="/opt/bitnami/mellon"

# Installation mellon et curl pour récupérer metadata IdP
RUN install_packages libapache2-mod-auth-mellon curl libxml2-utils gettext-base &&\
    rm -rf /var/lib/apt/lists/* &&\
    apt purge &&\
    apt autoremove -y

# Création des repertoires de travail mellon
RUN mkdir -p $MELLON_ROOT_PATH/saml &&\
    mkdir -p $MELLON_ROOT_PATH/scripts && \
    chmod a+w $MELLON_ROOT_PATH/saml

# Copie des scripts pour générer les metadatas
COPY ./scripts/entrypoint.sh $MELLON_ROOT_PATH/scripts/entrypoint.sh
COPY ./scripts/mellon_create_metadata.sh $MELLON_ROOT_PATH/scripts/mellon_create_metadata.sh
COPY ./scripts/mellon_copy_metadata.sh $MELLON_ROOT_PATH/scripts/mellon_copy_metadata.sh

# Droits 0755 au scripts
RUN chmod a+rwx,g-w,o-w $MELLON_ROOT_PATH/scripts/*

# Copie de la conf apache et mellon
COPY ./pages/auth/redirect.html /opt/bitnami/apache/htdocs/auth/redirect.html
COPY ./conf/httpd.conf /opt/bitnami/apache2/conf/httpd.conf
COPY ./conf/mellon.conf /opt/bitnami/apache2/conf/extra/mellon.conf
COPY ./conf/mellon-diagnostics.conf /opt/bitnami/apache2/conf/extra/mellon-diagnostics.conf.disabled
COPY ./conf/mellon-ssl.conf /opt/bitnami/apache2/conf/extra/mellon-ssl.conf
COPY ./conf/mellon-user-attributes.conf /opt/bitnami/apache2/conf/extra/mellon-user-attributes.conf
RUN chmod a+rw,a-x,o-w /opt/bitnami/apache2/conf/extra/mellon-diagnostics.conf.disabled /opt/bitnami/apache2/conf/extra/mellon-ssl.conf /opt/bitnami/apache2/conf/extra/mellon.conf /opt/bitnami/apache2/conf/httpd.conf

# Création des fichiers de logs
RUN touch "${APACHE_LOGS_DIR}/mellon_diagnostics"
RUN touch "${APACHE_LOGS_DIR}/mellon-error_log"
RUN touch "${APACHE_LOGS_DIR}/mellon-access_log" 
RUN chmod -R g+rwX "${APACHE_LOGS_DIR}" && chmod a+rwx ${APACHE_LOGS_DIR}/mellon*

RUN ln -sf "/dev/stdout" "${APACHE_LOGS_DIR}/mellon-access_log"
RUN ln -sf "/dev/stderr" "${APACHE_LOGS_DIR}/mellon_diagnostics"
RUN ln -sf "/dev/stderr" "${APACHE_LOGS_DIR}/mellon-error_log"

# Modify the default container user
USER 1002

# Execution de notre entrypoint qui appelle le entrypoint par defaut apache
CMD [ "/opt/bitnami/mellon/scripts/entrypoint.sh", "/opt/bitnami/scripts/apache/run.sh" ]

