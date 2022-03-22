#!/bin/sh
CONFIGURATION="$HOME/Desktop/totp_key.txt"
if [ -z $1 ]; then
  echo "Usage:"
  echo "   otp google"
  echo
  echo "Configuration: $CONFIGURATION"
  echo "Format: name=key"
  echo "Services:"
  sed 's/=.*//; s/^/   /' $CONFIGURATION
  echo
  exit
fi
OTPKEY="$(sed -n "s/${1}=//p" $CONFIGURATION)"
if [ -z "$OTPKEY" ]; then
  echo "$(basename $0): Bad Service Name '$1'"
  $0
  exit
fi
oathtool --totp -b "$OTPKEY"
