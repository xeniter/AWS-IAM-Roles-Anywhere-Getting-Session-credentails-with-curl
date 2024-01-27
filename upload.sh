#!/bin/sh -u

# Upload a file to Amazon AWS S3 using Signature Version 4
# docs: https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html
# script taken from https://gist.github.com/vszakats/2917d28a951844ab80b1
# new base script based on https://stackoverflow.com/questions/1496453/uploading-to-amazon-s3-using-curl-libcurl
# and modified remove content length and set content hash to UNSIGNED-PAYLOAD

# modified to upload with temporary S3 IAM rolesanywhere credentials

DEBUG=""
USE_TEMPORY_IAM_AUTH="yes"
AWS_IAM_CREDENTIALS_FILE="s3_tmp_credentials.json"

# # for old fixed user method:
# AWS_ACCESS_KEY_ID="insere_user_id_here"
# AWS_SECRET_ACCESS_KEY="insere_access_key_here"
    
# Usage: ./s3_upload.sh LocalFile RemoteFile bucket region(optional,default:eu-central-1)
################################################################################

show_help() {
   echo "Usage:"
   echo "$0 localfile remotefile bucket region(optional,default:eu-central-1)"
   echo "Uploads [locafile] to [bucket] at [remotefile] destination"
   echo "$0 stdin remotefile bucket region(optional,default:eu-central-1)"
   echo "Uploads stdin to [bucket] at [remotefile] destination"
   echo ""
}

# checking parameters
########################
if [[ $# == 0 ]] || [[ $# -gt 4 ]]; then
   show_help
   exit 0
fi

fileLocal="${1:-example-local-file.ext}"
fileRemote="${2:-${fileLocal}}"
bucket=${3:-}
region=${4:-eu-central-1}

security_token_header=""
security_token_signed_header=""
awsToken=""

write_new_s3_tmp_credential_file() {
    request.sh > $AWS_IAM_CREDENTIALS_FILE
}

if [[ -n "$USE_TEMPORY_IAM_AUTH" ]]; then
    # check if tempory S3 credential file exist already
    if [ -f "${AWS_IAM_CREDENTIALS_FILE}" ]; then
                
        # check if credential are still valid
        date_now=$(date --utc +"%s")
        date_req=$(cat $AWS_IAM_CREDENTIALS_FILE | jq -r '.credentialSet[0].credentials.expiration')
        # convert to unix timestamp
        date_regex="^([0-9]*)-([0-9]*)-([0-9]*)T([0-9]*):([0-9]*):([0-9]*)Z$"
        if [[ $date_req =~ $date_regex ]]; then
            YEAR=${BASH_REMATCH[1]}
            MONTH=${BASH_REMATCH[2]}
            DAY=${BASH_REMATCH[3]}
            HOUR=${BASH_REMATCH[4]}
            MIN=${BASH_REMATCH[5]}
            SEC=${BASH_REMATCH[6]}
            date_req_timestamp=$(date -d "$YEAR-$MONTH-$DAY $HOUR:$MIN:$SEC" +"%s")
            date_diff=$((date_now-date_req_timestamp))
           
            # request new credential if current are too old (~ more than 1hour(59min))
            if [ $date_diff -gt 3540 ]; then
                write_new_s3_tmp_credential_file
            fi
        else
            write_new_s3_tmp_credential_file
        fi
    else
        # if not request temporary credential
        write_new_s3_tmp_credential_file
    fi
    
    awsAccess=$(cat $AWS_IAM_CREDENTIALS_FILE | jq -r '.credentialSet[0].credentials.accessKeyId')
    awsSecret=$(cat $AWS_IAM_CREDENTIALS_FILE | jq -r '.credentialSet[0].credentials.secretAccessKey')
    awsToken=$(cat $AWS_IAM_CREDENTIALS_FILE | jq -r '.credentialSet[0].credentials.sessionToken')
    
    # for IAM / temporary credentials security token is required        
    security_token_header="x-amz-security-token:${awsToken}\n"
    security_token_signed_header=";x-amz-security-token"

else
     # old method with fix user and pass
    awsAccess="${AWS_ACCESS_KEY_ID}"
    awsSecret="${AWS_SECRET_ACCESS_KEY}"
fi

if [[ -n "$DEBUG" ]]; then
    echo "Uploading" "${fileLocal}" "->" "${bucket}" "${region}"
fi

yyyymmdd=`date +%Y%m%d`
isoDate=`date --utc +%Y%m%dT%H%M%SZ`
endpoint="s3-${region}.amazonaws.com"
contentHash="UNSIGNED-PAYLOAD"

if [[ $fileLocal != "stdin" ]]; then
    contentChksum=$(openssl dgst -sha256 -binary $fileLocal | base64)
    canonicalRequest="PUT\n/${bucket}/${fileRemote}\n\nhost:${endpoint}\nx-amz-checksum-sha256:${contentChksum}\nx-amz-content-sha256:${contentHash}\nx-amz-date:${isoDate}\n${security_token_header}\nhost;x-amz-checksum-sha256;x-amz-content-sha256;x-amz-date$security_token_signed_header\n${contentHash}"
else
    canonicalRequest="PUT\n/${bucket}/${fileRemote}\n\nhost:${endpoint}\nx-amz-content-sha256:${contentHash}\nx-amz-date:${isoDate}\n${security_token_header}\nhost;x-amz-content-sha256;x-amz-date${security_token_signed_header}\n${contentHash}"
fi
canonicalRequestHash=`echo -en ${canonicalRequest} | openssl sha256 -hex | sed 's/.* //'`

stringToSign="AWS4-HMAC-SHA256\n${isoDate}\n${yyyymmdd}/${region}/s3/aws4_request\n${canonicalRequestHash}"

if [[ -n "$DEBUG" ]]; then
    echo "----------------- canonicalRequest --------------------"
    echo -e ${canonicalRequest}
    echo "----------------- stringToSign --------------------"
    echo -e ${stringToSign}
    echo "-------------------------------------------------------"
fi

# calculate the signature keys for the date and the region for creating the SigningKey
DateKey=`echo -n "${yyyymmdd}" | openssl sha256 -hex -hmac "AWS4${awsSecret}" | sed 's/.* //'`
DateRegionKey=`echo -n "${region}" | openssl sha256 -hex -mac HMAC -macopt hexkey:${DateKey} | sed 's/.* //'`
DateRegionServiceKey=`echo -n "s3" | openssl sha256 -hex -mac HMAC -macopt hexkey:${DateRegionKey} | sed 's/.* //'`
SigningKey=`echo -n "aws4_request" | openssl sha256 -hex -mac HMAC -macopt hexkey:${DateRegionServiceKey} | sed 's/.* //'`
# then, once more a HMAC for the signature
signature=`echo -en ${stringToSign} | openssl sha256 -hex -mac HMAC -macopt hexkey:${SigningKey} | sed 's/.* //'`


# Upload file or data from stdin
if [[ $fileLocal == "stdin" ]]; then
    curl_param="--data-binary @-"
    authoriz="Authorization: AWS4-HMAC-SHA256 Credential=${awsAccess}/${yyyymmdd}/${region}/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date$security_token_signed_header, Signature=${signature}"
    curl_response=$(
    curl -X PUT \
    -s -o /dev/null -w '%{http_code}' \
    ${curl_param} \
    -H "Host: ${endpoint}" \
    -H "x-amz-date: ${isoDate}" \
    -H "x-amz-content-sha256: ${contentHash}" \
    -H "x-amz-security-token: ${awsToken}" \
    -H "${authoriz}" \
    https://${endpoint}/${bucket}/${fileRemote}
    )
else
    curl_param="-T ${fileLocal}"
    authoriz="Authorization: AWS4-HMAC-SHA256 Credential=${awsAccess}/${yyyymmdd}/${region}/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-checksum-sha256;x-amz-date$security_token_signed_header, Signature=${signature}"
    curl_response=$(
    curl -X PUT \
    -s -o /dev/null -w '%{http_code}' \
    ${curl_param} \
    -H "Host: ${endpoint}" \
    -H "x-amz-date: ${isoDate}" \
    -H "x-amz-content-sha256: ${contentHash}" \
    -H "x-amz-checksum-sha256: ${contentChksum}" \
    -H "x-amz-security-token: ${awsToken}" \
    -H "${authoriz}" \
    https://${endpoint}/${bucket}/${fileRemote}
    )
fi


if [[ -n "$DEBUG" ]]; then
    echo "curl response: $curl_response"
fi

if [[ "$curl_response" == "200" ]]; then
    exit 0
else
    echo "Upload error: $curl_response" 1>&2
    evctl report "s3_upload.sh:error:curl_response:$curl_response"
fi

exit 1
