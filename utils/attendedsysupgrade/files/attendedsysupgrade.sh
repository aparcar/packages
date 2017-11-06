#!/bin/sh
# sends a request to the demo update server

CHECK_SIGNATURE=0

. /usr/share/libubox/jshn.sh

function load_device_info() {
	json_load "$(ubus call system board)"
	json_get_var board_name board_name
	json_select release
	json_get_var release version
	json_get_var distro distribution
	json_get_var release_target target
	target="$(echo $release_target | awk -F'\/' '{ print $1 }')"
	subtarget="$(echo $release_target | awk -F'\/' '{ print $2 }')"
}

function load_uci() {
	if [ -e /etc/confi/attendedsysupgrade ]; then
		export UPDATESERVER="$(uci get attendedsysupgrade.server.url)"
	else
		echo "config file missing"
		exit 1
	fi
}

function gen_json_board() {
	json_add_string "distro" $distro
	json_add_string "target" $target
	json_add_string "subtarget" $subtarget
}

function gen_json_check () {
	json_init;
	gen_json_board;
	json_add_string "version" $release
	json_add_object "packages";

	if [ -f /usr/lib/opkg/status ]; then
		while read var p1 p2 p3; do
			if [ "$var" = "Package:" ]; then
				pkg="$p1"
			fi
			if [ "$var" = "Version:" ]; then
				version="$p1"
			fi

			if [ "$var" = "Status:" \
				-a "$p1" = "install" \
				-a "$p2" = "user" \
				-a "$p3" = "installed" ]; then
			json_add_string "$pkg" "$version";
			fi
		done < /usr/lib/opkg/status
	fi
	json_close_object;

	export REQUEST_JSON="$(json_dump)"
}

IMAGEBUILDER=0
BUILDING=0
function server_request() {
	export content="$(uclient-fetch --post-data "$REQUEST_JSON" "$UPDATESERVER/$REQUEST_PATH" -O- 2>/tmp/uclient-statuscode)"
	export statuscode=$(expr "$(cat /tmp/uclient-statuscode)" : '.*HTTP error \([0-9][0-9][0-9]\)')
	if [ -z $statuscode ]; then
		if [ $(expr "$(cat /tmp/uclient-statuscode)" : '.*full content requested') != 0 ]; then
			export statuscode=206
		elif [ $(expr "$(cat /tmp/uclient-statuscode)" : '.*prematurely') != 0 ]; then
			export statuscode=204
		else
			export statuscode=200
		fi
	fi
	if [ $statuscode -eq 500 ]; then
		echo "internal server error"
		echo "$content"
		exit 1
	elif [ $statuscode -eq 400 ]; then
		echo "bad request"
		echo "$content"
		exit 1
	elif [ $statuscode -eq 201 ]; then
		if [ $IMAGEBUILDER -eq 0 ]; then
			echo -n "setting up imagebuilder"
			IMAGEBUILDER=1
		else
			echo -n "."
		fi
		sleep 3
		server_request
	elif [ $statuscode -eq 204 ]; then
		echo "system is up to date"
		exit 0
	elif [ $statuscode -eq 206 ]; then
		if [ $IMAGEBUILDER -eq 1 ] && [ $BUILDING -eq 0 ]; then
			echo ""
		fi
		if [ $BUILDING -eq 0 ]; then
			echo ""
			echo -n "building image"
			BUILDING=1
		else
			echo -n "."
		fi
		sleep 3
		server_request
	fi
}

function upgrade_check_200() {
	json_load "$content"
	json_get_var version version
	gen_json_board

	if [ "$version" != '' ]; then
		echo "new release found: $version"
		echo "request firmware and download? [y/N]"
		read request_sysupgrade
		#request_sysupgrade="y"
		if [ "$request_sysupgrade" == "y" ]; then
			echo "requesting image"
			export IMAGEBUILDER=0
			export BUILDING=0
			export REQUEST_PATH='api/upgrade-request'
			server_request;
			json_init;
			gen_json_board;
			json_add_string "version" "$version"
			json_add_string "packages" "$packages"
			upgrade_request_200;
		fi
	fi
}

function check_checksum() {
	md5_checksum="$(md5sum /tmp/firmware.bin | awk '{ print $1 }')"
	if [ "$md5_checksum" != "$sysupgrade_checksum" ]; then
		echo "checksum: missmatch!"
		exit 1
	else
		echo "checksum: valid"
	fi
}

function check_signature() {
	if [ $CHECK_SIGNATURE -eq 1 ]; then
		if [ -e /etc/build_pubkey ]; then
			uclient-fetch -O "/tmp/firmware.bin.sig" "${sysupgrade_url/https/http}.sig"
			usign -V -m /tmp/firmware.bin -p /tmp/worker_pubkey -q
			if [ $? != 0 ]; then
				echo "signature: missmatch!"
				exit 1
			else
				echo "signature: valid"
				echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
				echo "not really secure just yet due to http"
				echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
			fi
		else
			echo "signature: check skipped"
		fi
	else
		echo "no public of server found"
		exit 1
	fi
}

function check_memory() {
	system_info="$(ubus call system info)";
	json_load "$system_info";
	json_select "memory";
	json_get_var free free
	if [ $free -lt $sysupgrade_filesize ]; then
		echo "more memory needed";
		exit 1
	fi
}

function upgrade_request_200() {
	json_load "$content"
	json_get_var sysupgrade_url sysupgrade
	json_get_var sysupgrade_checksum checksum
	json_get_var sysupgrade_filesize filesize
	uclient-fetch -O "/tmp/firmware.bin" "${sysupgrade_url/https/http}"
	check_checksum;
	check_signature;
	check_memory;

	echo "install sysupgrade? [y/N]"
	read install_sysupgrade
	if [ "$install_sysupgrade" == "y" ]; then
		ubus call rpc-sys upgrade_start
		echo "sysupgrade started - please wait for reboot"
	else
		echo "sysupgrade aborted"
	fi
}

load_uci;
load_device_info;
gen_json_check;
export REQUEST_PATH='api/upgrade-check';
server_request;
upgrade_check_200;
