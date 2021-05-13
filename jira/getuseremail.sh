#!/bin/bash

#
# Assuming you have a list of JIRA assignee exported in a TXT file (single column CSV), obtain the names and emails:
#
#   while read line; do echo -ne "$line\t"; ./getuseremail.sh $line; done < usernames.txt | tee emails.tsv
#

# Replace this with your actual tracker username and password
AUTH=username:password

DATA="username=$@"

curl -s -G -H "Content-Type: application/json" -u ${AUTH} --data-urlencode "${DATA}" https://tracker.moodle.org/rest/api/2/user | jq -r -M '.displayName + "\t" + .emailAddress' | sed 's/ at /@/' | sed 's/ dot /./g'
