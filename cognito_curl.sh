#!/usr/bin/env bash

# https://stackoverflow.com/a/49015716
#===============================================================================
# SET AUTH DOMAIN
#===============================================================================
AUTH_DOMAIN="MY-DOMAIN.auth.REGION.amazoncognito.com"

#===============================================================================
# AUTH CODE/IMPLICIT GRANTS, WITHOUT PKCE, WITHOUT CLIENT SECRET
#===============================================================================

## Set constants ##
CLIENT_ID="USER_POOL_CLIENT_ID"
RESPONSE_TYPE="code"
#RESPONSE_TYPE="token"
REDIRECT_URI="https://example.com/"
SCOPE="openid"

USERNAME="testuser"
PASSWORD="testpassword"

## Get CSRF token and LOGIN URL from /oauth2/authorize endpoint ##
curl_response="$(
    curl -qv "https://${AUTH_DOMAIN}/oauth2/authorize?response_type=${RESPONSE_TYPE}&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}" 2>&1
)"
curl_redirect="$(printf "%s" "$curl_response" \
                    | awk '/^< Location: / {
                        gsub(/\r/, ""); # Remove carriage returns
                        print $3;       # Print redirect URL
                    }')"
csrf_token="$(printf "%s" "$curl_response" \
                   | awk '/^< Set-Cookie:/ {
                       gsub(/^XSRF-TOKEN=|;$/, "", $3); # Remove cookie name and semi-colon
                       print $3;                        # Print cookie value
                    }')"

## Get auth code or tokens from /login endpoint ##
curl_response="$(
    curl -qv "$curl_redirect" \
        -H "Cookie: XSRF-TOKEN=${csrf_token}; Path=/; Secure; HttpOnly" \
        -d "_csrf=${csrf_token}" \
        -d "username=${USERNAME}" \
        -d "password=${PASSWORD}" 2>&1
)"
curl_redirect="$(printf "%s" "$curl_response" \
                    | awk '/^< Location: / {
                        gsub(/\r/, ""); # Remove carriage returns
                        print $3;       # Print redirect URL
                    }')"
auth_code="$(printf "%s" "$curl_redirect" \
                | awk '{
                    sub(/.*code=/, ""); # Remove everything before auth code
                    print;              # Print auth code
                }')"

## Get tokens from /oauth2/token endpoint ##
GRANT_TYPE="authorization_code"
curl "https://${AUTH_DOMAIN}/oauth2/token" \
    -d "grant_type=${GRANT_TYPE}" \
    -d "client_id=${CLIENT_ID}" \
    -d "code=${auth_code}" \
    -d "redirect_uri=${REDIRECT_URI}"

#===============================================================================
# AUTH CODE/IMPLICIT GRANTS, WITH PKCE, WITH CLIENT SECRET
#===============================================================================

## Set constants ##
CLIENT_ID="USER_POOL_CLIENT_ID"
CLIENT_SECRET="USER_POOL_CLIENT_SECRET"
RESPONSE_TYPE="code"
#RESPONSE_TYPE="token"
REDIRECT_URI="https://example.com/"
SCOPE="openid"

USERNAME="testuser"
PASSWORD="testpassword"

## Create a code_verifier and code_challenge ##
CODE_CHALLENGE_METHOD="S256"
# code_verifier = random, 64-char string consisting of chars between letters,
#                 numbers, periods, underscores, tildes, or hyphens; the string
#                 is then base64-url encoded
code_verifier="$(cat /dev/urandom \
                    | tr -dc 'a-zA-Z0-9._~-' \
                    | fold -w 64 \
                    | head -n 1 \
                    | base64 \
                    | tr '+/' '-_' \
                    | tr -d '='
                )"
# code_challenge = SHA-256 hash of the code_verifier; it is then base64-url
#                  encoded
code_challenge="$(printf "$code_verifier" \
                    | openssl dgst -sha256 -binary \
                    | base64 \
                    | tr '+/' '-_' \
                    | tr -d '='
                )"

## Get CSRF token from /oauth2/authorize endpoint ##
curl_response="$(
    curl -qv "https://${AUTH_DOMAIN}/oauth2/authorize?response_type=${RESPONSE_TYPE}&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&code_challenge_method=${CODE_CHALLENGE_METHOD}&code_challenge=${code_challenge}" 2>&1
)"
curl_redirect="$(printf "%s" "$curl_response" \
                    | awk '/^< Location: / {
                        gsub(/\r/, ""); # Remove carriage returns
                        print $3;       # Print redirect URL
                    }')"
csrf_token="$(printf "%s" "$curl_response" \
                | awk '/^< Set-Cookie:/ {
                    gsub(/^XSRF-TOKEN=|;$/, "", $3); # Remove cookie name and semi-colon
                    print $3;                        # Print cookie value
                }')"

## Get auth code or tokens from /login endpoint ##
curl_response="$(
    curl -qv "$curl_redirect" \
        -H "Cookie: XSRF-TOKEN=${csrf_token}; Path=/; Secure; HttpOnly" \
        -d "_csrf=${csrf_token}" \
        -d "username=${USERNAME}" \
        -d "password=${PASSWORD}" 2>&1
)"
curl_redirect="$(printf "%s" "$curl_response" \
                    | awk '/^< Location: / {
                        gsub(/\r/, ""); # Remove carriage returns
                        print $3;       # Print redirect URL
                    }'
                )"
auth_code="$(printf "%s" "$curl_redirect" \
                | awk '{
                    sub(/.*code=/, ""); # Remove everything before auth code
                    print;              # Print auth code
                }')"

## Get tokens from /oauth2/token endpoint ##
authorization="$(printf "${CLIENT_ID}:${CLIENT_SECRET}" \
                    | base64 \
                    | tr -d "\n" # Remove line feed
                )"
GRANT_TYPE="authorization_code"
curl "https://${AUTH_DOMAIN}/oauth2/token" \
    -H "Authorization: Basic ${authorization}" \
    -d "grant_type=${GRANT_TYPE}" \
    -d "client_id=${CLIENT_ID}" \
    -d "code=${auth_code}" \
    -d "redirect_uri=${REDIRECT_URI}" \
    -d "code_verifier=${code_verifier}"

#===============================================================================
# CLIENT CREDENTIALS GRANT
#===============================================================================

## Set constants ##
CLIENT_ID="USER_POOL_CLIENT_ID"
CLIENT_SECRET="USER_POOL_CLIENT_SECRET"
GRANT_TYPE="client_credentials"

## Get access token from /oauth2/token endpoint ##
authorization="$(printf "${CLIENT_ID}:${CLIENT_SECRET}" \
                    | base64 \
                    | tr -d "\n" # Remove line feed
                )"
curl "https://${AUTH_DOMAIN}/oauth2/token" \
    -H "Authorization: Basic ${authorization}" \
    -d "grant_type=${GRANT_TYPE}"

#===============================================================================
# LOGOUT
#===============================================================================

## Set constants ##
CLIENT_ID="USER_POOL_CLIENT_ID"
REDIRECT_URI="https://example.com/"

## Hit /logout endpoint ##
curl -v "https://${AUTH_DOMAIN}/logout?client_id=${CLIENT_ID}&logout_uri=${REDIRECT_URI}"
