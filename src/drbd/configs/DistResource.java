/*
 * This file is part of DRBD Management Console by LINBIT HA-Solutions GmbH
 * written by Rasto Levrinc.
 *
 * Copyright (C) 2009, LINBIT HA-Solutions GmbH.
 *
 * DRBD Management Console is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as published
 * by the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * DRBD Management Console is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with drbd; see the file COPYING.  If not, write to
 * the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
 */

package drbd.configs;

import java.util.Arrays;

/**
 * Here are common commands for all linuxes.
 */
public class DistResource extends
            java.util.ListResourceBundle {

    /** Get contents. */
    protected final Object[][] getContents() {
        return Arrays.copyOf(contents, contents.length);
    }

    /** Contents. */
    private static Object[][] contents = {
        {"Support", "no"},
        {"arch:i686", "i386"}, // convert arch to arch in the drbd download file
        {"arch:x86_64", "x86_64"}, // convert arch to arch in the drbd download file
        {"distribution", "undefined"},

        /* This is used to find out which distribution on web page corresponds to which
         * distribution */
        {"dist:sles",                 "suse"},
        {"dist:suse",                 "suse"},
        {"dist:opensuse",             "suse"},
        {"dist:centos",               "rhel"},
        {"dist:fedora",               "redhat"},
        {"dist:rhas",                 "redhat"},
        {"dist:rhel",                 "rhel"},
        {"dist:fc",                   "fedora"},
        {"dist:debian-etch",          "debian"},
        {"dist:ubuntu",               "ubuntu"},
        {"dist:ubuntu-dapper-server", "ubuntu"},
        {"dist:ubuntu-hardy-server",  "ubuntu"},
        {"dist:ubuntu-jaunty-server",  "ubuntu"},

        {"kerneldir",                 "(.*)"},

        {"WhichDist",
         "uname; uname -m; uname -r;\n"
           + "for d in [ redhat debian gentoo SuSE ]; do \n"
           + "v=`head -1 -q /etc/\"$d\"_version /etc/\"$d\"-release 2>/dev/null`; \n"
           + "if [ ! -z \"$v\" ]; then echo \"$v\"; echo \"$d\"; fi; \n"
           + "done; lsb_release -i -r 2>/dev/null|sed 's/CentOS/redhat/'|sed 's/SUSE LINUX/suse/'|perl -lne 'print lc((split /:\\s*/)[1])' "},
        /* DrbdCheck.version has exit code != 0 if nothing is installed */
        {"DrbdCheck.version", "echo|drbdadm help | grep 'Version: '|sed 's/Version: //' | grep ."},
        //{ "HbCheck.version", ""},
        {"HbCheck.version", "/usr/lib/heartbeat/heartbeat -V 2>/dev/null || /usr/lib64/heartbeat/heartbeat -V"},
        {"HbGUICheck.version", "which hb_gui"},
        /* DrbdAvailableVersions returns available versions of drbd in the download area. One
         * version per line.
         *
         * example output:
         * -----
         * drbd-0.7.17
         * drbd-0.7.18
         * drbd-0.7.19
         * drbd-0.7.20
         * ------
         */
        {"DrbdAvailVersions",
         "/usr/bin/wget --no-check-certificate -q http://www.linbit.com/@SUPPORTDIR@/ -O - |perl -ple '($_) = /href=\"@DRBDDIR@-(\\d.*?)\\/\"/ or goto LINE'"
        },

        {"DrbdAvailDistributions",
         "/usr/bin/wget --no-check-certificate -q http://www.linbit.com/@SUPPORTDIR@/@DRBDDIR@-@DRBDVERSION@/ -O - |perl -ple '($_) = m!href=\"([^\"/]+)/\"! or goto LINE'"
        },

        {"DrbdAvailKernels",
         "/usr/bin/wget --no-check-certificate -q http://www.linbit.com/@SUPPORTDIR@/@DRBDDIR@-@DRBDVERSION@/@DISTRIBUTION@/ -O - |perl -ple '($_) = m!href=\"([^\"/]+)/\"! or goto LINE'"
        },

        {"DrbdAvailArchs",
         "/usr/bin/wget --no-check-certificate -q http://www.linbit.com/@SUPPORTDIR@/@DRBDDIR@-@DRBDVERSION@/@DISTRIBUTION@/@KERNELVERSIONDIR@/ -O - |perl -ple '($_) = m!href=\"drbd8?-(?:plus8?-)?(?:km|module)-.+?(i386|x86_64|amd64|i486|i686|k7)\\.(?:rpm|deb)\"! or goto LINE'"
        },

        {"DrbdAvailBuilds",
         "/usr/bin/wget --no-check-certificate -q http://www.linbit.com/@SUPPORTDIR@/@DRBDDIR@-@DRBDVERSION@/@DISTRIBUTION@/@KERNELVERSIONDIR@/ -O - |perl -ple '($_) = m!href=\"drbd8?-(?:plus8?-)?(?:km|module)-(.*?)[-_]@DRBDVERSION@.+?[._]@ARCH@\\..+?\"! or goto LINE'"
        },

        {"DrbdAvailVersionsForDist",
         "/usr/bin/wget --no-check-certificate -q http://www.linbit.com/@SUPPORTDIR@/@DRBDDIR@-@DRBDVERSION@/@DISTRIBUTION@/@KERNELVERSIONDIR@/ -O - |perl -ple '($_) = m!href=\"drbd8?-(?:plus8?-)?(?:utils_)?(\\d.*?)-\\d+[._]@ARCH@\\..+?\"! or goto LINE'"
        },

        {"DrbdAvailFiles",
         "/usr/bin/wget --no-check-certificate -q http://www.linbit.com/@SUPPORTDIR@/@DRBDDIR@-@DRBDVERSION@/@DISTRIBUTION@/@KERNELVERSIONDIR@/ -O - |perl -ple '($_) = m!href=\"(drbd8?-(?:plus8?-)?(?:utils)?(?:(?:km|module|utils)[_-]@BUILD@)?[-_]?@DRBDVERSION@.*?[._]@ARCH@\\.(?:rpm|deb))\"! or goto LINE'"
        },

        {"TestCommand", "uptime"},

        /* donwload and installation */
        {"DrbdInst.test",    "/bin/ls /tmp/drbdinst/@DRBDPACKAGE@ && /bin/ls /tmp/drbdinst/@DRBDMODULEPACKAGE@"},
        {"DrbdInst.mkdir",   "/bin/mkdir -p /tmp/drbdinst/"},
        {"DrbdInst.wget",    "/usr/bin/wget --no-check-certificate --progress=dot --http-user='@USER@' --http-passwd='@PASSWORD@' --directory-prefix=/tmp/drbdinst/ "
         + "http://www.linbit.com/@SUPPORTDIR@/@DRBDDIR@-@DRBDVERSION@/@DISTRIBUTION@/@KERNELVERSIONDIR@/@DRBDPACKAGE@ "
         + "http://www.linbit.com/@SUPPORTDIR@/@DRBDDIR@-@DRBDVERSION@/@DISTRIBUTION@/@KERNELVERSIONDIR@/@DRBDMODULEPACKAGE@"},
        {"DrbdInst.start",   "/etc/init.d/drbd start"},

        {"HbInst.authkeys", "if [ ! -e /etc/ha.d/authkeys ]; then printf 'auth 1\n1 crc\n# 2 sha1 ThisIsASampleKeyAnythingAlphaNumericIsGoodHere\n#3 md5 ThisIsASampleKeyAnythingAlphaNumericIsGoodHere' > /etc/ha.d/authkeys; fi"},

        {"installGuiHelper", "installGuiHelper"}, // is treated specially by ssh class.

        {"GetHostInfo", "/usr/local/bin/drbd-gui-helper all"},
        {"GetNetInfo",  "/usr/local/bin/drbd-gui-helper get-net-info"},

        /* heartbeat crm commands */
        {"Heartbeat.resourceList",      "cibadmin -Q"},
        {"Heartbeat.getStatus",         "cibadmin -Q --obj_type status"},
        {"Heartbeat.setParameter",      "crm_resource -r @ID@ --set-parameter "},
        //{"Heartbeat.addResource",       "cibadmin -C -o resources -X"},
        //{"Heartbeat.removeResource",    "crm_resource -D -r @ID@ -t @TYPE@"},
        //{"Heartbeat.cleanupResource",    "crm_resource -C -r @ID@ -t @TYPE@"},
        {"Heartbeat.addConstraint",     "cibadmin -C -o constraints -X '@XML@'"},
        //{"Heartbeat.startResource",     "crm_resource -r @ID@ -p target_role -v started"},
        //{"Heartbeat.stopResource",      "crm_resource -r @ID@ -p target_role -v stopped"},
        {"Heartbeat.migrateResource",   "crm_resource -r @ID@ -H @HOST@ --migrate"},
        {"Heartbeat.unmigrateResource", "crm_resource -r @ID@ --un-migrate"},

        /* gets all ocf resources and theirs meta-data */
        /* TODO: buggy xml in heartbeat 2.0.8 in ftp and mysql */
        /* TODO: implement version overwrite */
        {"Heartbeat.2.0.8.getOCFParameters", "export OCF_ROOT=/usr/lib/ocf; for s in `ls -1 /usr/lib/ocf/resource.d/heartbeat/ | grep -v Pure-FTPd|grep -v mysql`; do /usr/lib/ocf/resource.d/heartbeat/$s meta-data 2>/dev/null; done"},
        /* vmxpath env is needed so that vmware meta-data does not hang */
        {"Heartbeat.getOCFParameters", "export OCF_RESKEY_vmxpath=a;export OCF_ROOT=/usr/lib/ocf; for s in `ls -1 /usr/lib/ocf/resource.d/heartbeat/ `; do /usr/lib/ocf/resource.d/heartbeat/$s meta-data 2>/dev/null; done; /usr/local/bin/drbd-gui-helper get-old-style-resources; /usr/local/bin/drbd-gui-helper get-lsb-resources"},
        {"Heartbeat.getHbStatus",    "/usr/local/bin/drbd-gui-helper get-mgmt-events"},
        {"Heartbeat.start",          "/etc/init.d/heartbeat start"},
        {"Heartbeat.isStarted",      "/etc/init.d/heartbeat status > /dev/null"},
        {"Heartbeat.reloadHeartbeat", "/etc/init.d/heartbeat reload"},
        {"Heartbeat.stopHeartbeat",  "/etc/init.d/heartbeat stop"},
        {"Heartbeat.getHbConfig",    "cat /etc/ha.d/ha.cf"},
        {"Heartbeat.standByOn",      "crm_standby -U @HOST@ -v on"},
        {"Heartbeat.standByOff",     "crm_standby -U @HOST@ -v off"},


        /* drbd commands */
        //{"Drbd.getParameters", "for section in disk net syncer; do drbdsetup xml $section; done"},
        {"Drbd.getParameters", "/usr/local/bin/drbd-gui-helper get-drbd-xml"},
        //{"Drbd.getConfig",     "if [ -e /etc/drbd.conf ]; then /root/rastotest/drbdadm dump-xml || /sbin/drbdadm dump-xml ; fi"},
        //{"Drbd.getConfig",     "if [ -e /etc/drbd*.conf ]; then echo|/sbin/drbdadm dump-xml ; fi"},
        {"Drbd.getConfig",     "echo|/sbin/drbdadm dump-xml"},
        {"Drbd.getStatus",     "/usr/local/bin/drbd-gui-helper get-drbd-info"},

        {"DRBD.attach",        "echo|/sbin/drbdadm attach @RESOURCE@"},
        {"DRBD.detach",        "echo|/sbin/drbdadm detach @RESOURCE@"},
        {"DRBD.connect",       "echo|/sbin/drbdadm connect @RESOURCE@"},
        {"DRBD.disconnect",    "echo|/sbin/drbdadm disconnect @RESOURCE@"},
        {"DRBD.pauseSync",     "echo|/sbin/drbdadm pause-sync @RESOURCE@"},
        {"DRBD.resumeSync",    "echo|/sbin/drbdadm resume-sync @RESOURCE@"},
        {"DRBD.setPrimary",    "echo|/sbin/drbdadm primary @RESOURCE@"},
        {"DRBD.setSecondary",  "echo|/sbin/drbdadm secondary @RESOURCE@"},
        //{"DRBD.initDrbd",      "modprobe drbd; echo \"yes\"|/sbin/drbdadm create-md @RESOURCE@; drbdadm up @RESOURCE@"},
        {"DRBD.createMDDestroyData", "dd if=/dev/zero of=@DEVICE@ bs=1024 count=8; echo -e \"yes\\nyes\"|/sbin/drbdadm create-md @RESOURCE@"},
        {"DRBD.createMD",      "echo -e \"yes\\nyes\"|/sbin/drbdadm create-md @RESOURCE@"},
        {"DRBD.forcePrimary",  "echo|/sbin/drbdadm -- --overwrite-data-of-peer primary @RESOURCE@"},
        {"DRBD.invalidate",    "echo|/sbin/drbdadm invalidate @RESOURCE@"},
        {"DRBD.discardData",   "echo|/sbin/drbdadm -- --discard-my-data connect @RESOURCE@"},
        {"DRBD.resize",        "echo|/sbin/drbdadm resize @RESOURCE@"},
        //{"DRBD.getDrbdStatus", "/sbin/drbdsetup all events -a -u"},
        {"DRBD.getDrbdStatus", "/usr/local/bin/drbd-gui-helper get-drbd-events"},
        {"DRBD.adjust",        "if [ -e /proc/drbd ]; then echo|/sbin/drbdadm adjust @RESOURCE@; fi"},
        {"DRBD.adjust.dryrun", "echo|/sbin/drbdadm -d adjust @RESOURCE@"},
        {"DRBD.down",          "echo|/sbin/drbdadm down @RESOURCE@"},
        {"DRBD.up",            "echo|/sbin/drbdadm up @RESOURCE@"},
        {"DRBD.makeFilesystem", "/sbin/mkfs.@FILESYSTEM@ @DRBDDEV@"},

        {"DRBD.getProcDrbd",   "cat /proc/drbd"},
        {"DRBD.getProcesses",  "ps aux|grep drbd|grep -v python"},
        {"DRBD.start",         "/etc/init.d/drbd start"},
        {"DRBD.load",          "modprobe drbd"},
        {"DRBD.isModuleLoaded", "lsmod|grep drbd"},

        {"Heartbeat.getCrmMon",     "crm_mon -1"},
        {"Heartbeat.getProcesses",  "ps aux|grep heartbeat|grep -v regevt"},

        {"UdevCheck.version", "udevinfo -V 2>/dev/null | grep 'version '|sed 's/udevinfo, version //'"},
        
        {"Logs.hbLog",     "(grep @GREPPATTERN@ /var/log/ha.log 2>/dev/null || grep @GREPPATTERN@ /var/log/syslog)|tail -500"},
        {"DrbdLog.log",    "grep @GREPPATTERN@ /var/log/kern.log | tail -500"},
    };
}
