#!/bin/bash

# https://docs.aws.amazon.com/rolesanywhere/latest/userguide/authentication-sign-process.html
# https://nerdydrunk.info/aws:roles_anywhere

CERT_FILE="client.crt"
CERT_KEY_FILE="client.key"
PAYLOAD_FILE="curl_request.json"

region="eu-central-1"

amz_date=`date --utc +%Y%m%dT%H%M%SZ`

host="rolesanywhere.$region.amazonaws.com"

content_type="application/json"
amz_x509=`openssl x509 -in $CERT_FILE -outform der | base64 -w 0`

HttpRequestMethod="POST"
CanonicalUri="/sessions"
CanonicalQueryString=""

CanonicalHeaders="content-type:$content_type\nhost:$host\nx-amz-date:$amz_date\nx-amz-x509:$amz_x509\n"

SignedHeaders="content-type;host;x-amz-date;x-amz-x509"
Payload_Hash=`cat $PAYLOAD_FILE | openssl dgst -sha256  | cut -d " " -f 2`

CanonicalRequest="$HttpRequestMethod\n$CanonicalUri\n$CanonicalQueryString\n$CanonicalHeaders\n$SignedHeaders\n$Payload_Hash"
CanonicalRequestSha256=`echo -e -n "$CanonicalRequest" | openssl dgst -sha256 | sed 's/^.* //'`

algorithm="AWS4-X509-RSA-SHA256"
date_stamp=`date --utc +%Y%m%d`
credential_scope="$date_stamp/$region/rolesanywhere/aws4_request"

string_to_sign="$algorithm\n$amz_date\n$credential_scope\n$CanonicalRequestSha256"
signature=`echo -n -e "$string_to_sign" | openssl dgst -sha256 -sign client.key -hex | cut -d " " -f 2`

CertSerialHex=`openssl x509 -in $CERT_FILE -noout -serial | cut -d "=" -f 2`
CertSerialDec=`echo "ibase=16; $CertSerialHex" | bc`

authorization_header="$algorithm Credential=$CertSerialDec/$credential_scope, SignedHeaders=$SignedHeaders, Signature=$signature"

curl_response=$(
curl -s -X POST \
-H "host: ${host}" \
-H "content-Type: ${content_type}" \
-H "x-amz-date: ${amz_date}" \
-H "x-amz-x509: ${amz_x509}" \
-H "Authorization: ${authorization_header}" \
-d @$PAYLOAD_FILE \
https://${host}${CanonicalUri}
)

echo "$curl_response"



