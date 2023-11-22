#!/bin/bash
set -e

PROG="$(basename "$0")"

printUsage() {
    echo "Usage: $PROG ENTITY-ID ENDPOINT-URL"
    echo ""
    echo "Example:"
    echo "  $PROG urn:someservice https://sp.example.org/mellon"
    echo ""
}

if [ "$#" -lt 2 ]; then
    printUsage
    exit 1
fi

ENTITYID="$1"
if [ -z "$ENTITYID" ]; then
    echo "$PROG: An entity ID is required." >&2
    exit 1
fi

BASEURL="$2"
if [ -z "$BASEURL" ]; then
    echo "$PROG: The URL to the MellonEndpointPath is required." >&2
    exit 1
fi

if ! echo "$BASEURL" | grep -q '^https\?://'; then
    echo "$PROG: The URL must start with \"http://\" or \"https://\"." >&2
    exit 1
fi

# Récupération de l'argument pour définir si métadata dans un fichier ou en env vars
METADATA_SRC="$3"

HOST="$(echo "$BASEURL" | sed 's#^[a-z]*://\([^:/]*\).*#\1#')"
BASEURL="$(echo "$BASEURL" | sed 's#/$##')"

#OUTFILE="$(echo "$ENTITYID" | sed 's/[^0-9A-Za-z.]/_/g' | sed 's/__*/_/g')"
OUTFILE="/opt/bitnami/mellon/saml/mellon_metadata"
echo "Output files:"
echo "Private key:               $OUTFILE.key"
echo "Certificate:               $OUTFILE.cert"
echo "Metadata:                  $OUTFILE.xml"
echo
echo "Host:                      $HOST"
echo
echo "Endpoints:"
echo "SingleLogoutService:       $BASEURL/logout"
echo "AssertionConsumerService:  $BASEURL/postResponse"
echo

# No files should not be readable by the rest of the world.
umask 0077

#openssl req -utf8 -batch -config "$TEMPLATEFILE" -new -x509 -days 3652 -nodes -out "$OUTFILE.cert" -keyout "$OUTFILE.key" 2>/dev/null
if [ "${METADATA_SRC}" = FILE ]
then
  cp "${MELLON_METADATA_CERTIFICATE_FILE}" "${OUTFILE}.tmp.cert"
  cp "${MELLON_METADATA_PRIVATE_KEY_FILE}" "${OUTFILE}.tmp.key"
else
  echo "${MELLON_METADATA_CERTIFICATE}" > "${OUTFILE}.tmp.cert"
  echo "${MELLON_METADATA_PRIVATE_KEY}" > "${OUTFILE}.tmp.key"
fi
# Vérification de compatibilité entre certificats et PK
echo "Vérification de compatibilité entre certificats et PK..."
MODULUS_CERT=$(openssl x509 -noout -modulus -in "${OUTFILE}.tmp.cert" | openssl md5)
MODULUS_KEY=$(openssl rsa -noout -modulus -in "${OUTFILE}.tmp.key" | openssl md5)

if [ "${MODULUS_CERT}" != "${MODULUS_KEY}" ]; then
    echo "--> Le certificat et la clé privée ne sont pas compatibles. Vérifiez les variable MELLON_METADATA_CERTIFICATE / MELLON_METADATA_PRIVATE_KEY ou MELLON_METADATA_CERTIFICATE_FILE / MELLON_METADATA_PRIVATE_KEY_FILE." >&2
    exit 1
fi

# On copie les fichiers sous leur format final
echo "--> Certificats et PK Mellon valides. Ils sont importés dans la configuration."
mv "${OUTFILE}.tmp.cert" "${OUTFILE}.cert"
mv "${OUTFILE}.tmp.key" "${OUTFILE}.key"

CERT="$(grep -v '^-----' "${OUTFILE}.cert")"

cat >"${OUTFILE}.xml" <<EOF
<EntityDescriptor entityID="$ENTITYID" xmlns="urn:oasis:names:tc:SAML:2.0:metadata" xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
  <SPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol" AuthnRequestsSigned="true">
    <KeyDescriptor use="signing">
      <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
        <ds:X509Data>
          <ds:X509Certificate>$CERT</ds:X509Certificate>
        </ds:X509Data>
      </ds:KeyInfo>
    </KeyDescriptor>
    <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="$BASEURL/logout"/>
    <AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="$BASEURL/postResponse" index="0"/>
  </SPSSODescriptor>
</EntityDescriptor>
EOF

umask 0777
chmod go+r "$OUTFILE.xml"
chmod go+r "$OUTFILE.cert"

