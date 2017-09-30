#!/bin/bash
#
# usage: ./run.sh [optional # of containers to create: default 3]
#
#  This script will launch the specified number of containers using el6,
# el7 and ub14 prebuilt images that are running sshd
#
set -e

NUM_TARGETS="${1:-3}"
REPO="${REPO:-ambakshi/}"
DOCKER_ARGS=(-d -t -e container=docker -v /sys/fs/cgroup:/sys/fs/cgroup:ro)

if ! test -e /var/run/docker.sock; then
    echo >&2 "Docker installation not found. See https://docker.com for instructions"
    exit 1
fi
if test -w /var/run/docker.sock; then
    docker=docker
else
    echo >&2 "WARNING: Your user is not a member of the docker group. Try 'sudo usermod -aG docker `id -un`'"
    echo >&2 "WARNING: to add your user to the docker group, then log out and back in. For now this script"
    echo >&2 "WARNING: will call docker using sudo"
    docker='sudo docker'
fi

OLDCONTAINERS=($($docker ps -a | grep target[1-9] | awk '{print $(NF)}'))
for container in "${OLDCONTAINERS[@]}"; do
    echo "Removing old container ${container} ..."
    $docker stop "$container" &>/dev/null || true
    $docker rm -fv "$container" &>/dev/null || true
done
rm -f hosts.txt

echo Launching $NUM_TARGETS containers ...
chmod 0600 developer_key
IMAGES=(el6-sshd el7-sshd ub14-sshd)
for ii in `seq 1 $NUM_TARGETS`; do
    idx=$(( $ii - 1 ))
    idx=$(( $idx % 3 ))
    img="${REPO}${IMAGES[$idx]}"
    echo "Updating ${img} ..."
    $docker pull "${img}" &>/dev/null || $docker pull "${img}"
    echo "Starting target$ii ($img) ..."
    case "${IMAGES[$idx]}" in
        el7-*) extra_args=(--cap-add=SYS_ADMIN);;
        *) extra_args=() ;;
    esac
    $docker run "${DOCKER_ARGS[@]}" "${extra_args[@]}" --hostname target$ii --name target$ii "$img" >/dev/null
    ipaddr="$($docker inspect --format '{{ .NetworkSettings.IPAddress }}' target$ii)"
    echo "target${ii}: ${ipaddr}"
    echo "${ipaddr}" >> hosts.txt
done

echo "Done!"

