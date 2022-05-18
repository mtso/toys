#!/bin/sh

../zig/zig build-exe -target x86_64-linux-gnu --name http src/main.zig
docker build -t mtso/devlog .

