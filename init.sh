#!/bin/sh

#
# Script options (exit script on command fail).
#
set -e

CONFIG_DIR="/etc/bind"

#
# create default log file
#
mkdir -p /var/log/named

#
# generate keys
#
mkdir $CONFIG_DIR/keys
cd $CONFIG_DIR/keys
KEY_FILE=$(dnssec-keygen -a HMAC-MD5 -b 512 -n HOST server)
KEY=$(grep ^Key $KEY_FILE.private | awk '{split($0,v," "); print v[2]}')

#
# Create bind zones with variable
#
#ZONES="example.com,example2.com"
#REVERSE_ZONES="192.168.0.0/24,172.19.0.0/16"

for ZONE in $(echo $ZONES | tr "," "\n")
do 

# create zone default file
cat >$CONFIG_DIR/$ZONE.zone  <<EOL
\$ORIGIN $ZONE.
\$TTL 604800
; -----------------------------------------------------------------------------
; SOA for $ZONE
; -----------------------------------------------------------------------------

@ IN SOA ns1.$ZONE. hostmaster.$ZONE. (
  2016021501 ; Serial
  604800     ; Refresh
  86400      ; Retry
  2419200    ; Expire
  604800)   ; Negative Cache TTL

@ IN NS ns1.$ZONE.
ns1 IN A  172.17.0.2
EOL
    echo "> $ZONE"
done

#
# reverse zone
#
for ZONE in $(echo $REVERSE_ZONES | tr "," "\n")
do 

# create reverse zone default file
cat >$CONFIG_DIR/$ZONE.zone.reverse  <<EOL
\$ORIGIN .
\$TTL 604800
$ZONE.in-addr.arpa IN SOA ns1.example.com. hostmaster.example.com. (
  2016021502 ; Serial
  604800     ; Refresh
  86400      ; Retry
  2419200    ; Expire
  604800)   ; Negative Cache TTL
  NS ns1.$ZONE.
\$ORIGIN $ZONE.in-addr.arpa. 
EOL
    echo "> $ZONE"
done




cat >$CONFIG_DIR/named.conf  <<EOL

options {
    directory "/var/bind";
    version "private";
    listen-on port 53 { any; };
    listen-on-v6 { none; };
    allow-transfer { none; };
    pid-file "/var/run/named/named.pid";
    allow-recursion { any; };
    recursion yes;
    forwarders { $FORWARDERS };
};

logging {
    channel general {
        file "/var/log/named/general.log" versions 5;
        print-time yes;
        print-category yes;
        print-severity yes;
    };

    channel queries {
        file "/var/log/named/queries.log" versions 5 size 10m;
        print-time yes;
        print-category yes;
        print-severity yes;
    };

    channel security {
        file "/var/log/named/security.log" versions 5;
        print-time yes;
        print-category yes;
        print-severity yes;
    };

    category default { general; };
    category general { general; };
    category config { general; };
    category network { general; };
    category queries { queries; };
    category security { security; };
};
EOL

for ZONE in $(echo $ZONES | tr "," "\n")
do 
# register zone in named.conf
cat >> $CONFIG_DIR/named.conf  <<EOL
zone "$ZONE" IN {
    type master;
    file "/etc/bind/$ZONE.zone";
    allow-update { any; };
};
EOL
done


for ZONE in $(echo $REVERSE_ZONES | tr "," "\n")
do 
# register zone in named.conf
cat >> $CONFIG_DIR/named.conf  <<EOL
zone "$ZONE.in-addr.arpa" IN {
    type master;
    file "/etc/bind/$ZONE.zone.reverse";
    allow-update { any; };
};
EOL
done




#exit 0;

#
# Define default Variables.
#
USER="named"
GROUP="named"
COMMAND_OPTIONS_DEFAULT="-f"
NAMED_UID_DEFAULT="1000"
NAMED_GID_DEFAULT="101"
COMMAND="/usr/sbin/named -u ${USER} -c /etc/bind/named.conf ${COMMAND_OPTIONS:=${COMMAND_OPTIONS_DEFAULT}}"

NAMED_UID_ACTUAL=$(id -u ${USER})
NAMED_GID_ACTUAL=$(id -g ${GROUP})

#
# Display settings on standard out.
#
echo "named settings"
echo "=============="
echo
echo "  Username:        ${USER}"
echo "  Groupname:       ${GROUP}"
echo "  UID actual:      ${NAMED_UID_ACTUAL}"
echo "  GID actual:      ${NAMED_GID_ACTUAL}"
echo "  UID prefered:    ${NAMED_UID:=${NAMED_UID_DEFAULT}}"
echo "  GID prefered:    ${NAMED_GID:=${NAMED_GID_DEFAULT}}"
echo "  Command:         ${COMMAND}"
echo

#
# Change UID / GID of named user.
#
echo "Updating UID / GID... "
if [[ ${NAMED_GID_ACTUAL} -ne ${NAMED_GID} -o ${NAMED_UID_ACTUAL} -ne ${NAMED_UID} ]]
then
    echo "change user / group"
    deluser ${USER}
    addgroup -g ${NAMED_GID} ${GROUP}
    adduser -u ${NAMED_UID} -G ${GROUP} -h /etc/bind -g 'Linux User named' -s /sbin/nologin -D ${USER}
    echo "[DONE]"
    echo "Set owner and permissions for old uid/gid files"
    find / -user ${NAMED_UID_ACTUAL} -exec chown ${USER} {} \;
    find / -group ${NAMED_GID_ACTUAL} -exec chgrp ${GROUP} {} \;
    echo "[DONE]"
else
    echo "[NOTHING DONE]"
fi

#
# Set owner and permissions.
#
echo "Set owner and permissions... "
chown -R ${USER}:${GROUP} /var/bind /etc/bind /var/run/named /var/log/named
chmod -R o-rwx /var/bind /etc/bind /var/run/named /var/log/named
echo "[DONE]"

#
# Start named.
#
echo "Start named... "
exec ${COMMAND}
