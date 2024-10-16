#!/bin/bash
#
# Copyright (C) 2019-present ScyllaDB
#

#
# SPDX-License-Identifier: AGPL-3.0-or-later
#

if [ ! -d /run/systemd/system ]; then
    exit 0
fi

# Install capabilities.conf when AmbientCapabilities supported
. /etc/os-release

# the command below will still work in systems without systemctl (like docker) and across all
# versions of systemd. We will set the version to 0 if systemctl is not found and then be able
# to use that in tests.
SYSTEMD_VER=$(( systemctl --version 2>/dev/null || echo 0 0) | head -n1 | awk '{print $2}')
RHEL=$(echo $ID $ID_LIKE | grep -oi rhel)
SYSTEMD_REL=0
if [ "$RHEL" ]; then
    SYSTEMD_REL=`rpm -q systemd --qf %{release}|sed -n "s/\([0-9]*\).*/\1/p"`
fi

AMB_SUPPORT=`grep -c ^CapAmb: /proc/self/status`

# AmbientCapabilities supported from v229 but it backported to v219-33 on RHEL7
if [ $SYSTEMD_VER -ge 229 ] || [[ $SYSTEMD_VER -eq 219 && $SYSTEMD_REL -ge 33 ]]; then
    if [ $AMB_SUPPORT -eq 1 ]; then
        mkdir -p /etc/systemd/system/scylla-server.service.d/
        cat << EOS > /etc/systemd/system/scylla-server.service.d/capabilities.conf
[Service]
AmbientCapabilities=CAP_SYS_NICE CAP_IPC_LOCK
EOS
    fi
fi

# For systems with not a lot of memory, override default reservations for the slices
# seastar has a minimum reservation of 1.5GB that kicks in, and 21GB * 0.07 = 1.5GB.
# So for anything smaller than that we will not use percentages in the helper slice
MEMTOTAL=$(cat /proc/meminfo |grep -e "^MemTotal:"|sed -s 's/^MemTotal:\s*\([0-9]*\) kB$/\1/')
MEMTOTAL_BYTES=$(($MEMTOTAL * 1024))
if [ $MEMTOTAL_BYTES -lt 23008753371 ]; then
    mkdir -p /etc/systemd/system/scylla-helper.slice.d/
    cat << EOS > /etc/systemd/system/scylla-helper.slice.d/memory.conf
[Slice]
MemoryHigh=1200M
MemoryMax=1400M
MemoryLimit=1400M
EOS

# On CentOS7, systemd does not support percentage-based parameter.
# To apply memory parameter on CentOS7, we need to override the parameter
# in bytes, instead of percentage.
elif [ "$RHEL" -a "$VERSION_ID" = "7" ]; then
    MEMORY_LIMIT=$((MEMTOTAL_BYTES / 100 * 5))
    mkdir -p /etc/systemd/system/scylla-helper.slice.d/
    cat << EOS > /etc/systemd/system/scylla-helper.slice.d/memory.conf
[Slice]
MemoryLimit=$MEMORY_LIMIT
EOS
fi

if [ -e /etc/systemd/system/systemd-coredump@.service.d/timeout.conf ]; then
    COREDUMP_RUNTIME_MAX=$(grep RuntimeMaxSec /etc/systemd/system/systemd-coredump@.service.d/timeout.conf)
    if [ -z $COREDUMP_RUNTIME_MAX ]; then
    cat << EOS > /etc/systemd/system/systemd-coredump@.service.d/timeout.conf
[Service]
RuntimeMaxSec=infinity
TimeoutSec=infinity
EOS
    fi
fi

systemctl --system daemon-reload >/dev/null || true
