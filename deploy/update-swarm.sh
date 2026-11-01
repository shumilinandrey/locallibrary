#!/usr/bin/env bash
set -euo pipefail

IMAGE="ghcr.io/shumilinandrey/locallibrary:latest"
SERVICE="library_web"

echo "Checking GHCR for a new image..."

# Download current latest image without changing the service.
docker pull --quiet "$IMAGE" >/dev/null

# Get the immutable digest of the downloaded image.
NEW_IMAGE=$(docker image inspect \
  --format '{{index .RepoDigests 0}}' "$IMAGE")

# Get the image currently configured in Swarm.
CURRENT_IMAGE=$(docker service inspect \
  --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' "$SERVICE")

# Compare image digests, not just the latest tag.
NEW_DIGEST="${NEW_IMAGE##*@}"
CURRENT_DIGEST="${CURRENT_IMAGE##*@}"

if [[ "$NEW_DIGEST" == "$CURRENT_DIGEST" ]]; then
  echo "Already up to date: $NEW_DIGEST"
  exit 0
fi

echo "New image detected: $NEW_DIGEST"
echo "Updating $SERVICE..."

docker service update \
  --image "$NEW_IMAGE" \
  --detach=false \
  "$SERVICE"

echo "Checking the deployed image..."
DEPLOYED_IMAGE=$(docker service inspect \
  --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' "$SERVICE")

if [[ "${DEPLOYED_IMAGE##*@}" != "$NEW_DIGEST" ]]; then
  echo "ERROR: desired image was not deployed."
  exit 1
fi

echo "Deployment finished: $NEW_DIGEST"
