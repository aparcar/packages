# sends a request to the demo update server
UPDATESERVER="http://betaupdate.libremesh.org"

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

	json_init
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
		uclient-fetch -O "/tmp/sysupgrade.bin" "${sysupgrade_url/https/http}"
		echo "install sysupgrade? [y/N]"
		read install_sysupgrade
		if [ "$install_sysupgrade" == "y" ]; then
			echo "installing sysupgrade"
			ubus call attendedsysupgrade sysupgrade
		fi
	fi
}

upgrade_check
