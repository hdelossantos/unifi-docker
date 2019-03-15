#!/usr/bin/env bash

# fail on error
set -e

# Retry 5 times with a wait of 10 seconds between each retry
tryfail() {
    for i in $(seq 1 5);
        do [ $i -gt 1 ] && sleep 10; $* && s=0 && break || s=$?; done;
    (exit $s)
}

# Try multiple keyservers in case of failure
addKey() {
    for server in $(shuf -e ha.pool.sks-keyservers.net \
        hkp://p80.pool.sks-keyservers.net:80 \
        keyserver.ubuntu.com \
        hkp://keyserver.ubuntu.com:80 \
        pgp.mit.edu) ; do \
        if apt-key adv --keyserver "$server" --recv "$1"; then
            exit 0
        fi
    done
    return 1
}

if [ "x${1}" == "x" ]; then
    echo please pass PKGURL as an environment variable
    exit 0
fi

apt-get update
apt-get install -qy --no-install-recommends \
    apt-transport-https \
    curl \
    openjdk-8-jre-headless \
    procps \
    libcap2-bin

curl -O http://downloads.mongodb.org/linux/mongodb-linux-i686-3.2.22.tgz
tar -zxvf mongodb-linux-i686-3.2.22.tgz
cp mongodb-linux-i686-3.2.22/bin/* /usr/bin/

curl https://raw.githubusercontent.com/mongodb/mongo/master/debian/init.d > init.d
mv init.d /etc/init.d/mongod
chmod 755 /etc/init.d/mongod

cat << MONGO_CONF >> /etc/mongod.conf
storage:
  dbPath: /var/lib/mongo
  journal:
    enabled: true
  engine: mmapv1
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
processManagement:
  fork: true
net:
  port: 27017
  bindIp: 0.0.0.0
MONGO_CONF

useradd --home-dir /var/lib/mongo --shell /bin/false mongodb

mkdir /var/lib/mongo
chown -R mongodb /var/lib/mongo
chgrp -R mongodb /var/lib/mongo

mkdir /var/log/mongodb
chown -R mongodb /var/log/mongodb
chgrp -R mongodb /var/log/mongodb

touch /var/run/mongod.pid
chown mongodb /var/run/mongod.pid
chgrp mongodb /var/run/mongod.pid

update-rc.d mongod defaults

apt-get update
echo "deb http://www.ubnt.com/downloads/unifi/debian unifi5 ubiquiti" > /etc/apt/sources.list.d/20ubiquiti.list
tryfail apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv C0A52C50
curl -L -o ./unifi.deb "${1}"
apt -qy install ./unifi.deb
rm -f ./unifi.deb
chown -R unifi:unifi /usr/lib/unifi
rm -rf /var/lib/apt/lists/*

rm -rf ${ODATADIR} ${OLOGDIR}
mkdir -p ${DATADIR} ${LOGDIR}
ln -s ${DATADIR} ${BASEDIR}/data
ln -s ${RUNDIR} ${BASEDIR}/run
ln -s ${LOGDIR} ${BASEDIR}/logs
rm -rf {$ODATADIR} ${OLOGDIR}
ln -s ${DATADIR} ${ODATADIR}
ln -s ${LOGDIR} ${OLOGDIR}
mkdir -p /var/cert ${CERTDIR}
ln -s ${CERTDIR} /var/cert/unifi

rm -rf "${0}"
