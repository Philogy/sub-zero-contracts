#!/bin/bash

forge build
balls src/deploy-proxy/NonceIncreaser.balls -d -o src/deploy-proxy/NonceIncreaser.huff -m 6
balls src/deploy-proxy/DeployProxy.balls -d -o src/deploy-proxy/DeployProxy.huff -m 7
balls src/micro-create2/MicroCreate2.balls -d -o src/micro-create2/MicroCreate2.huff -m 6
