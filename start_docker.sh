#!/bin/sh

podman run --rm -it --mount type=bind,source="$(pwd)",target=/app --workdir /app ubuntu:22.04 bash