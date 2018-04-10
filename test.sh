#!/bin/bash

CONTAINER_NAME=$(uuidgen)

docker run -e ZONES="example.com" -e REVERSE_ZONES="0.168.192" --name="$CONTAINER_NAME" -d -t bind 
while [ $(docker logs $CONTAINER_NAME |grep 'Start named' | wc -l) -eq 0 ] ; do echo 'wait start bind...';   sleep 1; done
KEY_FILE=$(docker exec -i "$CONTAINER_NAME" ls /etc/bind/keys/ -1 | grep private)

function cleanup_and_exit() {
    docker rm -f $CONTAINER_NAME
    docker image prune -f
    exit 1;
}

echo "
server localhost
zone example.com
update del test.example.com. A
update add test.example.com 1440 A 192.168.0.1

zone 0.168.192.in-addr.arpa
update del 1.0.168.192.in-addr.arpa. PTR
update add 1.0.168.192.in-addr.arpa. 300 PTR test.example.com
show
send
" | docker exec -i $CONTAINER_NAME nsupdate -k "/etc/bind/keys/$KEY_FILE"

if [ "$(docker exec -i $CONTAINER_NAME dig @localhost test.example.com +short)" == "192.168.0.1" ]; then 
    echo [ok] - dns created with success
else 
    echo [fail] - dns test.example.com does not created
    cleanup_and_exit
fi

if [ "$(docker exec -i $CONTAINER_NAME dig @localhost -x 192.168.0.1 +short)" == "test.example.com." ]; then 
    echo [ok] - reverse dns created with success
else 
    echo [fail] - reverse dns for 192.168.0.1 does not pointer to test.example.com not created
    cleanup_and_exit
fi
