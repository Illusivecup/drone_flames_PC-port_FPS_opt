#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
echo "==================================================="
echo "  DroneFlames PC Port - Test Version Builder"
echo "==================================================="
python3 build_test.py "$@"
