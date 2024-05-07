#!/bin/bash
#Exit immediately on error
set -e

# Set script vars
source .env
DOCKER_TAG="npm-registry"

echo "Setting permissions"
ssh "$PI_USER@$PI_IP" "sudo mkdir -p /var/lib/verdaccio" || true
ssh "$PI_USER@$PI_IP" "sudo chmod -R 777 /var/lib/verdaccio"
ssh "$PI_USER@$PI_IP" "sudo mkdir -p /verdaccio/storage"
ssh "$PI_USER@$PI_IP" "sudo chown -R 10001:65533 /verdaccio/storage"

echo "Setting builder to mybuilder"
docker buildx use mybuilder

echo "Building target for arm64"
docker buildx build --platform linux/arm64 -t $DOCKER_TAG . --load

echo "Stopping old container"
ssh "$PI_USER@$PI_IP" "docker stop $DOCKER_TAG " || true

echo "Removing old container"
ssh "$PI_USER@$PI_IP" "docker container rm $DOCKER_TAG " || true

echo "Pushing new image"
docker save $DOCKER_TAG | bzip2 | ssh -l $PI_USER $PI_IP docker load

echo "Starting Container"
ssh "$PI_USER@$PI_IP" "docker run -d --network host -e VERDACCIO_PUBLIC_URL=$VERDACCIO_PUBLIC_URL -v /verdaccio/storage:/verdaccio/storage --restart unless-stopped --name $DOCKER_TAG \"$DOCKER_TAG\""

echo "Removing dangling images"
ssh "$PI_USER@$PI_IP" 'docker image rm $(docker images -f "dangling=true" -q)'