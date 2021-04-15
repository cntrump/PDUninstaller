#!/bin/bash
#
# Script to clean up Parallels Desktop and Parallels Desktop Switch to Mac
# installations starting from version 3.
#
# Use it at your own risk.
#
# Copyright (c) 2004-2014 Parallels IP Holdings GmbH.
# All rights reserved.
# http://www.parallels.com

domain='com.parallels'
apps_path='/Applications/Parallels Desktop.app'
lib_path='/Library/Parallels'
svc_path="${lib_path}/Parallels Service.app"
agents_path='/Library/LaunchAgents'
daemons_path='/Library/LaunchDaemons'
incompat_path='/Incompatible Software'

pd5_uninst="${svc_path}/Contents/Resources/Uninstaller.sh"
pd7_uninst="${lib_path}/Uninstaller/Parallels Hypervisor/Uninstaller.sh"
pd9_uninst="${apps_path}/Contents/MacOS/Uninstaller"
pd10_uninst="${apps_path}/Contents/MacOS/Uninstaller"

mode=kind
[ "x${1}" = 'x-p' -o "x${1}" = 'x--purge' ] && mode='purge'

if [ `id -u` -ne 0 ]; then
	echo 'Root privileges required.'
	exit 1
fi

uninst() {
	local uninst_script="$2"
	[ -x "${uninst_script}" ] || return
	echo " * Found $1 uninstaller"
	"${uninst_script}" $3
}

uninst PD5 "${pd5_uninst}" desktop
uninst PD7 "${pd7_uninst}" virtualization
uninst PD9 "${pd9_uninst}" remove
uninst PD10 "${pd10_uninst}" remove

users=$(
for u in `ls /Users`; do
	[ -d "/Users/$u" ] && id "$u" >/dev/null 2>&1 && echo "$u"
done)

daemons="
${daemons_path}/${domain}.desktop.launchdaemon.plist
${daemons_path}/pvsnatd.plist
"
agents="
${agents_path}/${domain}.desktop.launch.plist
${agents_path}/${domain}.DesktopControlAgent.plist
${agents_path}/${domain}.vm.prl_pcproxy.plist
"
IFS=$'\n'
for plist in $daemons; do
	launchctl unload "${plist}"
	rm -f "${plist}"
done
for plist in $agents; do
	for u in $users; do
		sudo -u "$u" launchctl unload "${plist}"
	done
	rm -f "${plist}"
done
unset IFS
rm -rf '/Library/StartupItems/ParallelsDesktopTransporter'
rm -rf '/Library/StartupItems/ParallelsTransporter'
rm -rf '/Library/StartupItems/Parallels'

bins2kill='
prl_vm_app
prl_client_app
prl_disp_service
Parallels Transporter
Parallels Image Tool
llipd
Parallels Explorer
Parallels Mounter
Parallels
'
IFS=$'\n'
for bin in ${bins2kill}; do
	killall -KILL "${bin}"
done
unset IFS

kill -KILL `ps -A -opid,command | \
	fgrep "/bin/bash ${apps_path}/Contents/MacOS/watchdog" | awk '{print $1}'`
ps -A -opid,comm | \
	grep -E "(${apps_path}/Contents/MacOS|${svc_path}/Contents)" | \
	awk '{print $1}' | \
	while read pid; do kill -KILL $pid; done

kextunload -b "${domain}.kext.netbridge"
kextunload -b "${domain}.kext.prl_netbridge"
kextstat | fgrep "${domain}." |
	fgrep -v "${domain}.virtualsound" | fgrep -v "${domain}.prl_video" | \
	awk '{print $6}' | while read i; do kextunload -b $i; done

pd3kexts='
ConnectUSB
Pvsnet
hypervisor
vmmain
'
IFS=$'\n'
for k in ${pd3kexts}; do
	kpath="/System/Library/Extensions/${k}.kext"
	defaults read "${kpath}/Contents/Info" CFBundleIdentifier | \
		fgrep -q "${domain}" && rm -rf "${kpath}"
	rm -rf "${incompat_path}/${k}.kext"
done
unset IFS

rm -rf /System/Library/Extensions/prl*
rm -rf "${apps_path}"
rm -rf "/Applications/Parallels"
rm -f "/Applications/._Parallels"

rm -rf "${svc_path}"
rm -rf "${lib_path}/Parallels Mounter.app"
rm -rf "${lib_path}/Parallels Transporter.app"
rm -rf "${lib_path}/Receipts"
rm -rf "${lib_path}/Tools"
rm -rf "${lib_path}/Uninstaller"
rm -rf "${lib_path}/Bioses"
rm -rf "${lib_path}/Help"
rm -rf "${lib_path}/libmspack_prl.dylib"
rm -rf "${lib_path}/.bc_backup"
rm -f "${lib_path}/.dhcp"*
rm -f /var/db/receipts/${domain}.pkg.virtualization.*
rm -f /var/db/receipts/${domain}.pkg.desktop.*
rm -f /var/db/receipts/${domain}.prlufs.core.{bom,plist}
rm -rf '/Library/Receipts/Parallels '*.pkg
rm -rf '/Library/Receipts/Install Parallels Desktop.pkg'

rm -rf "${incompat_path}/Parallels "*.app
rm -rf "${incompat_path}"/${domain}.*.plist

IFS=$'\n'
for u in ${users}; do
	home="/Users/${u}"
	home_lib="${home}/Library"
	rm -rf "${home}/.Trash/Parallels Desktop.app"
	rm -rf "${home}/.Trash/Parallels Service.app"
	rm -rf "${home}/Desktop/Parallels Desktop.app"
	rm -rf "${home}/Applications (Parallels)"

	caches="${home_lib}/Caches"
	rm -rf "${caches}/Parallels"
	rm -rf "${caches}/${domain}.desktop.console"
	rm -rf "${caches}/${domain}.winapp."*

	rm -rf "${home_lib}/Parallels/Application Menus"
	rm -f "${home_lib}/Parallels/"*.pid

	home_saved="${home_lib}/Saved Application State"
	rm -rf "${home_saved}/${domain}.desktop.console.savedState"
	rm -rf "${home_saved}/${domain}.desktop.transporter.savedState"
	rm -rf "${home_saved}/${domain}.smartinstall.savedState"

	if [ "${mode}" = 'purge' ]; then
		rm -rf "${home_lib}/Parallels"
		rm -rf "${home_lib}/Logs/Parallels"
		rm -rf "${home_lib}/Logs/parallels.log"*
		rm -rf "${home_lib}/Preferences/Parallels"
		rm -rf "${home_lib}/Preferences/${domain}."*
		rm -rf "${home}/Documents/.parallels-vm-directory"
	fi
done

cmd_tools='
prl_convert
prl_disk_tool
prl_perf_ctl
prlctl
prlsrvctl
'
for cmd in ${cmd_tools}; do
	rm -f "/usr/bin/${cmd}"
	rm -f "/usr/share/man/man8/${cmd}.8"
done
unset IFS

find /System/Library/Frameworks/Python.framework /Library/Python \
	-name prlsdkapi -exec rm -rf "{}" \;

rm -rf '/System/Library/Filesystems/prlufs.fs'
rm -rf '/Library/Filesystems/prlufs.fs'
rm -rf '/usr/lib/parallels'
rm -f '/usr/local/lib/libprl_sdk.'*
rm -rf '/usr/share/parallels-server'
rm -rf '/usr/include/parallels-server'
rm -rf '/Library/Spotlight/ParallelsMD.mdimporter'
rm -rf '/Library/QuickLook/ParallelsQL.qlgenerator'
rm -rf '/Library/Contextual Menu Items/ParallelsCM.plugin'

rm -rf /var/run/lic_events
rm -f /var/run/prl_*.pid
rm -rf '/tmp/.pd'
rm -f /etc/pam.d/prl_disp_service*
rm -f /tmp/.pd-video-path

if [ "${mode}" = 'purge' ]; then
	rm -rf "${lib_path}"
	rm -rf '/Library/Preferences/Parallels'
	rm -f '/Library/Logs/parallels.log'*
	rm -f '/Library/Logs/parallels_mounter.log'
	rm -f '/Library/Logs/parallels_migration.log'
	rm -f '/var/log/prl_disp_service_server.log'
	rm -f "/var/root/Library/Preferences/${domain}.Parallels Desktop.plist"
	rm -f "/var/root/Library/Preferences/${domain}.desktop"*.plist
	rm -f "/var/root/Library/Preferences/${domain}.desktop"*.plist.lockfile
fi
