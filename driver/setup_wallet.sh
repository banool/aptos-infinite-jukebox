#!/bin/bash

# $1 is the path where we'll run the CLI
# $2 is the private key

cd $1

if test -f ".aptos/config.yml"; then
    echo "Aptos CLI config already exists, exiting..."
    exit 0
fi

yes "" | aptos config init --private-key $2 --assume-yes