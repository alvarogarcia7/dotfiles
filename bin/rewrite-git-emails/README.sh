#!/bin/bash

set -euxo pipefail

# 2026-01-12 19:08:20 AGB

uv init .

uv add git-filter-repo

source .venv/bin/activate
