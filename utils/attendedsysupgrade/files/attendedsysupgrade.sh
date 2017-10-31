# sends a request to the demo update server
UPDATESERVER="http://betaupdate.libremesh.org"
echo "untrusted comment: worker 33" > /tmp/worker_pubkey
echo "RWRFTbSNRlxUI3TtRQkWEwxs384u9jv2zdPvP5ItA1XxA+JhCjIUkDbp" >> /tmp/worker_pubkey

. /usr/share/libubox/jshn.sh


function gen_json () {
	json_init
	json_load "$(ubus call system board)"
	json_get_var board_name board_name
	json_select release
	json_get_var release version
	json_get_var distro distribution
	json_get_var release_target target
	target="$(echo $release_target | awk -F'\/' '{ print $1 }')"
	subtarget="$(echo $release_target | awk -F'\/' '{ print $2 }')"

	json_init;
	json_add_object "packages"

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

	json_close_object
	json_add_string "distro" $distro
	json_add_string "version" $release
	json_add_string "target" $target
	json_add_string "subtarget" $subtarget
	export REQUEST_JSON="$(json_dump)"
}

IMAGEBUILDER=0
BUILDING=0
function server_request () {
	export content="$(uclient-fetch --post-data "$REQUEST_JSON" "$UPDATESERVER/$REQUEST_PATH" -O- 2>/tmp/uclient-statuscode)"
	export statuscode=$(expr "$(cat /tmp/uclient-statuscode)" : '.*HTTP error \([0-9][0-9][0-9]\)')
	if [ -z $statuscode ]; then
		export statuscode=200
	fi
}

gen_json
export REQUEST_PATH='api/upgrade-check'

function upgrade_check () {
	server_request
	if [ $statuscode -eq 200 ]; then
		upgrade_check_200
	elif [ $statuscode -eq 500 ]; then
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
		sleep 1
		upgrade_check
	fi
}

function upgrade_check_200() {
	json_load "$content"
	json_get_var version version
	if [ "$version" != '' ]; then
		echo "new release found: $version"
		echo "request firmware and download?"
		read request_sysupgrade
		#request_sysupgrade="y"
		if [ "$request_sysupgrade" == "y" ]; then
			echo "requesting image"
			export IMAGEBUILDER=0
			export BUILDING=0
			image_request
		fi
	fi
}

function image_request() {
	export REQUEST_PATH='api/image-request'
	server_request
	echo $statuscode
	cat /tmp/uclient-statuscode
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
		sleep 1
		image_request
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
		sleep 1
		image_request
	elif [ $statuscode -eq 200 ]; then
		json_load "$content"
		json_get_var sysupgrade_url sysupgrade
		json_get_var sysupgrade_checksum checksum
		uclient-fetch -O "/tmp/sysupgrade.bin" "${sysupgrade_url/https/http}"
		md5_checksum="$(md5sum /tmp/sysupgrade.bin | awk '{ print $1 }')"
		echo $md5_checksum
		echo $sysupgrade_checksum
		if [ "$md5_checksum" != "$sysupgrade_checksum" ]; then
			echo "checksum: missmatch!"
			exit 1
		else
			echo "checksum: valid"
		fi
		uclient-fetch -O "/tmp/sysupgrade.bin.sig" "${sysupgrade_url/https/http}.sig"
		usign -V -m /tmp/sysupgrade.bin -p /tmp/worker_pubkey -q
		if [ $? != 0 ]; then
			echo "signature: missmatch!"
			exit 1
		else
			echo "signature: valid"
			echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
			echo "not really secure just yet due to http"
			echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
		fi
		echo "install sysupgrade? [y/N]"
		read install_sysupgrade
		if [ "$install_sysupgrade" == "y" ]; then
			echo "installing sysupgrade"
			if [ -f "/tmp/sysupgrade.bin" ]; then
				/etc/init.d/uhttpd stop
				/etc/init.d/dropbear stop
				sleep 1;
				if [ "$keep_settings" -eq "0" ]; then
					keep_settings_param="-n"
				fi
				/sbin/sysupgrade $keep_settings_param /tmp/sysupgrade.bin
			else
				echo "could not find /tmp/sysupgrade.bin"
			fi
		fi
	fi
}

upgrade_check
