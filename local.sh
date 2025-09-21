#!/bin/bash


testing-farm request --compose RHEL-8.10.0-Nightly \
    --git-url https://github.com/tomasfratrik/infra.leapp \
    --git-ref main \
    --no-wait \
    -e 'SR_ANSIBLE_VER=""' \
    -e 'SR_EXCLUDED_TESTS=""' \
    -e 'SR_ONLY_TESTS=""' \
    --tag user=tfratrik \
    --plan plans/general

