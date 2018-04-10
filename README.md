# infra-dynamic-dns

This docker image provides a [bind service](https://www.isc.org/downloads/bind/) based on [Alpine Linux](https://hub.docker.com/_/alpine/) with dns updates via nsupdate.


NOTE: this image has the purpose of assisting the configuration of dns in testlabs, do not use in production.

## usage

```bash
docker run \
    -e ZONES="example.com" \
    -e REVERSE_ZONES="0.168.192" \
    -e FORWARDERS="8.8.8.8; 8.8.4.4;" \
    --publish 53:53/tcp --publish 53:53/udp \
    -d -t mycloudlab/infra-dynamic-dns 
```

Environment variables:

- **ZONES**: especify zones to be created, multiple zones is allowed. ex: ZONES="example.com; example2.com;"

- **REVERSE_ZONES**: especify reversed zones to be created, multiple zones is allowed. ex: REVERSE_ZONES="0.168.192; 99.168.192;"

- **FORWARDERS**: especify dns forwarder to be dispach queries, multiple forwarders is allowed. ex: FORWARDERS="8.8.8.8; 8.8.4.4;"

**Update dns records**

nsupdate should be used to update dns records. 

Example:

```bash
echo "
server localhost

; update zone with example.com
zone example.com
update del test.example.com. A
update add test.example.com 1440 A 192.168.0.1

; update reverse zone
zone 0.168.192.in-addr.arpa
update del 1.0.168.192.in-addr.arpa. PTR
update add 1.0.168.192.in-addr.arpa. 300 PTR test.example.com

show
send
" | nsupdate 
```

Test updates:

```bash
dig @localhost test.example.com +short
dig @localhost  -x 192.168.0.1 +short
```