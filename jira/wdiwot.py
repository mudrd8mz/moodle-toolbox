#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
wdiwot - What Did I Work On Today?

Run wdiwot.py to query the Moodle Tracker for the list of issues you
looked at today.

2019 David Mudrák <david@moodle.com> - GNU GPL v3 or later
"""

import sys
import requests
import json

user = "<put your moodle tracker username here>"
passwd = "<put your moodle tracker password here>"

params = {
    "jql": "issue IN issueHistory() AND updated >= -16h ORDER BY updated",
    "fields": "key,summary"
}

headers = {
    "content-type": "application/json"
}

response = requests.get(
    url = "https://tracker.moodle.org/rest/api/2/search",
    params = params,
    auth = requests.auth.HTTPBasicAuth(user, passwd),
    headers = headers
)

response.raise_for_status()

data = response.json()

for item in data["issues"]:
    print item["key"],item["fields"]["summary"]
