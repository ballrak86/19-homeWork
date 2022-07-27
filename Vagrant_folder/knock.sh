#!/bin/bash
HOST=$1
shift
for ARG in "$@"
do
  nmap -Pn --max-retries 0 -p $ARG $HOST
done

