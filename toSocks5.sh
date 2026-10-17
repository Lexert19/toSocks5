#!/usr/bin/env bash
set -euo pipefail

COUNT=1
PASSWORD=""
TYPES="vpngate,warp"
BASE_PORT=11080
USERNAME="sock5user"

usage() {
  echo "Usage: $0 -n <count> -p <password> [-t <types>] [-b <base_port>] [-u <username>]"
  exit 1
}

while getopts "n:p:t:b:u:h" opt; do
  case "$opt" in
    n) COUNT="$OPTARG" ;;
    p) PASSWORD="$OPTARG" ;;
    t) TYPES="$OPTARG" ;;
    b) BASE_PORT="$OPTARG" ;;
    u) USERNAME="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [[ -z "$PASSWORD" ]]; then
  echo "Error: password is required (-p)" >&2
  usage
fi

IFS=',' read -ra TYPE_ARRAY <<< "$TYPES"
CURRENT_PORT="$BASE_PORT"

for TYPE in "${TYPE_ARRAY[@]}"; do
  case "$TYPE" in
    vpngate)
      IMAGE="zhengxiongzhao/vpngate:latest"
      EXTRA_ENV=(
        -e "INITIAL_ADMIN_USERNAME=${USERNAME}"
        -e "INITIAL_ADMIN_PASSWORD=${PASSWORD}"
      )
      CONTAINER_PORT="7928"
      ;;
    warp)
      IMAGE="caomingjun/warp:latest"
      GOST_ARGS="-L socks5://${USERNAME}:${PASSWORD}@:1080"
      EXTRA_ENV=(
        -e "GOST_ARGS=${GOST_ARGS}"
      )
      CONTAINER_PORT="1080"
      ;;
    *)
      echo "Error: unknown type: $TYPE" >&2
      exit 1
      ;;
  esac

  for ((i=1; i<=COUNT; i++)); do
    CONTAINER_NAME="${TYPE}-socks-${i}"
    HOST_PORT="$CURRENT_PORT"

    echo "Creating $CONTAINER_NAME: host port $HOST_PORT -> container port $CONTAINER_PORT"

    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

    docker run -d \
      --name "$CONTAINER_NAME" \
      --restart unless-stopped \
      --cap-add=NET_ADMIN \
      --device=/dev/net/tun \
      -p "${HOST_PORT}:${CONTAINER_PORT}" \
      "${EXTRA_ENV[@]}" \
      "$IMAGE"

    echo "Started $CONTAINER_NAME on host port $HOST_PORT"
    ((CURRENT_PORT++))
  done
done

echo "Done. Created $((COUNT * ${#TYPE_ARRAY[@]})) containers."