#!/usr/bin/perl

# This file is part of Linux Cluster Management Console by Rasto Levrinc.
#
# Copyright (C) 2011 - 2012, Rastislav Levrinc.
# Copyright (C) 2009 - 2011, LINBIT HA-Solutions GmbH.
#
# DRBD Management Console is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# DRBD Management Console is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with drbd; see the file COPYING.  If not, write to
# the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

use strict;
use warnings;
$| = 1;

use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use POSIX qw(:errno_h); # EAGAIN
use Digest::MD5;

use Socket;

$ENV{LANG}="C";
$ENV{LANGUAGE}="C";
$ENV{LC_CTYPE}="C";
$ENV{PATH}="/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin"
	   .":/usr/bin:/bin:/usr/bin";
for (keys %ENV) {
	$ENV{$_} = "C" if /^LC_/;
}

{
	package Main;

	# options
	our $CMD_LOG_OP = "--cmd-log";
	our $LOG_TIME_OP = "--log-time";
	our $CMD_LOG_DEFAULT = 0;
	our $LOG_TIME_DEFAULT = 300;

	our $HW_INFO_INTERVAL = 10;
	our $DRBD_INFO_INTERVAL = 10;
	our $CLUSTER_INFO_INTERVAL = 10;
	our $OCF_DIR = "/usr/lib/ocf";
	our $OCF_RESOURCE_DIR = $OCF_DIR . "/resource.d";
	our $STONITH_ADMIN_PROG = "/usr/sbin/stonith_admin";
	our $VIRSH_COMMAND = "virsh -r";
	# --secure-info and -r don't work together
	our $VIRSH_COMMAND_NO_RO = "virsh";
	our $PCMK_SERVICE_AGENTS = "crm_resource --list-agents ";
	our $DRBD_PROXY_GET_PLUGINS = "drbd-proxy-ctl -c 'show avail-plugins'";
	our $DRBD_PROXY_SHOW = "drbd-proxy-ctl -c show";

	our $PROC_DRBD = "/proc/drbd";
	our @SERVICE_CLASSES = ("service", "systemd", "upstart");
	our @VM_OPTIONS = ("",
		"-c 'xen:///'",
		"-c lxc:///",
		"-c openvz:///system",
		"-c vbox:///session",
		"-c uml:///system");

	our $LV_CACHE;
	our $VG_CACHE;
	our $LVM_CACHE_FILE = "/tmp/lcmc.lvm.$$";
	our $LVM_ALL_CACHE_FILES = "/tmp/lcmc.lvm.*";
	our $NO_LVM_CACHE = 0;

	our %DISABLE_VM_OPTIONS; # it'll be populated for options that give an error

	start(\@ARGV);

	sub start {
		my $argv = shift || die;
		my ($helper_options, $action_options) = Options::parse($argv);
		my $do_log = $$helper_options{$CMD_LOG_OP} || $CMD_LOG_DEFAULT;
		my $log_time = $$helper_options{$LOG_TIME_OP} || $LOG_TIME_DEFAULT;
		Log::init($do_log, $log_time);
		my $action = shift @$action_options || die;
		if ($action eq "all") {
			clear_lvm_cache();
			print "net-info\n";
			print Network::get_net_info();
			print "disk-info\n";
			print get_disk_info($NO_LVM_CACHE);
			print "disk-space\n";
			print disk_space();
			print "vg-info\n";
			print get_vg_info($NO_LVM_CACHE);
			print "filesystems-info\n";
			print get_filesystems_info();
			print "crypto-info\n";
			print get_crypto_info();
			print "qemu-keymaps-info\n";
			print get_qemu_keymaps_info();
			print get_cpu_map_info();
			print "mount-points-info\n";
			print get_mount_points_info();
			print "drbd-proxy-info\n";
			print get_drbd_proxy_info();
			print "gui-info\n";
			print get_gui_info();
			print "installation-info\n";
			print get_installation_info();
			print "gui-options-info\n";
			print get_gui_options_info();
			print "version-info\n";
			print get_version_info();
		}
		elsif ($action eq "hw-info-daemon") {
			start_hw_info_daemon();
		}
		elsif ($action eq "hw-info") {
			print get_hw_info();
		}
		elsif ($action eq "hw-info-lvm") {
			clear_lvm_cache();
			print get_hw_info();
			print "vg-info\n";
			print get_vg_info($NO_LVM_CACHE);
			print "disk-info\n";
			print get_disk_info($NO_LVM_CACHE);
			print "disk-space\n";
			print disk_space();
		}
		elsif ($action eq "hw-info-lazy") {
			print get_hw_info_lazy();
		}
		elsif ($action eq "installation-info") {
			print get_installation_info();
		}
		elsif ($action eq "get-net-info") {
			print Network::get_net_info();
		}
		elsif ($action eq "get-disk-info") {
			print get_disk_info($NO_LVM_CACHE);
		}
		elsif ($action eq "get-vg-info") {
			print get_vg_info($NO_LVM_CACHE);
		}
		elsif ($action eq "get-filesystems-info") {
			print get_filesystems_info();
		}
		elsif ($action eq "get-crypto-info") {
			print get_crypto_info();
		}
		elsif ($action eq "get-qemu-keymaps-info") {
			print get_qemu_keymaps_info();
		}
		elsif ($action eq "get-cpu-map-info") {
			print get_cpu_map_info();
		}
		elsif ($action eq "get-drbd-proxy-info") {
			print get_drbd_proxy_info();
		}
		elsif ($action eq "get-gui-info") {
			print get_gui_info();
		}
		elsif ($action eq "get-mount-point-info") {
			print get_mount_points_info();
		}
		elsif ($action eq "get-drbd-info") {
			print get_drbd_info();
		}
		elsif ($action eq "get-drbd-events") {
			get_drbd_events();
		}
		elsif ($action eq "get-resource-agents") {
			get_resource_agents(@$action_options);
		}
		elsif ($action eq "get-old-style-resources") {
			get_old_style_resources(@$action_options);
		}
		elsif ($action eq "get-lsb-resources") {
			get_lsb_resources();
		}
		elsif ($action eq "get-stonith-devices") {
			get_stonith_devices(@$action_options);
		}
		elsif ($action eq "get-drbd-xml") {
			get_drbd_xml();
		}
		elsif ($action eq "get-cluster-events") {
			my $ret = get_cluster_events();
			if ($ret) {
				print "---start---\n";
				print "$ret\n";
				print "---done---\n";
				exit 1;
			}
		}
		elsif ($action eq "get-cluster-metadata") {
			get_cluster_metadata();
		}
		elsif ($action eq "get-cluster-versions") {
			print get_cluster_versions();
		}
		elsif ($action eq "get-vm-info") {
			print get_vm_info();
		}
		elsif ($action eq "gui-test") {
			Gui_Test::gui_pcmk_config_test(@$action_options);
			Gui_Test::gui_pcmk_status_test(@$action_options);
		}
		elsif ($action eq "gui-drbd-test") {
			Gui_Test::gui_drbd_test(@$action_options);
		}
		elsif ($action eq "gui-vm-test") {
			Gui_Test::gui_vm_test(@$action_options);
		}
		elsif ($action eq "proc-drbd") {
			get_proc_drbd();
		}
		elsif ($action eq "processed-log") {
			Log::processed_log();
		}
		elsif ($action eq "raw-log") {
			Log::raw_log();
		}
		elsif ($action eq "clear-log") {
			Log::clear_log();
		}
		else {
			die "unknown command: $action";
		}
	}

	# periodic stuff
	sub start_hw_info_daemon {
		my $prev_hw_info = 0;
		my $prev_hw_info_lazy = 0;
		my $prev_vm_info = 0;
		my $prev_drbd_info = 0;
		my $count = 0;
		my $use_lvm_cache = 0;
		while (1) {
			print "\n";
			if (!-e $LVM_CACHE_FILE) {
				$use_lvm_cache = 0;
				Command::_exec("touch $LVM_CACHE_FILE");
			}
			if ($count % 5 == 0) {
				my $hw_info = get_hw_info();
				$hw_info .= "vg-info\n";
				$hw_info .= get_vg_info($use_lvm_cache);
				$hw_info .= "disk-info\n";
				$hw_info .= get_disk_info($use_lvm_cache);
				if ($hw_info ne $prev_hw_info) {
					print "--hw-info-start--" . `date +%s%N`;
					print $hw_info;
					$prev_hw_info = $hw_info;
					print "--hw-info-end--\n";
				}
				$count = 0;
			}
			else {
				my $hw_info_lazy = get_hw_info_lazy();
				$hw_info_lazy .= "vg-info\n";
				$hw_info_lazy .= get_vg_info($use_lvm_cache);
				$hw_info_lazy .= "disk-info\n";
				$hw_info_lazy .= get_disk_info($use_lvm_cache);
				if ($hw_info_lazy ne $prev_hw_info_lazy) {
					print "--hw-info-start--" . `date +%s%N`;
					print $hw_info_lazy;
					print "--hw-info-end--\n";
					$prev_hw_info_lazy = $hw_info_lazy;
				}
			}
			$use_lvm_cache = 1;
			my $vm_info = get_vm_info();
			if ($vm_info ne $prev_vm_info) {
				print "--vm-info-start--" . `date +%s%N`;
				print $vm_info;
				print "--vm-info-end--\n";
				$prev_vm_info = $vm_info;
			}
			my $drbd_info = get_drbd_dump_xml();
			if ($drbd_info ne $prev_drbd_info) {
				print "--drbd-info-start--" . `date +%s%N`;
				print $drbd_info;
				print "--drbd-info-end--\n";
				$prev_drbd_info = $drbd_info;
			}
			sleep $HW_INFO_INTERVAL;
			$count++;
		}
	}

	sub get_hw_info {
		my $out = "net-info\n";
		$out .= Network::get_net_info();
		$out .= "filesystems-info\n";
		$out .= get_filesystems_info();
		$out .= "disk-space\n";
		$out .= disk_space();
		$out .= "crypto-info\n";
		$out .= get_crypto_info();
		$out .= "qemu-keymaps-info\n";
		$out .= get_qemu_keymaps_info();
		$out .= get_cpu_map_info();
		$out .= "mount-points-info\n";
		$out .= get_mount_points_info();
		$out .= "drbd-proxy-info\n";
		$out .= get_drbd_proxy_info();
		#$out .= "gui-info\n";
		#$out .= get_gui_info();
		$out .= "installation-info\n";
		$out .= get_installation_info();
		$out .= "version-info\n";
		$out .= get_version_info();
		return $out;
	}

	sub get_hw_info_lazy {
		my $out = "net-info\n";
		$out .= Network::get_net_info();
		$out .= "filesystems-info\n";
		$out .= get_filesystems_info();
		$out .= "disk-space\n";
		$out .= disk_space();
		$out .= "mount-points-info\n";
		$out .= get_mount_points_info();
		$out .= "installation-info\n";
		$out .= get_installation_info();
		$out .= "drbd-proxy-info\n";
		$out .= get_drbd_proxy_info();
		return $out;
	}

	sub get_drbd_info {
		print "--drbd-info-start--" . `date +%s%N`;
		print get_drbd_dump_xml();
		print "--drbd-info-end--\n";
	}

	sub get_drbd_dump_xml {
		return Command::_exec("/sbin/drbdadm -d dump-xml 2>&1");
	}

	# get_drbd_devs
	# Returns hash with drbd devices as keys and the underlying blockd evices as their
	# value.
	sub get_drbd_devs {
		my %drbd_devs;
		for (Command::_exec(
			qq(for f in `find /dev/drbd/by-disk/ -name '*' 2>/dev/null`;do
    			if [ -L \$f ]; then
    				echo -n "\$f ";
    				readlink -f \$f;
    			fi;
    	     	done))) {
			my ($dev, $drbd) = split;
			$dev =~ s!^/dev/drbd/by-disk/!/dev/!;
			$drbd_devs{$drbd} = $dev;
		}
		return \%drbd_devs;
	}


	# get_mount
	#
	# returns hash with block device as a key and mount point with filesystem as
	# value. LVM device name is converted to the /dev/group/name from
	# /dev/group-name. If there is - in the group or name, it is escaped as --, so
	# it is unescaped here. /bin/mount is used rather than cat /proc/mounts,
	# because in the output from /bin/mount is lvm device name always in the same
	# form.
	sub get_mount {
		my $drbd_devs = shift;
		my %dev_to_mount;
		for (Command::_exec("/bin/mount")) {
			# /dev/md1 on / type xfs (rw)
			# /dev/mapper/vg00--sepp-sources on /mnt/local-src type xfs (rw)
			if (m!/dev/(\S+)\s+on\s+(\S+)\s+type\s+(\S+)!) {
				my ($dev, $mountpoint, $filesystem) = ($1, $2, $3);
				$dev = "/dev/$dev";
				if ($$drbd_devs{"$dev"}) {
					$dev = $$drbd_devs{"$dev"};
				}
				if ($dev =~ m!^/dev/mapper/(.+)!) {
					# convert mapper/vg00--sepp-sources to vg00-sepp/sources
					my ($group, $name) = map {s/--/-/g;
						$_} $1 =~ /(.*[^-])-([^-].*)/;
					if ($group && $name) { # && !$$lvm_devs{"$group/$name"}) {
						$dev = "/dev/$group/$name";
					}
				}
				Log::print_debug("mount: $dev, $mountpoint, $filesystem");
				$dev_to_mount{$dev} = "$mountpoint fs:$filesystem";
			}
		}
		return \%dev_to_mount;
	}

	#
	# Returns hash with free disk space
	sub disk_space {
		my %dev_to_used;
		for (Command::_exec("/bin/df -Pl 2>/dev/null")) {
			if (m!(\S+)\s+\d+\s+\d+\s+\d+\s+(\d+)%\s+!) {
				my ($dev, $used) = ($1, $2);
				if ($dev =~ m!^/dev/mapper/(.+)!) {
					# convert mapper/vg00--sepp-sources to vg00-sepp/sources
					my ($group, $name) = map {s/--/-/g;
						$_} $1 =~ /(.*[^-])-([^-].*)/;
					if ($group && $name) { # && !$$lvm_devs{"$group/$name"}) {
						$dev = "/dev/$group/$name";
					}
				}
				$dev_to_used{$dev} = $used;
				print "$dev $used\n"
			}
		}
	}

	# get_swaps
	# returns hash with swaps as keys.
	sub get_swaps {
		open SW, "/proc/swaps" or Log::disk_info_error("cannot open /proc/swaps");
		my %swaps;
		while (<SW>) {
			next if /^Filename/; # header
			my ($swap_dev) = split;
			if ($swap_dev =~ m!^/dev/mapper/(.+)!) {
				# convert
				my ($group, $name) = map {s/--/-/g;
					$_} $1 =~ /(.*[^-])-([^-].*)/;
				if ($group && $name) {
					$swap_dev = "/dev/$group/$name";
				}
			}
			$swaps{$swap_dev}++;
		}
		return \%swaps;
	}

	# get_lvm
	#
	# returns 4 hashes. One hash that maps lvm group to the physical volume. A hash
	# that maps major and minor kernel numbers to the lvm device name. Major and
	# minor numbers are separated with ":". And a hash that contains block devices
	# that have lvm on top of them.
	sub get_lvm {
		my $use_cache = shift || 0;
		if ($use_cache && $LV_CACHE) {
			return @$LV_CACHE;
		}
		my $path = "/usr/sbin/";
		if (-e "/sbin/pvdisplay") {
			$path = "/sbin";
		}
		if (!-e "/sbin/pvdisplay" && !-e "/usr/sbin/pvdisplay") {
			return({}, {}, {}, {});
		}

		# create physical volume to volume group hash
		my %pv_to_group;
		for (Command::_exec("$path/pvdisplay -C --noheadings -o pv_name,vg_name 2>/dev/null")) {
			my ($pv_name, $vg_name) = split;
			$pv_name =~ s!^/dev/!!;
			Log::print_debug("pv: $pv_name, $vg_name");
			$pv_to_group{$pv_name} = $vg_name;
		}

		my %major_minor_to_dev;
		my %major_minor_to_group;
		my %major_minor_to_lv_name;

		# create major:minor kernel number to device hash
		for (Command::_exec("$path/lvdisplay -C --noheadings -o lv_kernel_major,lv_kernel_minor,vg_name,lv_name 2>/dev/null")) {
			my ($major, $minor, $group, $name) = split;
			Log::print_debug("get_lvm: ($major, $minor, $group, $name)");
			$major_minor_to_dev{"$major:$minor"} = "$group/$name";
			$major_minor_to_group{"$major:$minor"} = $group;
			$major_minor_to_lv_name{"$major:$minor"} = $name;
		}
		$LV_CACHE = [ \%pv_to_group,
			\%major_minor_to_dev,
			\%major_minor_to_group,
			\%major_minor_to_lv_name ];
		return @$LV_CACHE;
	}

	# this is used if the devices is dm but not lvm
	sub get_device_mapper_hash {
		my %major_minor_hash;
		my $dir = "/dev/mapper";
		if (opendir(DIR, $dir)) {
			for (grep {$_ !~ /^\./ && -b "$dir/$_"} readdir(DIR)) {
				my $out = Command::_exec("/sbin/dmsetup info $dir/$_ 2>&1");
				if ($out) {
					my ($major, $minor) =
						$out =~ /^Major.*?(\d+)\D+(\d+)/m;
					$major_minor_hash{"$major:$minor"} = "$dir/$_";
				}

			}
			closedir DIR;
		}
		return \%major_minor_hash;
	}

	# get_raid()
	#
	# returns hash with devices that are in the raid.
	sub get_raid {
		return if !-e "/proc/mdstat";
		open MDSTAT, "/proc/mdstat" or Log::disk_info_error("cannot open /proc/mdstat");
		# md1 : active raid1 sdb2[1] sda2[0]
		#	   9775488 blocks [2/2] [UU]
		my %devs_in_raid;

		# create hash with devices that are in the raid.
		while (<MDSTAT>) {
			if (/^(md\d+)\s+:\s+(.+)/ # old way
				|| /^(md_d\d+)\s+:\s+(.+)/) {
				my $dev = $1;
				my ($active, $type, @members) = split /\s+/, $2;
				Log::print_debug("get_raid: $dev ($active, $type, @members)");
				for my $member (@members) {
					$member =~ s/\[\d+\]$//;
					$devs_in_raid{"$member"}++;
				}
			}
		}
		return \%devs_in_raid;
	}

	sub get_device_mapper_major {
		my $m = 253;
		open DM, "/proc/devices" or Log::disk_info_error("cannot open /proc/devices");
		while (<DM>) {
			$m = $1 if /^(\d+)\s+device-mapper/;
		}
		close DM;
		return $m;
	}

	sub get_disk_uuid_map {
		my $dir = shift;
		my %ids;
		if (opendir(DIR, $dir)) {
			for (grep {$_ !~ /^\./ && -l "$dir/$_"} readdir(DIR)) {
				my $dev = Command::_exec("readlink -f \"$dir/$_\"", 2);
				chomp $dev;
				$ids{$dev} = "$dir/$_";
			}
			closedir DIR;
		}
		return \%ids;
	}

	sub get_disk_id_map {
		my $dir = shift;
		my %ids;
		if (opendir(DIR, $dir)) {
			for (grep {$_ !~ /^\./ && -l "$dir/$_"} readdir(DIR)) {
				my $dev = Command::_exec("readlink -f \"$dir/$_\"", 2);
				chomp $dev;
				push @{$ids{$dev}}, "$dir/$_";
			}
			closedir DIR;
		}
		return \%ids;
	}

	# get_disk_info()
	#
	# parses /proc/partitions and writes device and size of one block device per
	# line separated by one space. If block device is mounted, mount point and
	# file system type is attached.
	# It doesn't show block devices, that are in raid or there is lvm on top of
	# them. In this case only device names of raid or lvm are used.
	sub get_disk_info {
		my $use_lvm_cache = shift;
		my $devs_in_raid = get_raid();
		my ($pvs,
			$lvm_major_minor_to_dev,
			$lvm_major_minor_to_group,
			$lvm_major_minor_to_lv_name) = get_lvm($use_lvm_cache);
		my $dm_major_minor_to_dev = get_device_mapper_hash();
		my $drbd_devs = get_drbd_devs();
		my $dev_to_mount = get_mount($drbd_devs);
		my $dev_to_swap = get_swaps();
		# read partition table
		open PT, "/proc/partitions" or Log::disk_info_error("cannot open /proc/partitions");
		my $info;
		my $device_mapper_major = get_device_mapper_major();
		my $by_uuids = get_disk_uuid_map("/dev/disk/by-uuid");
		my $by_ids = get_disk_id_map("/dev/disk/by-id");
		while (<PT>) {
			next if /^major / || /^$/; # skip header
			chomp;
			my ($major, $minor, $blocks, $name) = split;
			next if $$devs_in_raid{$name};
			my $device;
			my $lvm_group;
			my $lv_name;
			if ($major == $device_mapper_major) {
				if ($$lvm_major_minor_to_dev{"$major:$minor"}) {
					$device = "/dev/" . $$lvm_major_minor_to_dev{"$major:$minor"};
					my $dev = $$lvm_major_minor_to_dev{"$major:$minor"};
					$dev = $name if !$dev;
					$device = "/dev/" . $dev;
					$lvm_group = $$lvm_major_minor_to_group{"$major:$minor"};
					$lv_name = $$lvm_major_minor_to_lv_name{"$major:$minor"};
				}
				elsif ($$dm_major_minor_to_dev{"$major:$minor"}) {
					$device =
						$$dm_major_minor_to_dev{"$major:$minor"};
					if ($device =~ /(-cow|-real)$/) {
						# skip snapshot devices.
						next;
					}
				}
				else {
					$device = "/dev/$name";
				}
			}
			elsif ($major == 1) {
				next; # ramdisk
			}
			elsif ($major == 7) {
				next; # loop device
			}
			elsif ($major == 3
				|| $major == 8
				|| $major == 72
				|| $major == 202
				|| $major == 104) { # ide and scsi disks
				# 104 cciss0
				if ($_ !~ /\d$/) { # whole disk
					$device = "/dev/$name";
				}
				elsif ($blocks == 1) { # extended partition
					next;
				}
				else {
					$device = "/dev/$name";
				}
			}
			elsif ($major == 9 || $major == 254) { # raid
				$device = "/dev/$name";
			}
			elsif ($name =~ /^drbd/) {
				$device = "/dev/$name";
			}
			else {
				Log::disk_info_warning("unknown partition: $_");
				$device = "/dev/$name";
			}
			my $readlink = Command::_exec("readlink -f $device", 2);
			chomp $readlink;
			my $dev_sec = $$by_uuids{$readlink} || $readlink || $device;

			my $mount = $$dev_to_mount{$device} || $$dev_to_mount{$dev_sec};
			my $swap = $$dev_to_swap{$device} || $$dev_to_swap{$dev_sec};

			my $disk_ids_s = "";

			my $disk_ids = $$by_ids{$readlink};
			if ($disk_ids) {
				for (@$disk_ids) {
					$disk_ids_s .= " disk-id:" . $_;
				}
			}

			$info .= "$device uuid:$dev_sec$disk_ids_s size:$blocks";
			$info .= " mp:$mount" if $mount;
			$info .= " fs:swap mp:swap" if $swap;
			$info .= " lv:" . $lv_name if defined $lv_name;
			$info .= " vg:" . $lvm_group if defined $lvm_group;
			$info .= " pv:" . $$pvs{$name} if defined $$pvs{$name};
			$info .= "\n";
		}
		close PT;

		return $info;
	}

	# returns volume group info
	sub get_vg_info {
		my $use_cache = shift || 0;
		if ($use_cache && defined $VG_CACHE) {
			return $VG_CACHE;
		}
		my $path = "/usr/sbin/";
		if (-e "/sbin/pvdisplay") {
			$path = "/sbin";
		}
		my $out = "";
		for (Command::_exec("$path/vgdisplay -C --noheadings --units b -o name,free 2>/dev/null")) {
			my ($name, $free) = split;
			$free =~ s/B$//;
			$out .= "$name $free\n";
		}
		$VG_CACHE = $out;
		return $out;
	}

	# get_filesystems_info
	#
	# prints available filesystems on this host.
	sub get_filesystems_info {
		my $out = "";
		for (Command::_exec("ls /sbin/mkfs.* 2>/dev/null")) {
			chomp;
			my ($fs) = /([^\.]+)$/;
			Command::_exec("/sbin/modinfo $fs >/dev/null 2>&1 || grep '\\<$fs\\>' /proc/filesystems", 2);
			$out .= "$fs\n" if !$?;
		}
		return $out;
	}

	# get_mount_points_info
	#
	# prints directories in the /mnt directory
	sub get_mount_points_info {
		my $dir = "/mnt";
		my $out = "";
		if (opendir(DIR, $dir)) {
			$out .= "$dir/$_\n" for (sort grep {$_ !~ /^\./ && -d "$dir/$_"} readdir(DIR));
			closedir DIR;
		}
		return $out;
	}

	# get_crypto_info
	#
	# prints available crypto modules on this host.
	sub get_crypto_info {
		my @modules;
		my %module_exists;
		for (Command::_exec("cat /proc/crypto")) {
			my ($cr) = /^name\s*:\s*(\S+)/;
			next if !$cr || $cr =~ /\(/ || $module_exists{$cr};
			push @modules, $cr;
			$module_exists{$cr}++;

		}
		for (Command::_exec("ls /lib/modules/`uname -r`/kernel/crypto/*.ko", 2)) {
			my ($cr) = /([^\/]+).ko$/;
			next if $module_exists{$cr};
			if ($cr eq "sha1" || $cr eq "md5" || $cr eq "crc32c") {
				unshift @modules, $cr;
			}
			else {
				push @modules, $cr;
			}
		}
		my $out = "";
		for (@modules) {
			$out .= "$_\n";
		}
		return $out;
	}

	# get_crypto_info
	#
	# prints available qemu keymaps.
	sub get_qemu_keymaps_info {
		my $out = "";
		for (Command::_exec("ls /usr/share/qemu*/keymaps/ 2>/dev/null")) {
			$out .= $_;
		}
		return $out;
	}

	sub get_cpu_map_info {
		my @models;
		my %vendors;
		if (open my $cpu_map_fh, "/usr/share/libvirt/cpu_map.xml") {
			while (<$cpu_map_fh>) {
				my ($model) = /<model\s+name=\'(.*)'>/;
				push @models, $model if $model;
				my ($vendor) = /<vendor>(.*)</
					|| /<vendor\s+name=\'(.*?)'.*\/>/;
				$vendors{$vendor} = 1 if $vendor;
			}
		}
		my $out = "";
		$out .= "cpu-map-model-info\n";
		for (@models) {
			$out .= "$_\n";
		}
		$out .= "cpu-map-vendor-info\n";
		for (sort keys %vendors) {
			$out .= "$_\n";
		}
		return $out;
	}

	# get_gui_info()
	#
	sub get_gui_info {
		my $out = "";
		if (open FH, "/var/lib/heartbeat/drbdgui.cf") {
			while (<FH>) {
				$out .= "$_";
			}
			close FH;
		}
		return $out;
	}

	# get_installation_info()
	#
	sub get_installation_info {
		my $out = get_cluster_versions();
		my $hn = Command::_exec("hostname");
		chomp $hn;
		$out .= "hn:$hn\n";
		return $out;
	}

	#
	# get_gui_options_info
	#
	sub get_gui_options_info {
		my $out = "o:vm.filesystem.source.dir.lxc\n";
		$out .= "/var/lib/lxc\n";
		$out .= Command::_exec("ls -1d /var/lib/lxc/*/rootfs 2>/dev/null");
		return $out;
	}

	#
	# get_version_info()
	#
	sub get_version_info {
		my $cmd =
			'uname; uname -m; uname -r; '
				. 'for d in redhat debian gentoo SuSE SUSE distro; do '
				. 'v=`head -1 -q /etc/"$d"_version /etc/"$d"-release /etc/"$d"-brand 2>/dev/null`; '
				. 'if [ ! -z "$v" ]; then echo "$v"; echo "$d"; fi; '
				. 'done |head -2'
				. '| sed "s/distro/openfiler/";'
				. 'lsb_release -i -r 2>/dev/null '
				. '| sed "s/centos/redhat/I"|sed "s/SUSE LINUX/suse/" '
				. '| sed "s/openSUSE project/suse/" '
				. '| sed "s/openSUSE$/suse/" '
				. '| sed "s/enterprise_linux\|ScientificSL/redhatenterpriseserver/" '
				. '| perl -lne "print lc((split /:\s*/)[1])"'
				. '| sed "s/oracleserver/redhat/"; '
				. 'cut -d ":" /etc/system-release-cpe -f 4,5 2>/dev/null|sed "s/:/\n/"'
				. '| sed "s/enterprise_linux/redhatenterpriseserver/" '
				. '| sed "s/centos/redhat/" ';
		return Command::_exec("$cmd");
	}

	sub get_drbd_events {
		my $kidpid;
		die "can't fork: $!" unless defined($kidpid = fork());
		if ($kidpid) {
			while (1) {
				do_drbd_events();
				sleep $DRBD_INFO_INTERVAL;
			}
		}
		else {
			while (1) {
				print "\n"; # reset timeout
				sleep $DRBD_INFO_INTERVAL;
			}
		}
	}

	sub do_drbd_events {
		if (!-e $PROC_DRBD) {
			print "--nm--\n";
			return;
		}
		my ($v1, $v2) = get_drbd_version();
		my $command;
		if ($v1 < 7 || ($v1 == 8 && $v2 < 4)) { # < 8.4.0
			$command = "/sbin/drbdsetup /dev/drbd0 events -a -u";
		}
		else {
			$command = "/sbin/drbdsetup all events";
		}
		my $prev_drbd_info = 0;
		if (!open EVENTS, "$command|") {
			Log::print_warning("can't execute $command\n");
			return;
		}
		else {
			while (<EVENTS>) {
				if ($_ && $_ !~ /\d+\s+(ZZ|\?\?)/) {
					my $drbd_info = get_drbd_dump_xml();
					if ($drbd_info ne $prev_drbd_info) {
						print "--drbd-info-start--"
							. `date +%s%N`;
						print $drbd_info;
						print "--drbd-info-end--\n";
						$prev_drbd_info = $drbd_info;
					}
					print "--event-info-start--" . `date +%s%N`;
					print "$_";
					print "--event-info-end--\n";
				}
			}
		}
		close EVENTS;
	}

	sub is_smaller_v {
		my $v = shift;
		my $than_v = shift;
		my @v_parts = split /\./, $v;
		my @than_v_parts = split /\./, $than_v;

		return 0 if @v_parts != @than_v_parts;

		for (@v_parts) {
			my $than_v_part = shift @than_v_parts;
			return 0 if $_ > $than_v_part;
			return 1 if $_ < $than_v_part;
		}
		return 0;
	}

	sub cib_message {
		my $socket = shift;
		my $msg = shift;
		$msg = ">>>\n$msg<<<\n";
		printf $socket pack "L", length $msg;
		printf $socket pack "L", 0xabcd;
		print $socket $msg;
	}

	#
	# Return heartbeat lib path. It can be /usr/lib/heartbeat or
	# /usr/lib64/heartbeat
	#
	sub get_hb_lib_path {
		my $arch = Command::_exec("uname -m", 2);
		chomp $arch;
		if ($arch eq "x86_64" && -e "/usr/lib64") {
			return "/usr/lib64/heartbeat";
		}
		return "/usr/lib/heartbeat";
	}

	sub get_crmd_lib_path {
		my $hb_lib_path = get_hb_lib_path();
		for ("/usr/lib64/pacemaker",
			"/usr/libexec/pacemaker",
			"/usr/lib/x86_64-linux-gnu/pacemaker",
			"/usr/lib/pacemaker",
			$hb_lib_path) {
			if (-e "$_/crmd") {
				return $_;
			}
		}
	}

	sub get_message {
		my $socket = shift;
		my $msg = "";
		while (<$socket>) {
			if ($_ eq "<<<\n") {
				return $msg;
			}
			if ($_ !~ />>>/) {
				$msg .= $_;
			}
		}
		die;
	}

	#
	# Prints cib info.
	#
	sub get_cluster_events {
		my $kidpid;
		die "can't fork: $!" unless defined($kidpid = fork());
		if ($kidpid) {
			# parent
			do_cluster_events();
			kill 1, $kidpid;
		}
		else {
			# kid
			while (1) {
				print "---reset---\n"; # reset timeout
				sleep $CLUSTER_INFO_INTERVAL;
			}
		}
	}

	sub do_cluster_events {
		my $libpath = get_hb_lib_path();
		my $hb_version = Command::_exec("$libpath/heartbeat -V 2>/dev/null") || "";
		my $info = get_cluster_info($hb_version);
		my $pcmk_path = "/usr/libexec/pacemaker:/usr/lib/heartbeat:/usr/lib64/heartbeat:/usr/lib/pacemaker:/usr/lib64/pacemaker:/usr/lib/x86_64-linux-gnu/pacemaker";
		my $command =
			"PATH=$pcmk_path exec cibmon -udVVVV -m1 2>&1";
		if ($hb_version && (compare_versions($hb_version, "2.1.4") <= 0)) {
			$command =
				" PATH=$pcmk_path exec cibmon -dV -m1 2>&1";
		}
		if ($info) {
			print "---start---\n";
			print $info;
			print "---done---\n";
			my $prev_info = 0;
			if (!open EVENTS, "$command|") {
				Log::print_warning("can't execute $command\n");
				return;
			}
			else {
				while (<EVENTS>) {
					# pcmk 1.1.8, it's an error, but
					# still indicates an event
					if (/signon to CIB failed/i) {
						print "ERROR: signon to CIB failed";
						return;
					}
					elsif (/error:/
						|| /Diff: ---/
						|| /Local-only Change:/) {
						my $cluster_info = get_cluster_info($hb_version);
						if ($cluster_info ne $prev_info) {
							print "---start---\n";
							print $cluster_info;
							print "---done---\n";
							$prev_info = $cluster_info;
						}
					}
				}
			}
		}
		else {
			print "ERROR: cib connection error";
		}
	}

	#
	# Get info from ptest and make xml from it. This is used only to find out
	# if a resource is running, not running and/or unmanaged
	# unmanaged etc.
	sub get_resource_status {
		my $hb_version = shift;
		my %role;
		my %unmanaged;
		my %resources;
		my @fenced_nodes;
		my $crm_simulate_prog = "/usr/sbin/crm_simulate";
		my $prog = "crm_simulate -s -S -VVVVV -L 2>&1";
		my $errors = ""; # TODO: error handling
		my $ptest_prog = "/usr/sbin/ptest";
		if (!-e $crm_simulate_prog && -e $ptest_prog) {
			if ($hb_version
				&& (compare_versions($hb_version, "2.1.4") <= 0)) {
				$prog = "$ptest_prog -S -VVVVV -L 2>&1";
			}
			else {
				$prog = "$ptest_prog -s -S -VVVVV -L 2>&1";
			}
			# default, because crm_simulate
			# crashes sometimes
			# older ptest versions don't have -s option
		}
		elsif (!-e $ptest_prog) {
			$errors .= "could not find $prog\n";
		}
		my %allocation_scores;
		for my $line (Command::_exec("$prog")) {
			my $what;
			my $on;
			my $res;
			if ($line =~ /pe_fence_node:\s+Node\s+(\S+)/) {
				push @fenced_nodes, $1;
			}
			elsif ($line =~
				/Leave\s+(?:resource\s+)?(\S+)\s+\((.*?)\)/) {
				# managed: Started, Master, Slave, Stopped
				$res = $1;
				my $state = $2;
				if ($res =~ /(.*):\d+$/) {
					$res = $1;
				}
				if ($state =~ /\s+unmanaged$/) {
					$unmanaged{$res}++;
				}
				else {
					if ($state =~ /^(Stopped)/) {
					}
					else {
						if ($state =~ /\s/) {
							($what, $on) =
								split /\s+/, $state;
						}
						else {
							$what = "started";
							$on = $state;
						}

					}
				}
			}
			elsif ($line
				=~ /Stop\s+resource\s+(\S+)\s+\((.*)\)/) {
				# Stop, is still slave or started
				$res = $1;
				$on = $2;
				if ($res =~ /(.*):\d+$/) {
					$res = $1;
					$what = "slave";
				}
				else {
					$what = "started";
				}
			}
			elsif ($line =~
				/Demote\s+(\S+)\s+\(Master -> \S+\s+(.*)\)/) {
				# Demote master -> *, still master
				$res = $1;
				$on = $2;
				if ($res =~ /(.*):\d+$/) {
					$res = $1;
					$what = "master";
				}
			}
			elsif ($line =~
				/Promote\s+(\S+)\s+\((\S+) -> \S+\s+(.*)\)/) {
				# Promote from something, still that something
				$res = $1;
				$what = $2;
				$on = $3;
				if ($res =~ /(.*):\d+$/) {
					$res = $1;
				}
			}
			elsif ($line =~
				/Move\s+(\S+)\s+\((\S+)\s+(\S+)/) {
				# Promote from something, still that something
				$res = $1;
				$what = $2;
				$on = $3;
			}
			elsif ($line =~
				/native_print:\s+(\S+).*:\s+(.*)\s+\(unmanaged\)$/) {
				# unmanaged
				$res = $1;
				my $state = $2;
				$state =~ s/\(.*\)\s+//;
				if ($res =~ /(.*):\d+$/) {
					$res = $1;
				}
				if ($state =~ /^(Stopped)/) {
				}
				else {
					($what, $on) = split /\s+/, $state;
				}
				$unmanaged{$res}++;
			}
			elsif ($line =~ /native_color:\s+(\S+)\s+allocation score on ([^:]+):\s+(\S+)/) {
				my $r = $1;
				my $host = $2;
				my $score = $3;
				$allocation_scores{$r}{$host} = $score;
			}
			if ($res) {
				$resources{$res}++;
				if ($what && $on) {
					$role{$res}{$on} = $what if !$role{$res}{$on};
				}
			}
		}
		my $fenced_nodes_ret = "";
		if (@fenced_nodes > 0) {
			$fenced_nodes_ret .= "<fenced>\n";
			for my $n (@fenced_nodes) {
				$fenced_nodes_ret .= " <node>$n</node>\n"
			}
			$fenced_nodes_ret .= "</fenced>\n";
		}
		my $info = "";
		for my $res (sort keys %resources) {
			my $running = "running";
			if (keys %{$role{$res}} == 0) {
				$running = "stopped";
			}
			my $managed = "managed";
			if ($unmanaged{$res}) {
				$managed = "unmanaged";
			}
			$info .= "  <resource id=\"$res\""
				. " running=\"$running\""
				. " managed=\"$managed\">\n";
			for my $on (sort keys %{$role{$res}}) {
				my $tag = $role{$res}{$on};
				$info .= "    <$tag>$on</$tag>\n";
			}
			if ($allocation_scores{$res}) {
				$info .= "    <scores>\n";
				for my $host (keys %{$allocation_scores{$res}}) {
					my $score = $allocation_scores{$res}{$host};
					$info .= "      <score host=\"$host\" score=\"$score\"/>\n";
				}
				$info .= "    </scores>\n";
			}
			$info .= "  </resource>\n";
		}
		if ($info) {
			return("<resource_status>\n$info</resource_status>\n",
				$fenced_nodes_ret);
		}
		return("", $fenced_nodes_ret);
	}

	sub get_cluster_info {
		my $hb_version = shift;
		my ($info, $fenced_nodes) = get_resource_status($hb_version);
		# TODO: use cib.xml if cibadmin can't connect
		my $cibinfo = Command::_exec("/usr/sbin/cibadmin -Ql || cat /var/lib/pacemaker/cib/cib.xml /var/lib/heartbeat/crm/cib.xml 2>/dev/null");
		if ($cibinfo) {
			my $res_status = "res_status";
			my $cibquery = "cibadmin";
			return "$res_status\nok\n$info\n>>>$res_status\n"
				. "$cibquery\nok\n<pcmk>\n$fenced_nodes$cibinfo</pcmk>\n"
				. ">>>$cibquery\n";
		}
		return "\n";
	}

	sub get_cluster_metadata {
		print "<metadata>\n";
		my $libpath = get_hb_lib_path();
		my $crmd_libpath = get_crmd_lib_path();
		# pengine moved in pcmk 1.1.7
		my $pengine = Command::_exec("$crmd_libpath/pengine metadata 2>/dev/null || $libpath/pengine metadata 2>/dev/null");
		if ($pengine) {
			# remove first line
			substr $pengine, 0, index($pengine, "\n") + 1, '';
			print $pengine;
		}
		my $crmd = Command::_exec("$crmd_libpath/crmd metadata 2>/dev/null");
		if ($crmd) {
			# remove first line
			substr $crmd, 0, index($crmd, "\n") + 1, '';
			print $crmd;
		}
		print "</metadata>\n";
	}

	sub get_existing_resources {
		my $list = Command::_exec("crm_resource -L");
		my %existing_rscs;
		while ($list =~ /\((.*)::(.*):(.*)\)/g) {
			$existing_rscs{$1}{$2}{$3} = 1;
		}
		return \%existing_rscs;
	}

	sub get_resource_agents {
		my $type = shift || "";
		my $existing_rscs_ocf;
		my $existing_rscs_stonith;
		if ("configured" eq $type) {
			my $existing_rscs = get_existing_resources();
			$existing_rscs_ocf = $$existing_rscs{"ocf"};
			$existing_rscs_stonith = $$existing_rscs{"stonith"};
		}
		print "class:ocf\n";
		get_ocf_resources($type, $existing_rscs_ocf);
		print "provider:heartbeat\n";
		print "master:\n";
		print "class:stonith\n";
		get_stonith_devices($type, $existing_rscs_stonith);
		if ("quick" eq $type) {
			print "class:heartbeat\n";
			get_old_style_resources($type);
			for my $service (@SERVICE_CLASSES) {
				get_service_resources($service);
			}
			# lsb is subset of service, but this is needed for
			# services already configured as lsb in pcmk config.
			print "class:lsb\n";
			get_lsb_resources();
		}
	}

	sub get_ocf_resources {
		my $type = shift || "";
		my $existing_rscs = shift;
		my $quick = 0;
		if ("quick" eq $type) {
			$quick = 1;
		}
		if ("configured" eq $type) {
			for my $prov (keys %{$existing_rscs}) {
				print "provider:$prov\n";
				for my $s (keys %{$$existing_rscs{$prov}}) {
					get_ocf_resource($prov, $s, $quick);
				}
			}
		}
		else {
			opendir my $dfh, "$OCF_RESOURCE_DIR" or return;
			for my $prov (sort grep {/^[^.]/} readdir $dfh) {
				print "provider:$prov\n";
				opendir my $d2fh, "$OCF_RESOURCE_DIR/$prov" or next;
				for my $s (sort grep {/^[^.]/ && !/\.metadata$/} readdir $d2fh) {
					get_ocf_resource($prov, $s, $quick);
				}
			}
		}
	}

	sub get_ocf_resource {
		my $prov = shift;
		my $s = shift;
		my $quick = shift;
		if ($quick) {
			$s =~ s/\.sh$//;
			print "ra:$s\n";
		}
		else {
			my $ra_name = $s;
			$ra_name =~ s/\.sh$//;
			print "ra-name:$ra_name\n";
			print "master:";
			print Command::_exec("grep -wl crm_master $OCF_RESOURCE_DIR/$prov/$s;echo;") . "\n";
			print Command::_exec("OCF_RESKEY_vmxpath=a OCF_ROOT=$OCF_DIR $OCF_RESOURCE_DIR/$prov/$s meta-data 2>/dev/null");
		}
	}

	sub get_old_style_resources {
		my $type = shift || "";
		my $quick = 0;
		if ("quick" eq $type) {
			$quick = 1;
		}
		my $dir = "/etc/ha.d/resource.d/";
		for (Command::_exec("ls $dir 2>/dev/null")) {
			print "ra:$_";
		}
	}

	# service, upstart, systemd.
	# would work for lsb, but it's not backwards compatible
	sub get_service_resources {
		my $service = shift;
		print "class:$service\n";
		for (Command::_exec("$PCMK_SERVICE_AGENTS $service 2>/dev/null")) {
			next if /@/; # skip some weird stuff
			print "ra:$_";
		}
	}

	sub get_lsb_resources {
		# old style init scripts (lsb)
		my $dir = "/etc/init.d/";
		for (Command::_exec("find $dir -perm -u=x -xtype f -printf \"%f\n\"")) {
			print "ra:$_";
		}
	}

	sub get_stonith_devices {
		my $type = shift || "";
		my $existing_rscs = shift;
		if (!-e $STONITH_ADMIN_PROG) {
			get_stonith_devices_old($type, $existing_rscs);
		}
		my $quick = 0;
		my $configured = 0;
		my %configured_devs;
		if ("quick" eq $type) {
			$quick = 1;
		}
		elsif ("configured" eq $type) {
			$configured = 1;
			for my $p (keys %$existing_rscs) {
				for my $s (keys %{$$existing_rscs{$p}}) {
					$configured_devs{$s}++
				}
			}

		}

		for my $name (Command::_exec("$STONITH_ADMIN_PROG -I")) {
			chomp $name;
			if ($quick) {
				print "ra:$name\n";
				next;
			}
			if ($configured && !$configured_devs{$name}) {
				next;
			}
			my $metadata = Command::_exec("$STONITH_ADMIN_PROG -M -a $name");
			$metadata =~ s/(<resource-agent.*?)\>/$1 class="stonith">/;
			if (!$metadata) {
				next;
			}
			print "ra-name:$name\n";
			print $metadata;
		}
	}

	# squeeze, natty
	sub get_stonith_devices_old {
		my $type = shift || "";
		my $existing_rscs = shift;
		my $quick = 0;
		my $configured = 0;
		my %configured_devs;
		if ("quick" eq $type) {
			$quick = 1;
		}
		elsif ("configured" eq $type) {
			$configured = 1;
			for my $p (keys %$existing_rscs) {
				for my $s (keys %{$$existing_rscs{$p}}) {
					$configured_devs{$s}++
				}
			}

		}
		my $libdir = "/usr/lib/stonith/plugins";
		my $arch = Command::_exec("uname -m", 2);
		chomp $arch;
		if ($arch eq "x86_64") {
			my $libdir64 = "/usr/lib64/stonith/plugins";
			if (-e $libdir64) {
				$libdir = $libdir64;
			}
		}
		for my $subtype ("external") {
			my $dir = "$libdir/$subtype/";
			for (Command::_exec("find $dir -perm -a=x -type f -printf \"%f\n\"")) {
				if ($quick) {
					print "ra:$subtype/$_";
				}
				else {
					chomp;
					if ($configured && !$configured_devs{$_}) {
						next;
					}
					my $path = "PATH=\$PATH:/usr/share/cluster-glue";
					print get_ocf_like_stonith_devices(
						"$subtype/$_",
						scalar Command::_exec("$path $dir/$_ getinfo-devid"),
						scalar Command::_exec("$path $dir/$_ getinfo-devdescr")
							. Command::_exec("$path $dir/$_ getinfo-devurl"),
						scalar Command::_exec("$path $dir/$_ getinfo-xml"));
				}
			}
		}

		for my $subtype ("stonith2") {
			my $dir = "$libdir/$subtype/";
			for (Command::_exec("find $dir -type f -name *.so -printf \"%f\n\"")) {
				chomp;
				my $name = $_;
				$name =~ s/\.so$//;
				if ($quick) {
					print "ra:$name\n";
					next;
				}
				if ($configured && !$configured_devs{$name}) {
					next;
				}
				my $info = Command::_exec("/usr/sbin/stonith -t $name -h");
				if (!$info) {
					next;
				}
				my ($shortdesc, $longdesc) = $info
					=~ /^STONITH Device:\s+(.*?)$(.*?)List of valid/ms;
				my $content;
				open my $fh, "$dir/$_" or next;
				{
					local $/;
					$content = <$fh>;
				}
				close $fh;
				if (!$content) {
					next;
				}
				my ($parameters) =
					$content =~ /(<parameters>.*?<\/parameters>)/s;
				print get_ocf_like_stonith_devices($name,
					$shortdesc,
					$longdesc,
					$parameters);
			}
		}
	}

	sub get_ocf_like_stonith_devices {
		my $device = shift;
		my $shortdesc = shift;
		my $longdesc = shift;
		my $parameters = shift;
		my $class = "stonith";

		return <<XML;
<?xml version="1.0"?>
<resource-agent name="$device" class="$class">
<version>1.0</version>

<shortdesc lang="en">$shortdesc</shortdesc>
<longdesc lang="en">$longdesc</longdesc>
$parameters
<actions>
<action name="monitor" timeout="60" interval="60" />
<action name="start"   timeout="60" />
<action name="stop"    timeout="60" />
</actions>
</resource-agent>
XML
	}

	sub get_drbd_xml {
		get_drbd_proxy_xml();
		my %missing; # handlers and startup don't come from drbdsetup xml-help, so
		# we parse them out of the man page.
		my @missing;
		my $manpage = Command::_exec("zcat /usr/share/man/man5/drbd.conf.5.gz || cat /usr/share/man/man5/drbd.conf.5 || cat /usr/man/man5/drbd.conf.5 || bzcat /usr/share/man/man5/drbd.conf.5.bz2");
		if (!$manpage) {
			Log::print_error("drbd xml\n");
			exit 1;
		}
		my $from = "";

		for my $section ("global", "handlers", "startup") {
			my ($part) = $manpage =~ /^\\fB$section\\fR$(.*?)\.[TPs][Pp]/sm;
			my @options = map {s/\\-/-/g;
				$_} $part =~ /\\fB(.*?)\\fR(?!\()/g;
			push @missing, $section;
			$missing{$section} = \@options;
		}

		#$missing{"resource"} = ["protocol", "device"];
		push @missing, "resource";

		my @a = $manpage =~ /^\\fB(([^\n]*?)(?:\s+(?:\\fR\\fB)?\\fI|\\fR$).*?)\.[TP]P/msg;
		my %descs;
		while (@a) {
			if ($from && $a[1] ne "on-io-error") {
				shift @a;
				next;
			}
			$from = "";
			my $desc = shift @a;
			my $command = shift @a;
			$desc =~ s/.\\" drbd.conf:.*$//gm;
			$desc =~ s/\n(?!\n)/ /g;
			$desc =~ s/\.RS 4/\n/g;
			$desc =~ s/\.sp/\n\n/g;
			# split lines that are max 80 characters long.
			my $cols = 80;
			$desc = join "\n",
				map {
					my $line = $_;
					$_ = "";
					while (length $line >= $cols) {
						my $r = rindex $line, " ", $cols;
						my $next_line = substr $line,
							$r,
							length($line) - $r,
							"\n";
						$_ .= $line;
						$line = $next_line;
					};
					$_ . $line}
					split /\n/, $desc;
			for ($desc, $command) {
				s/\\m\[blue\]//g;
				s/\\m\[\].*?s\+2//g;
				s/\\-/-/g;
				s/\\'/'/g;
				s/\\&//g;
				s/&/&amp;/g;
				s/\\fI(.*?)\\fR/&lt;u&gt;&lt;i&gt;$1&lt;\/i&gt;&lt;\/u&gt;/g; # italic
				s/\\fB(.*?)\\fR/&lt;b&gt;$1&lt;\/b&gt;/g;                     # bold
				s/\</&lt;/g;
				s/\>/&gt;/g;
				s/\\fB//g;
				s/\.fR//g;
				s/\\fR//g;
				s/\.RS 4/&lt;br&gt;/g;
				s/\.RS//g;
				s/\.RE//g;
				s/\.sp/&lt;br&gt;/g;
				s/\.[TP]P//g;
				s/\n/&lt;br&gt;/g;
			}
			$descs{$command} = "<desc>&lt;html&gt;$desc&lt;/html&gt;</desc>";
		}

		for (@missing) {
			print "<command name=\"$_\">\n";
			for my $option (@{$missing{$_}}) {
				my $desc = $descs{$option};
				my $type = "string";
				my $handlers = "";
				my $default;
				my $min;
				my $max;

				if ($desc) {
					my ($arg) = $desc =~ /^.*?&lt;i&gt;(.*?)&lt;/;
					if (!$arg || $arg eq $option) {
						$type = "boolean";
					}
					elsif ($arg eq "count" || $arg eq "time") {
						$type = "numeric";
					}
					my ($part) =
						$desc =~ /valid.*?options.*?are:(.*)/si;
					if ($part) {
						my @hs =
							$part =~ /&lt;b&gt;(.*?)&lt;\/b&gt;/g;
						if (@hs > 0) {
							$type = "handler";
							for my $h (@hs) {
								$handlers .= "<handler>$h</handler>";
							}
						}
					}
					if ($type eq "numeric") {
						($default) = $desc =~ /default\s+.*?is\s+(\d+)/i;
						($min, $max) = $desc =~ /from (\d+) to (\d+)/;
					}
				}
				print "\t<option name=\"$option\" type=\"$type\">\n";
				if ($handlers) {
					print "\t\t$handlers\n";
				}
				if (defined $default) {
					print "\t\t<default>$default</default>\n";
				}
				if (defined $min) {
					print "\t\t<min>$min</min>\n";
				}
				if (defined $max) {
					print "\t\t<max>$max</max>\n";
				}
				if ($desc) {
					print "\t\t$desc\n";
				}
				print "\t</option>\n";
			}
			print "</command>\n";
		}

		my ($v1, $v2) = get_drbd_version();
		my @sections = ("net-options", "disk-options");
		my $help_option = "xml-help";
		if ($v1 < 7 || ($v1 == 8 && $v2 < 4)) {
			# < 8.4.0
			@sections = ("net", "disk", "syncer");
			$help_option = "xml";
		}

		for (@sections) {
			my $xml = Command::_exec("/sbin/drbdsetup $help_option $_");
			if ($Command::COMMAND_ERRNO) {
				Log::print_error("can't exec drbdsetup: $Command::COMMAND_ERRNO\n");
				exit 1;
			}
			$xml =~ s/(option name="(.*?)".*?)(<\/option>)/$1 . ($descs{$2} || "not documented") . $3 /egs;
			print $xml;
		}
	}
	sub get_drbd_proxy_plugins {
		my $out = Command::_exec("$DRBD_PROXY_GET_PLUGINS");
		my @parts = split /\n\n/, $out;
		my %plugins = (
			debug => "",
			lzma  => "",
			zlib  => "",
		); # default in case proxy is not installed
		for my $p (@parts) {
			my ($name, $desc) = $p =~ /Plugin.*?:\s+(\S+)\s+(.*)/s;
			$desc =~ s/\n/&lt;br&gt;/;
			$desc =~ s!\*(.*?)\*!&lt;b&gt;$1&lt;/b&gt;!;
			$plugins{$name} = $desc;
		}
		return \%plugins;

	}

	sub get_drbd_proxy_xml {
		my $proxy = <<"MEMLIMIT";
<command name="proxy">
	<option name="memlimit" type="numeric">
		<default>16</default>
		<unit_prefix>M</unit_prefix>
		<unit>bytes</unit>
		<desc>&lt;html&gt;
The amount of memory used by the proxy for incoming packets. This means&lt;br&gt;
the raw data size of DRBD packets. The actual memory used is typically&lt;br&gt;
twice as much (depending on the compression ratio)
		&lt;/html&gt;</desc>
	</option>
MEMLIMIT
		my $plugins = get_drbd_proxy_plugins();
		my %boolean_plugins = (debug => 1,
			noop                     => 1);
		for my $plugin (sort keys %$plugins) {
			if ($$plugins{$plugin} =~ /compress/i) {
				$proxy .= <<"PLUGIN";
	<option name="plugin-$plugin" type="handler">
		<handler>level 9</handler>
		<handler>contexts 4 level 9</handler>
		<handler>level 8</handler>
		<handler>level 7</handler>
		<handler>level 6</handler>
		<handler>level 5</handler>
		<handler>level 4</handler>
		<handler>level 3</handler>
		<handler>level 2</handler>
		<handler>level 1</handler>
		<desc>&lt;html&gt;
		$$plugins{$plugin}
		&lt;/html&gt;</desc>
	</option>
PLUGIN
			}
			else {
				my $type = "string";
				$type = "boolean" if $boolean_plugins{$plugin};
				$proxy .= <<"PLUGIN";
	<option name="plugin-$plugin" type="$type">
		<desc>&lt;html&gt;
		$$plugins{$plugin}
		&lt;/html&gt;</desc>
	</option>
PLUGIN
			}
		}
		# deprecated options
		$proxy .= <<"OTHER";
	<option name="read-loops" type="numeric">
		<desc>&lt;html&gt;
		&lt;b&gt;DEPRECATED&lt;/b&gt;: don't use
		&lt;/html&gt;</desc>
	</option>
	<option name="compression" type="handler">
		<handler>on</handler>
		<handler>off</handler>
		<desc>&lt;html&gt;
		&lt;b&gt;DEPRECATED&lt;/b&gt;: don't use
		&lt;/html&gt;</desc>
	</option>
OTHER
		$proxy .= "</command>\n";
		print $proxy;
	}

	sub get_drbd_proxy_info {
		my $out = "";
		for (Command::_exec("$DRBD_PROXY_SHOW 2>/dev/null")) {
			if (/add connection\s+(\S*)/) {
				$out .= "up:$1\n";
			}
		}
		return $out;
	}

	sub get_drbd_version {
		my (@version) = Command::_exec("echo|/sbin/drbdadm help 2>/dev/null")
			=~ /Version:\s+(\d+)\.(\d+)\.\d+/;
		return @version;
	}

	#
	# Returns whether it is an init script.
	sub is_init {
		my $script = shift;
		if (-e "/usr/lib/systemd/system/$script.service"
			|| -e "/etc/init.d/$script") {
			return "on";
		}
		return "";
	}

	#
	# Returns a portable command that determines if the init script is in rc?.d
	# directories.
	sub is_script_rc {
		my $script = shift;
		return
			"(/bin/systemctl is-enabled $script.service|grep enabled"
				. " || /usr/sbin/update-rc.d -n -f $script remove 2>&1|grep '/rc[0-9]\.d.*$script\\>'"
				. " || /sbin/chkconfig --list $script 2>/dev/null"
				. "|grep ':on') 2>/dev/null"
				. "|sed s/.*/on/|uniq";
	}

	#
	# Returns a portable command that determines if the init script is running.
	sub is_running {
		my $script = shift;
		my $prog = shift;
		return <<STATUS;
if (/etc/init.d/$script status 2>&1|grep 'Usage:' >/dev/null); then \
	PROG=$prog; \
	for PID in `pidof \$PROG`; do \
		if [ "\$(readlink -f /proc/\$PID/exe)" = "\$PROG" ]; then \
			exit 0; \
		fi; \
	done; \
	exit 3; \
else \
	if [ -e /etc/init.d/$script ]; then \
		out=`/etc/init.d/$script status 2>&1`; \
	else \
		out=`service $script status 2>&1`; \
	fi; \
	ret=\$?; \
	if [ -z "\$out" ]; then exit 111; else exit \$ret; fi; \
fi
STATUS
	}

	sub get_cluster_versions {
		my $libpath = get_hb_lib_path();
		my $crmd_libpath = get_crmd_lib_path();
		my $hb_version = Command::_exec("$libpath/heartbeat -V 2>/dev/null") || "";
		if ($hb_version) {
			$hb_version =~ s/\s+.*//;
			chomp $hb_version;
		}
		if ($hb_version eq "2.1.3") {
			# sles10 hb 2.1.3 looks like 2.1.4 to me
			my $desc = Command::_exec("/usr/bin/lsb_release -d 2>/dev/null");
			if ($desc && $desc =~ /SUSE Linux Enterprise Server 10/) {
				$hb_version = "2.1.4";
			}
		}
		my $pm_version = Command::_exec("$crmd_libpath/crmd version 2>/dev/null") || "";
		if ($pm_version) {
			$pm_version =~ s/CRM Version:\s+//;
			$pm_version =~ s/\s+.*//;
			chomp $pm_version;
			if ($pm_version =~ /^2\.1\./) {
				$pm_version = "";
			}
		}

		# there is no reliable way to find the installed corosync and openais
		# version, so it is best effort or just "ok" if it is installed
		# after that only the package managers will be asked.
		my $cs_prog = "/usr/sbin/corosync";
		my $cs_version = "";
		my $cs_script = "corosync";
		my $corosync_1_2_5_file = "/tmp/corosync-1.2.5-beware";
		if (-e $cs_prog) {
			if (-e $corosync_1_2_5_file) {
				$cs_version = "1.2.5!";
			}
			else {
				my ($cs_version_string) = Command::_exec("$cs_prog -v") =~ /('.*?')/;
				# workaround for opensuse
				$cs_version_string =~ s/'UNKNOWN'/'2.3.1'/;
				($cs_version) = $cs_version_string =~ /'(\d+\.\d+\.\d+)'/;
				if ($cs_version && "1.2.5" eq $cs_version) {
					# workaround so that corosync 1.2.5 does not fill up
					# shared momory.
					if (open TMP, ">$corosync_1_2_5_file") {
						close TMP;
					}
				}
				else {
					unlink $corosync_1_2_5_file;
				}
			}
			if (!$cs_version) {
				$cs_version = "ok";
			}
		}
		my $ais_prog = "/usr/sbin/aisexec";
		my $ais_script = "openais";
		if (!-e "/etc/init.d/openais" && -e "/etc/init.d/openais-legacy") {
			$ais_script = "openais-legacy";
		}
		my $ais_version = "";
		if (-e $ais_prog) {
			if (!(Command::_system("/usr/bin/file $ais_prog 2>/dev/null"
				. "|grep 'shell script' > /dev/null") >> 8)
				&& -e "/etc/init.d/openais") {
				$ais_version = "wrapper";
			}
			if (!$ais_version) {
				$ais_version =
					Command::_exec("grep -a -o 'subrev [0-9]* version [0-9.]*' /usr/sbin/aisexec|sed 's/.* //'");
				chomp $ais_version;
			}
			if (!$ais_version) {
				$ais_version = "ok";
			}
		}
		my $pcmk_prog = "/usr/sbin/pacemakerd";
		my $pcmk_script = "pacemaker";
		my $drbdp_script = "drbdproxy";
		my $drbdp_prog = "/sbin/drbd-proxy";
		my $hb_init = is_init("heartbeat");
		chomp $hb_init;
		my $cs_init = is_init($cs_script);
		chomp $cs_init;
		my $ais_init = is_init($ais_script);
		chomp $ais_init;
		my $pcmk_init = is_init($pcmk_script);
		chomp $pcmk_init;
		my $hb_isrc_cmd = is_script_rc("heartbeat");
		my $cs_isrc_cmd = is_script_rc($cs_script);
		my $ais_isrc_cmd = is_script_rc($ais_script);
		my $pcmk_isrc_cmd = is_script_rc($pcmk_script);
		my $hb_isrc = Command::_exec("$hb_isrc_cmd") || "off";
		my $cs_isrc = Command::_exec("$cs_isrc_cmd") || "off";
		my $ais_isrc = Command::_exec("$ais_isrc_cmd") || "off";
		my $pcmk_isrc = Command::_exec("$pcmk_isrc_cmd") || "off";
		chomp $hb_isrc;
		chomp $cs_isrc;
		chomp $ais_isrc;
		chomp $pcmk_isrc;

		my $hb_running_cmd = "$libpath/heartbeat -s";
		my $ais_running = "";
		if (!$cs_version || "wrapper" eq $ais_version) {
			my $ais_running_cmd = is_running($ais_script, $ais_prog);
			$ais_running =
				Command::_system("$ais_running_cmd >/dev/null 2>&1") >> 8 || "on";
		}
		my $cs_running_cmd = is_running($cs_script, $cs_prog);
		my $cs_running = Command::_system("$cs_running_cmd >/dev/null 2>&1") >> 8 || "on";
		my $hb_running = Command::_system("$hb_running_cmd >/dev/null 2>&1") >> 8 || "on";
		my $pcmk_running_cmd = is_running($pcmk_script, $pcmk_prog);
		my $pcmk_running =
			Command::_system("$pcmk_running_cmd >/dev/null 2>&1") >> 8 || "on";
		my $drbd_loaded = (!-e $PROC_DRBD) || "on";
		my $hb_conf = Command::_system("ls /etc/ha.d/ha.cf >/dev/null 2>&1") >> 8 || "on";
		my $drbdp_running_cmd = is_running($drbdp_script, $drbdp_prog);
		my $drbdp_running =
			Command::_system("$drbdp_running_cmd >/dev/null 2>&1") >> 8 || "on";
		my $cs_ais_conf;
		if ($cs_version) {
			$cs_ais_conf =
				Command::_system("ls /etc/corosync/corosync.conf >/dev/null 2>&1") >> 8
					|| "on";
		}
		else {
			$cs_ais_conf =
				Command::_system("ls /etc/ais/openais.conf >/dev/null 2>&1") >> 8
					|| "on";
		}
		chomp $hb_running;
		chomp $ais_running;
		chomp $cs_running;
		chomp $pcmk_running;
		chomp $drbdp_running;
		my $service = Command::_exec("(/usr/sbin/corosync-cmapctl service || /usr/sbin/corosync-objctl|grep '^service\.') 2>/dev/null");
		my $pcmk_svc_ver = "no";
		if ($service && $service =~ /^service\.ver=(\d+)/m) {
			$pcmk_svc_ver = $1;
		}
		# drbd version
		my ($drbd_version) =
			Command::_exec("echo|/sbin/drbdadm help 2>/dev/null") =~ /Version:\s+(\S+)/;
		$drbd_version = "" if !$drbd_version;
		my $drbd_mod_version = Command::_exec("(/sbin/modinfo -F version drbd 2>/dev/null|grep . || /sbin/modinfo -F description drbd 2>/dev/null|sed 's/.* v//')", 2) || "";
		chomp $drbd_mod_version;
		return "hb:$hb_version\n"
			. "pm:$pm_version\n"
			. "cs:$cs_version\n"
			. "ais:$ais_version\n"
			. "hb-rc:$hb_isrc\n"
			. "ais-rc:$ais_isrc\n"
			. "cs-rc:$cs_isrc\n"
			. "pcmk-rc:$pcmk_isrc\n"
			. "hb-running:$hb_running\n"
			. "cs-running:$cs_running\n"
			. "ais-running:$ais_running\n"
			. "pcmk-running:$pcmk_running\n"
			. "drbdp-running:$drbdp_running\n"
			. "hb-init:$hb_init\n"
			. "cs-init:$cs_init\n"
			. "ais-init:$ais_init\n"
			. "pcmk-init:$pcmk_init\n"
			. "pcmk-svc-ver:$pcmk_svc_ver\n"
			. "hb-conf:$hb_conf\n"
			. "cs-ais-conf:$cs_ais_conf\n"
			. "drbd:$drbd_version\n"
			. "drbd-mod:$drbd_mod_version\n"
			. "drbd-loaded:$drbd_loaded\n"
			. "hb-lib-path:$libpath\n"
	}

	# return -1 if ver1 is smaller than ver2 etc. 1.0.9.1 and 1.0.9 are considered
	# equal and return 0.
	sub compare_versions {
		my $ver1 = shift;
		my $ver2 = shift;
		my @ver1 = split /\./, $ver1;
		my @ver2 = split /\./, $ver2;
		while (@ver1 > 0 && @ver2 > 0) {
			my $v1 = shift @ver1;
			my $v2 = shift @ver2;
			if ($v1 < $v2) {
				return -1;
			}
			elsif ($v1 > $v2) {
				return 1;
			}
		}
		return 0;
	}

	sub pcmk_version_smaller_than {
		my $version = shift;
		my ($pcmk_version) = (get_cluster_versions() =~ /pm:([\d.]*)/);
		return compare_versions($pcmk_version, $version) < 0;
	}

	sub pcmk_version_greater_than {
		my $version = shift;
		my ($pcmk_version) = (get_cluster_versions() =~ /pm:([\d.]*)/);
		return compare_versions($pcmk_version, $version) > 0;
	}

	sub get_vm_networks {
		my %autostart;
		for (Command::_exec("ls /etc/libvirt/qemu/networks/autostart/*.xml 2>/dev/null")) {
			my ($name) = /([^\/]+).xml/;
			next if !$name;
			$autostart{$name}++;
		}
		my $out = "";
		for (Command::_exec("ls /etc/libvirt/qemu/networks/*.xml 2>/dev/null")) {
			my ($name) = /([^\/]+).xml/;
			next if !$name;
			chomp;
			my $config = Command::_exec("$VIRSH_COMMAND net-dumpxml $name 2>/dev/null")
				|| "";
			if ($config) {
				$out .= "<net name=\"$name\" config=\"$_\"";
				if ($autostart{$name}) {
					$out .= ' autostart="True"';
				}
				else {
					$out .= ' autostart="False"';
				}
				$out .= ">\n";
				$out .= $config;
				$out .= "</net>\n";
			}
		}
		return $out;
	}

	sub get_vm_info {
		my $networks = get_vm_networks();
		my %autostart;
		for (Command::_exec("ls /etc/libvirt/qemu/autostart/*.xml 2>/dev/null; ls /etc/xen/auto/ 2>/dev/null")) {
			my ($name) = /([^\/]+).xml/;
			next if !$name;
			$autostart{$name}++;
		}
		my $libvirt_version = "";
		if (Command::_exec("$VIRSH_COMMAND version 2>/dev/null") =~ /libvirt\s+([0-9\.]+)/) {
			$libvirt_version = $1;
		}
		my $out = "<version>$libvirt_version</version>\n";
		OPTIONS:
		for my $options (@VM_OPTIONS) {
			if ($DISABLE_VM_OPTIONS{$options}) {
				next;
			}
			my $header = 1;
			for (Command::_exec("$VIRSH_COMMAND $options list --all 2>&1")) {
				if ($header) {
					if (/^-{5}/) {
						$header = 0;
					}
					elsif (/^error:/) {
						# disable the ones that give an
						# error
						$DISABLE_VM_OPTIONS{$options}++;
						next OPTIONS;
					}
					next;
				}
				my ($name) = /^\s*\S+\s+(\S+)/;
				next if !$name;
				chomp;
				my $info =
					Command::_exec("$VIRSH_COMMAND $options dominfo $name 2>/dev/null|grep -v 'CPU time'")
						|| "";
				next if !$info;
				my $vncdisplay =
					Command::_exec("$VIRSH_COMMAND $options vncdisplay $name 2>/dev/null") || "";
				my $config_in_etc;
				#if (open CONFIG, $_) {
				#	local $/;
				#	$config_in_etc = <CONFIG>;
				#	close CONFIG;
				#}
				my $config;
				$config =
					Command::_exec("$VIRSH_COMMAND_NO_RO $options dumpxml --security-info $name 2>/dev/null") || "";
				$out .= "<vm name=\"$name\"";
				if ($autostart{$name}) {
					$out .= ' autostart="True"';
				}
				else {
					$out .= ' autostart="False"';
				}
				if ($options) {
					$out .= ' virsh-options="' . $options . '"';
				}
				$out .= ">\n";
				$out .= "<info>\n";
				$out .= $info;
				$out .= "</info>\n";
				$out .= "<vncdisplay>$vncdisplay</vncdisplay>\n";
				if ($config) {
					$out .= "<config>\n";
					$out .= $config;
					$out .= "</config>\n";
				}
				if ($config_in_etc) {
					$out .= "<config-in-etc>\n";
					$out .= "<![CDATA[$config_in_etc]]>";
					$out .= "</config-in-etc>\n";
				}
				$out .= "</vm>\n";
			}
		}
		if ($networks) {
			$out .= $networks;
		}
		my $md5 = Digest::MD5::md5_hex($out);
		my $ret = "<vms md5=\"$md5\">\n";
		$ret .= $out;
		$ret .= "</vms>\n";
		return $ret;
	}

	sub get_proc_drbd {
		my %texts = (ns => "sent over network",
			nr          => "received over network",
			dw          => "written to the disk",
			dr          => "read from the disk",
			al          => "number of activity log updates",
			bm          => "number of bitmap updates",
			lo          => "local count",
			pe          => "pending",
			ua          => "unacknowledged",
			ap          => "application pending",
			ep          => "epochs",
			wo          => "write order",
			oos         => "out of sync");
		my %units = (ns => "KB",
			nr          => "KB",
			dw          => "KB",
			dr          => "KB",
			al          => "",
			bm          => "",
			lo          => "",
			pe          => "",
			ua          => "",
			ap          => "",
			ep          => "",
			wo          => "fdn",
			oos         => "KB");
		my %write_orders = (b => "barrier",
			f                 => "flush",
			d                 => "drain",
			n                 => "none");

		if (!open my $pfh, "/proc/drbd") {
			Log::print_warning("can't open /proc/drbd: $!\n");
		}
		else {
			while (<$pfh>) {
				my @infos;
				print;
				if (/ns:/ && /nr:/ && /dr:/) {
					@infos = split;
				}
				my $l = 0;
				for (values %texts) {
					$l = length $_ if length $_ > $l;
				}
				for (@infos) {
					my ($name, $value) = split /:/;
					if ($texts{$name}) {
						print "    $texts{$name}: ";
						print " " x ($l - length $texts{$name});
						my $unit = $units{$name};
						if ("fdn" eq $unit) {
							print $write_orders{$value}
								. "\n";
						}
						elsif ("KB" eq $unit) {
							print convert_kilobytes($value)
								. "\n";
						}
						else {
							print "$value\n";
						}
					}
					else {
						print "$name: $value\n";
					}
				}
				if (/ns:/ && /nr:/ && /dr:/) {
					print "\n\n";
				}
			}
			close $pfh;
		}
	}

	sub convert_kilobytes {
		my $value = shift;
		for my $unit ("KiBytes", "MiBytes", "GiBytes", "TiBytes") {
			if ($value < 1024) {
				return sprintf("%.2f %s", $value, $unit);
			}
			$value = $value / 1024;
		}
		return $value . " TiBytes";
	}

	# force daemon to reread the lvm information
	sub clear_lvm_cache {
		unlink glob $LVM_ALL_CACHE_FILES;
	}
}

{
	package Options;
    # options: --log, ...
    # action options: all, get-cluster-events ...
    sub parse {
    	my $args = shift;
    	my %options;
    	my @action_options;
    	for (@$args) {
    		if ($_ !~ /^--/) {
    			# old options
    			push @action_options, $_;
    			next;
    		}
    		if (/=/) {
    			my @parts = split /=/, $_, 2;
    			$options{$parts[0]} = $parts[1];
    		} else {
    			$options{$_} = 1;
    		}
    	}
    	return (\%options, \@action_options);
    }
}
{
	package Command;

	our $COMMAND_ERRNO; # is set in _exec function

	sub _system {
		my $cmd = shift;
		my $level = shift || 1;
		return _execute($cmd, $level, 0);
	}

	sub _exec_or_die {
		my $result = _exec(shift);
		my $ret = $?;
		exit $ret if $ret != 0;
		return $result;
	}

	sub _exec {
		my $cmd = shift;
		my $level = shift || 1;
		return _execute($cmd, $level, 1);
	}

	sub _execute {
		my $cmd = shift;
		if (!$cmd) {
			Log::_log("ERROR: $0 unspecified command: line: " . (caller(1))[2], 1);
		}
		my $level = shift;
		my $wantoutput = shift;

		my $cmd_log = $cmd;
		$cmd_log =~ s/\n/ \\n /g;

		my $cmd_code = sprintf("%05x", rand(16 ** 5));
		my $start_time = Log::_log_time();
		Log::_log($start_time ." start $cmd_code: $cmd_log", $level);
		my @out;
		my $out;
		if ($wantoutput) {
			if (wantarray) {
				@out = `$cmd`;
			} else {
				$out = `$cmd` || "";
			}
		} else {
			$out = system($cmd);
		}
		$COMMAND_ERRNO=$?;
		my $end_time = Log::_log_time();
		Log::_log($end_time . " done  $cmd_code: $cmd_log", $level);
		if ($wantoutput) {
			if (wantarray) {
				return @out;
			} else {
				return $out;
			}
		} else {
			return $out;
		}
	}

	{
		package Network;

	    # get_net_info()
	    #
	    # parses ifconfig output and prints out interface, ip and mac address one
	    # interface per line.
	    sub get_net_info {
	    	my $bridges = get_bridges();
	    	my $out = "";
	    	for (Command::_exec("ip -o -f inet a; ip -o -f inet6 a")) {
	    		next if /scope link/;
	    		my ($dev, $type, $addr, $mask) =
	    			/^\d+:\s*(\S+)\s+(\S+)\s+(\S+)\/(\S+)/;
	    		next if !$dev;

	    		my $af;
	    		if ("inet" eq $type) {
	    			$af = "ipv4";
	    		} elsif ("inet6" eq $type) {
	    			$af = "ipv6";
	    		} else {
	    			next;
	    		}
	    		if ("lo" eq $dev) {
	    			$out = "$dev $af $addr $mask\n".$out;
	    		} else {
	    			$out .= "$dev $af $addr $mask";
	    			if ($$bridges{$dev}) {
	    				$out .= " bridge\n";
	    			} else {
	    				$out .= "\n";
	    			}
	    		}
	    	}
	    	$out .= "bridge-info\n";
	    	for (keys %$bridges) {
	    		$out .= "$_\n";
	    	}
	    	return $out;
	    }

		# Returns all bridges as an array.
		sub get_bridges {
			my %bridges;
			my $brctl = get_brctl_path();
			for (Command::_exec("$brctl show 2>/dev/null")) {
				next if /^\s*bridge\s+name/;
				next if /^\s/;
				$bridges{(split)[0]}++;
			}
			return \%bridges;
		}

		sub get_brctl_path {
			for my $p ("/usr/sbin/brctl", "/sbin/brctl", "/usr/local/sbin/brctl") {
				if (-e $p) {
					return $p;
				}
			}
			return "/usr/sbin/brctl";
		}
	}
}

{
	package Gui_Test;

	sub gui_test_compare {
		my $testfile_part = shift;
		my $realconf = remove_spaces(shift);
		my $test = "";
		my $diff = "";
		my $try = 0;
		do {
			my $testfile;
			if ($try > 1) {
				$testfile = "$testfile_part-$try";
			}
			else {
				$testfile = $testfile_part;
			}
			my $notestfile;
			if (!open TEST, $testfile) {
				print "$!";
				# .new can be used for new tests.
				open TEST, ">$testfile.new" or print "$!";
				print TEST $test;
				close TEST;
				$notestfile++;
			}
			else {
				{
					local $/;
					$test = remove_spaces(<TEST>);
				}
				close TEST;
			}
			open TEST, ">$testfile.error" or print "$!";
			print TEST $realconf;
			close TEST;
			open TEST, ">$testfile.error.file" or print "$!";
			print TEST $test;
			close TEST;
			$diff .= Command::_exec("diff -u $testfile.error.file $testfile.error") . "\n";
			$try++;
		} until ($realconf eq $test || !-e "$testfile_part-$try");
		if ($realconf eq $test) {
			print "ok ";
		}
		else {
			print "error\n";
			print "-------------\n";
			print $diff;
			exit 1;
		}
	}

	sub remove_spaces {
		my $config = shift || "";
		$config =~ s/^\s+//mg;
		$config =~ s/\s+$//mg;
		return $config;
	}

	sub gui_pcmk_config_test {
		my $testname = shift;
		my $index = shift;
		my @hosts = @_;
		my $crm_config = Command::_exec_or_die("TERM=dumb PATH=\$PATH:/usr/sbin /usr/sbin/crm configure show");
		for my $host (@hosts) {
			$crm_config =~ s/$host\b/host/gi;
		}
		gui_test_compare("/tmp/lcmc-test/$testname/test$index.crm", strip_crm_config($crm_config));
	}

	sub gui_pcmk_status_test {
		my $testname = shift;
		my $index = shift;
		my @hosts = @_;
		my $status = Command::_exec_or_die("crm_resource --list");
		for my $host (@hosts) {
			$status =~ s/$host\b/host/gi;
		}

		gui_test_compare("/tmp/lcmc-test/$testname/status$index.crm", $status);
	}

	sub strip_crm_config {
		my $crm_config = shift;
		$crm_config =~ s/^property.*//ms;
		$crm_config =~ s/^rsc_defaults .*//ms;
		$crm_config =~ s/^node .*//mg;
		$crm_config =~ s/^\s*attributes .*//mg;
		$crm_config =~ s/\\$//mg;
		$crm_config =~ s/^\s+//mg;
		$crm_config =~ s/\s+$//mg;
		# older crm shell had _rsc_set_
		$crm_config =~ s/_rsc_set_ //g;
		$crm_config =~ s/(start-delay=\d+) (timeout=\d+)/$2 $1/g;
		return $crm_config;
	}


	sub gui_vm_test {
		my $testname = shift;
		my $index = shift;
		my $name = shift;
		my $xml;
		for (@Main::VM_OPTIONS) {
			$xml = Command::_exec_or_die("$Main::VIRSH_COMMAND_NO_RO $_ dumpxml --security-info $name 2>/dev/null");
			if ($xml !~ /^\s*$/) {
				last;
			}
		}
		$xml =~ s/$name/\@NAME@/gm;
		my $simplified_xml = join "\n", $xml =~ /^\s*((?:<domain.*|<name.*|<disk.*|<source.*|<interface.*|<graphics type\S+))/mg;
		gui_test_compare("/tmp/lcmc-test/$testname/domain.xml$index", $simplified_xml);
	}

	sub gui_drbd_test {
		my $testname = shift;
		my $index = shift;
		my @hosts = @_;
		if (!open CONF, "/etc/drbd.conf") {
			print "$!";
			exit 2;
		}
		my $conf;
		{
			local $/;
			$conf = <CONF>;
		}
		close CONF;
		if (!$conf) {
			print "no /etc/drbd.conf";
			exit 3;
		}

		if ($conf =~ m!^include "drbd\.d/\*\.res"!m) {
			if (opendir my $dir, "/etc/drbd.d/") {
				for my $file (sort grep {/^[^.]/} readdir $dir) {
					$conf .= "--- $file ---\n";
					open my $fh, "/etc/drbd.d/$file" or die $!;
					{
						local $/;
						$conf .= <$fh>;
					}
					$conf .= "--- $file ---\n";
				}
			}
		}

		if (!open PROC, "/proc/drbd") {
			return;
		}
		my $proc = "";
		while (<PROC>) {
			next if /^version:/;
			next if /^GIT-hash:/;
			next if /^srcversion:/;
			next if /^\s+ns:/;
			next if /^\s+\d+:\s+cs:Unconfigured/;
			s/(\s\S\sr----)$/$1-/;
			$proc .= $_;
		}
		close PROC;
		for ($conf) {
			my $i = 1;
			for my $host (@hosts) {
				s/$host\b/host$i/gi;
				$i++;
			}
		}
		$conf =~ s/^(## generated by drbd-gui )\S+/$1VERSION/m;
		$conf =~ s/^(\s+shared-secret\s+)[^;]+/$1SECRET/m;
		$conf =~ s/^(\s+disk\s+)[^;{]+(\s*;\s*)$/$1DISK$2/mg;
		$conf =~ s/^(\s+address\s+)(?!.*127\.0\.0\.1)[^:]+/$1IP/mg;
		$conf =~ s/^(\s+outside\s+)[^:]+/$1IP/mg;
		my $libdir = Main::get_hb_lib_path();
		$conf =~ s/$libdir/LIBDIR/g;
		gui_test_compare("/tmp/lcmc-test/$testname/drbd.conf$index", $conf);
		gui_test_compare("/tmp/lcmc-test/$testname/proc$index", $proc);
	}
}