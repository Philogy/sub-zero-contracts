#!/bin/bash

forge build

echo ""
echo ""
echo ""
echo "////////////////////////////////////////////////////////////////"
echo "//                      NONCE INCREASER                       //"
echo "////////////////////////////////////////////////////////////////"
balls src/deploy-proxy/NonceIncreaser.balls -d -o src/deploy-proxy/NonceIncreaser.huff -m 6
huffy src/deploy-proxy/NonceIncreaser.huff --avoid-push0

echo ""
echo ""
echo ""
echo "////////////////////////////////////////////////////////////////"
echo "//                        DEPLOY PROXY                        //"
echo "////////////////////////////////////////////////////////////////"
balls src/deploy-proxy/DeployProxy.balls -d -o src/deploy-proxy/DeployProxy.huff
huffy src/deploy-proxy/DeployProxy.huff --avoid-push0

echo ""
echo ""
echo ""
echo "////////////////////////////////////////////////////////////////"
echo "//                       MICRO CREATE2                        //"
echo "////////////////////////////////////////////////////////////////"
balls src/micro-create2/MicroCreate2.balls -d -o src/micro-create2/MicroCreate2.huff
huffy src/micro-create2/MicroCreate2.huff --avoid-push0
