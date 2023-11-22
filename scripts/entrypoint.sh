#!/bin/bash

# Load libraries
. /opt/bitnami/scripts/liblog.sh

IDP_METADATA_XML_FILE=/opt/bitnami/mellon/saml/idp_metadata.xml

# Récupération des infos de l'IdP
debug "HTTP_PROXY: $HTTP_PROXY"
debug "HTTPS_PROXY: $HTTPS_PROXY"
debug "http_proxy: $http_proxy"
debug "https_proxy: $https_proxy"
info "Téléchargement du metadata de l'IDP: ${IDP_METADATA_URL}"
curl -k -o ${IDP_METADATA_XML_FILE} ${IDP_METADATA_URL} -vvv

if [ ! -f "${IDP_METADATA_XML_FILE}" ]; then
  error "${IDP_METADATA_XML_FILE} n'existe pas."
  exit 1;
fi

if [ "${BITNAMI_DEBUG}" = true ]
then
  # Activation 
  debug "Contenu du fichier '${IDP_METADATA_XML_FILE}': "
  echo "$(cat ${IDP_METADATA_XML_FILE})"
fi

if xmllint --noout ${IDP_METADATA_XML_FILE} > /dev/null 2>&1;
then
  info "Le metadata de l'IDP est un XML valide."
else
  error "Le metadata de l'IDP n'est pas un XML valide."
  exit 1;
fi

umask 0777
chmod go+r ${IDP_METADATA_XML_FILE}

#Initialisation des variables
fqdn="${SP_SERVER_NAME}"
SP_SERVER_PROTOCOL="${SP_SERVER_PROTOCOL:-https}"
mellon_endpoint_url="${SP_SERVER_PROTOCOL}://${fqdn}/mellon"
mellon_entity_id="${mellon_endpoint_url}/metadata"
file_prefix="$(echo "$mellon_entity_id" | sed 's/[^A-Za-z.]/_/g' | sed 's/__*/_/g')"

# Si la variable est définie et pointe vers un fichier
if [ ! -z "${MELLON_METADATA_CERTIFICATE_FILE}" ] && [ ! -z "${MELLON_METADATA_PRIVATE_KEY_FILE}" ] && [ -a "${MELLON_METADATA_CERTIFICATE_FILE}" ] && [ -a "${MELLON_METADATA_PRIVATE_KEY_FILE}" ]
then
  info "Les fichiers MELLON_METADATA_* existent : "
  info "MELLON_METADATA_CERTIFICATE_FILE : ${MELLON_METADATA_CERTIFICATE_FILE}"
  info "MELLON_METADATA_PRIVATE_KEY_FILE : ${MELLON_METADATA_PRIVATE_KEY_FILE}"

  # Appel du script
  info "Copy des métadatas mellon passées en paramètres (fichiers)."
  /opt/bitnami/mellon/scripts/mellon_copy_metadata.sh $mellon_entity_id $mellon_endpoint_url FILE

# Si la variable est vide ou non définie
elif [ -z "${MELLON_METADATA_CERTIFICATE}" ] && [ -z "${MELLON_METADATA_PRIVATE_KEY}" ]
then
    # Appel du script
    info "Génération automatique des métadatas mellon."
    /opt/bitnami/mellon/scripts/mellon_create_metadata.sh $mellon_entity_id $mellon_endpoint_url
else
    # Appel du script
    info "Copy des métadatas mellon passées en paramètres (env var)."
    /opt/bitnami/mellon/scripts/mellon_copy_metadata.sh $mellon_entity_id $mellon_endpoint_url ENV
fi

# activation du module diagnostics si MELLON_DIAGNOSTICS_ENABLE = true
debug "MELLON_DIAGNOSTICS_ENABLE => ${MELLON_DIAGNOSTICS_ENABLE}"
if [ "${MELLON_DIAGNOSTICS_ENABLE}" = true ]
then
    # Activation 
    info "Activation de la configuration 'MellonDiagnosticsEnable ON'"
    mv $APACHE_CONF_EXTRA/mellon-diagnostics.conf.disabled $APACHE_CONF_EXTRA/mellon-diagnostics.conf 
fi

# On génère la variable MELLON_HTTPS_ON (on | off) qui permet de définir 
# la config `SetEnv HTTPS "on"` ou `SetEnv HTTPS "off"`
if [ "${SP_SERVER_PROTOCOL}" = http ]
then
     # Désactivation 
    info "Désactivation de la configuration 'SSL ON'"
    #mv $APACHE_CONF_EXTRA/mellon-diagnostics.conf $APACHE_CONF_EXTRA/mellon-diagnostics.conf.disabled
    mv $APACHE_CONF_EXTRA/mellon-ssl.conf $APACHE_CONF_EXTRA/mellon-ssl.conf.disabled
fi

#On démarre apache avec l'entrypoint par défaut
exec /opt/bitnami/scripts/apache/entrypoint.sh "$@"
