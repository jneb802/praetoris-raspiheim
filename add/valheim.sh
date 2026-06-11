#!/bin/bash
set -euo pipefail

export PATH=/usr/local/bin/:$PATH
cp /etc/resolv.conf /
sed -i s/"nameserver ".*/"nameserver 1.1.1.1"/g /resolv.conf
cp /resolv.conf /etc/resolv.conf

run_steamcmd() {
	local steamcmd_bin="/steamcmd/linux64/steamcmd"
	if [ ! -x "$steamcmd_bin" ]; then
		steamcmd_bin="/steamcmd/linux32/steamcmd"
	fi

	local steamcmd_dir
	steamcmd_dir="$(dirname "$steamcmd_bin")"
	export LD_LIBRARY_PATH="${steamcmd_dir}:${LD_LIBRARY_PATH:-}"
	timeout --foreground "${STEAMCMD_TIMEOUT:-600}" box64 "$steamcmd_bin" "$@"
}

update_valheim() {
	cd /steamcmd
	echo "Updating the server..."

	# The tarball starts with linux32 SteamCMD. After self-update, linux64 SteamCMD
	# is available and is substantially more stable under Box64.
	if [ ! -x /steamcmd/linux64/steamcmd ]; then
		set +e
		box64 ./linux32/steamcmd +login anonymous +quit
		local bootstrap_rc=$?
		set -e
		if [ "$bootstrap_rc" -ne 0 ] && [ "$bootstrap_rc" -ne 42 ]; then
			return "$bootstrap_rc"
		fi
	fi

	if [ ! -x /steamcmd/linux64/steamcmd ]; then
		echo "SteamCMD self-update did not install linux64/steamcmd" >&2
		return 1
	fi

	for attempt in 1 2 3; do
		echo "SteamCMD app_update attempt ${attempt}/3"
		if run_steamcmd \
			+@sSteamCmdForcePlatformType linux \
			+force_install_dir /valheim \
			+login anonymous \
			+app_update 896660 validate \
			+quit; then
			return 0
		fi
		sleep 5
	done

	echo "SteamCMD failed to install or update Valheim after 3 attempts" >&2
	return 1
}

install_bepinex() {
	if [ "${BEPINEX:-disabled}" != "enabled" ] && [ "${BEPINEX:-disabled}" != "1" ]; then
		return 0
	fi

	if [ -f /valheim/BepInEx/core/BepInEx.Preloader.dll ] && [ -f /valheim/doorstop_libs/libdoorstop_x64.so ]; then
		echo "BepInEx already installed."
		return 0
	fi

	local version="${BEPINEX_VERSION:-5.4.2333}"
	local url="https://thunderstore.io/package/download/denikson/BepInExPack_Valheim/${version}/"
	local tmp_dir="/tmp/bepinexpack-valheim"

	echo "Installing BepInExPack_Valheim ${version}..."
	rm -rf "$tmp_dir"
	mkdir -p "$tmp_dir"
	wget -q -O "$tmp_dir/bepinex.zip" "$url"
	unzip -q "$tmp_dir/bepinex.zip" -d "$tmp_dir/extracted"
	cp -a "$tmp_dir/extracted/BepInExPack_Valheim/." /valheim/
	chmod +x /valheim/start_server_bepinex.sh /valheim/start_game_bepinex.sh
	rm -rf "$tmp_dir"
}

# Upgrade Valheim to latest Version
if [ ! -f /valheim/start_server.sh ] || [ "$UPDATE" = enabled ] || [ "$UPDATE" = 1 ]; then
	update_valheim
fi;

install_bepinex

# Manage Persistency
cp -f /scripts/start_server.sh.tpl	/valheim/start_server.sh

cd /valheim

# Start Server
chmod +x ./start_server.sh
mkdir -p /data/logs
export LOG_FILE="/data/logs/valheim-$(date '+%d.%m.%y - %H:%M:%S').log"
touch $LOG_FILE
echo "$LOG_FILE" > /data/logs/log-link.txt
./start_server.sh 2>/dev/null | tee -a "$LOG_FILE"
sleep 600
