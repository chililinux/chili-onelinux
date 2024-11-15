#!/usr/bin/env bash
# shellcheck shell=bash disable=SC1091,SC2039,SC2166

#  make-onelinux.sh - Create a mini linux with busybox
#  Created: 2024/04/05
#  Altered: 2024/04/11
#
#  Copyright (c) 2024-2024, Vilmar Catafesta <vcatafesta@gmail.com>
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
#  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
#  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
#  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
#  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
#  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#############################################################################
export PS4='${red}${0##*/}${green}[$FUNCNAME]${pink}[$LINENO]${reset} '
#set -x
set -e
shopt -s extglob

#export LANGUAGE=en
#export LANGUAGE=pt_BR
export TEXTDOMAINDIR=/usr/share/locale
export TEXTDOMAIN=make-onelinux

readonly APP="${0##*/}"
readonly _VERSION_="1.0.11-20240411"
readonly DEPENDENCIES=(tar cpio sed tee wget qemu-system-x86_64)
##
#readonly KERNEL_VERSION=6.8.4
readonly KERNEL_VERSION=6.11.5
readonly BUSYBOX_VERSION=1.36.1
readonly KERNEL_MAJOR=$(sed 's/\([0-9]*\)[^0-9].*/\1/' <<<"$KERNEL_VERSION")
readonly LOCALDIR="$PWD"

function debug {
	whiptail \
		--fb \
		--clear \
		--backtitle "[debug]$0" \
		--title "[debug]$0" \
		--yesno "${*}\n" \
		0 40
	result=$?
	if ((result)); then
		exit
	fi
	return $result
}

function sh_diahora {
	local DIAHORA=$(date +"%d%m%Y-%T")
	local DIAHORA=${DIAHORA//:/}
	printf "%s\n" "$DIAHORA"
}

function sh_config {
	declare -g TICK="${white}[${COL_LIGHT_GREEN}✓${COL_NC}${white}]"
	declare -g CROSS="${white}[${COL_LIGHT_RED}✗${COL_NC}$white]"
	declare -g BOOTLOG="/tmp/$APP-$(sh_diahora).log"
  #sudo usermod -a -G tty $USER
  #sudo chmod g+rw /dev/tty8
	declare -g LOGGER='/dev/tty8'
	declare -gi quiet=0
	declare -g use_color=1
	declare -gi contador=0
	declare -gi njobs=14
	sh_setvarcolors
}

function log_error {
	printf "%30s:%-06d] : %s => %s\n" "$1" "$2" "$3 $4" >>"$BOOTLOG"
}

function cmdlogger {
	local lastcmd="$@"
	local line_number=${BASH_LINENO[0]}
	local status
	local error_output
	local script_name="${0##*/}[${FUNCNAME[1]}]"

	info_msg "Running '$*'"
	#   error_output=$( "$@" 2>&1 )
	eval "$@" 2>&1 | tee -i -a "$BOOTLOG" >"$LOGGER"
	#  status="${PIPESTATUS[0]}"
	status="$?"
	if [ $status -ne 0 ]; then
		error_output=$(echo "$error_output" | cut -d':' -f3-)
		log_error "$script_name" "$line_number" "$lastcmd" "$error_output"
	fi
	return $status
}

function sh_check_terminal {
	if [ ! -t 1 ]; then
		use_color=0
	fi
}

function print_color {
	if ((use_color)); then
		echo -e "${@//\033\[*/}"
	else
		echo -e "$@"
	fi
}

function sh_setvarcolors {
	if [[ -n "$(command -v "tput")" ]]; then
		#tput setaf 127 | cat -v  #capturar saida
		# Definir a variável de controle para restaurar a formatação original
		reset=$(tput sgr0)

		# Definir os estilos de texto como variáveis
		bold=$(tput bold)
		underline=$(tput smul)   # Início do sublinhado
		nounderline=$(tput rmul) # Fim do sublinhado
		reverse=$(tput rev)      # Inverte as cores de fundo e texto

		# Definir as cores ANSI como variáveis
		black=$(tput bold)$(tput setaf 0)
		red=$(tput bold)$(tput setaf 196)
		green=$(tput bold)$(tput setaf 2)
		yellow=$(tput bold)$(tput setaf 3)
		blue=$(tput setaf 4)
		pink=$(tput setaf 5)
		magenta=$(tput setaf 5)
		cyan=$(tput setaf 6)
		white=$(tput setaf 7)
		gray=$(tput setaf 8)
		orange=$(tput setaf 202)
		purple=$(tput setaf 125)
		violet=$(tput setaf 61)
		light_red=$(tput setaf 9)
		light_green=$(tput setaf 10)
		light_yellow=$(tput setaf 11)
		light_blue=$(tput setaf 12)
		light_magenta=$(tput setaf 13)
		light_cyan=$(tput setaf 14)
		bright_white=$(tput setaf 15)
	else
		sh_unsetVarColors
	fi
}

sh_unsetVarColors() {
	unset reset bold underline nounderline reverse
	unset black red green yellow blue pink magenta cyan white gray orange purple violet
	unset light_red light_yellow light_blue light_magent bright_white
}

die() {
	printf "${red}$CROSS ${pink}%03d/%03d => ${red}$(gettext "FATAL:") %s\n\033[m" "$ncontador" "$njobs" "$@"
	exit 1
}

function info_msg() {
	((++ncontador))
	#	((++njobs))
	printf "${green}$TICK ${pink}%03d/%03d => ${yellow}%s\n\033[m" "$ncontador" "$njobs" "$@"
}

function run_cmd {
	info_msg "$APP: $(gettext "Rodando") $*"
	eval "$@"
}

function sh_checkDependencies() {
	local d
	local errorFound=0
	declare -a missing

	for d in "${DEPENDENCIES[@]}"; do
		if [[ -z $(command -v "$d") ]]; then
			missing+=("$d")
			errorFound=1
			info_msg "${red}$(gettext "ERRO: não consegui encontrar o comando")${reset}: ${cyan}'$d'${reset}"
		else
			info_msg "${green}$(gettext "OK: comando")${reset}: ${cyan}'$d'${reset}"
		fi
	done

	if ((errorFound)); then
		echo "${yellow}---------------$(gettext "IMPOSSÍVEL CONTINUAR")-------------${reset}"
		echo "$(gettext "Este script precisa dos comandos listados acima")"
		echo "$(gettext "Instale-os e/ou verifique se eles estão em seu") ${red}\$PATH${reset}"
		echo "${yellow}---------------$(gettext "IMPOSSÍVEL CONTINUAR")-------------${reset}"
		die "$(gettext "Instalação abortada!")"
	fi
}

function create_kernel {
	info_msg "$(gettext "Baixando Kernel $KERNEL_VERSION...")"
	{
		[[ -d src ]] || mkdir -p src
		cd src
		##kernel
		wget --no-verbose --continue https://mirrors.edge.kernel.org/pub/linux/kernel/v$KERNEL_MAJOR.x/linux-$KERNEL_VERSION.tar.xz || die "$(gettext "Download Kernel. Cancelado!")"
		cd ..
	} 2>&1 | tee -i -a "$BOOTLOG" >"$LOGGER"

	info_msg "$(gettext "Construindo Kernel v$KERNEL_VERSION")"
	{
		cd src
		tar -xf linux-$KERNEL_VERSION.tar.xz
		ln -sf linux-$KERNEL_VERSION linux
		cd linux-$KERNEL_VERSION
		make defconfig
		sed -i 's/^CONFIG_LOCALVERSION=""/CONFIG_LOCALVERSION="-onelinux"/' .config
		sed -i 's/^#\(.*CONFIG_LOCALVERSION_AUTO.*\)$/CONFIG_LOCALVERSION_AUTO=y/' .config
		sed -i 's/^#\(.*CONFIG_TTY.*\)$/CONFIG_TTY=y/' .config
		sed -i 's/^CONFIG_DEFAULT_HOSTNAME="(none)"/CONFIG_DEFAULT_HOSTNAME="localhost"/' .config
		make -j$(nproc) || exit
		cd ..
		cd ..
		cp src/linux-$KERNEL_VERSION/arch/x86_64/boot/bzImage ./
	} 2>&1 | tee -i -a "$BOOTLOG" >"$LOGGER"
}

function create_busybox {
	info_msg "$(gettext "Baixando Busybox $BUSYBOX_VERSION...")"
	{
		[[ -d src ]] || mkdir -p src
		cd src
		##busybox
		wget -c https://busybox.net/downloads/busybox-1.36.1.tar.bz2 || die "$(gettext "Download Busybox. Cancelado!")"
		cd ..
	} 2>&1 | tee -i -a "$BOOTLOG" >"$LOGGER"

	info_msg "$(gettext "Construindo Busybox v$BUSYBOX_VERSION")"
	{
		cd src
		tar -xf busybox-$BUSYBOX_VERSION.tar.bz2
		ln -sf busybox-$BUSYBOX_VERSION busybox
		cd busybox-$BUSYBOX_VERSION
		make defconfig
		sed 's/^.*CONFIG_STATIC[^_].*$/CONFIG_STATIC=y/g' -i .config
		#make CC=musl-gcc -j$(nproc) busybox || exit
		LDFLAGS="--static" make -j$(nproc) busybox || exit
		cd ..
		cd ..
	} 2>&1 | tee -i -a "$BOOTLOG" >"$LOGGER"
}

function create_dropbear {
	## https://kmahyyg.medium.com/tiny-image-dropbear-with-busybox-6f5b65a44dfb
	#local DROPBEAR_FILE="DROPBEAR_2020.81.tar.gz"
	#local dropbear_source="https://github.com/mkj/dropbear/archive/refs/tags/$DROPBEAR_FILE"
	local DROPBEAR_FILE="dropbear-2024.84.tar.bz2"
	local dropbear_source="https://matt.ucc.asn.au/dropbear/$DROPBEAR_FILE"

	info_msg "$(gettext "Baixando dropbear $dropbear_source ...")"
	{
		[[ -d src ]] || mkdir -p src
		cd src
		##kernel
		wget --no-verbose --continue "$dropbear_source" || die "$(gettext "Download Dropbear. Cancelado!")"
		cd ..
	} 2>&1 | tee -i -a "$BOOTLOG" >"$LOGGER"

	info_msg "$(gettext "Construindo Dropbear")"
	{
		cd src
		tar -xf $DROPBEAR_FILE
		ln -sf dropbear-2024.84 dropbear
		cd dropbear
		autoconf
		autoheader
		./configure --enable-static --with-zlib=/usr/lib/x86_64-linux-gnu
		#				cp ./default_options.h localoptions.h
		CFLAGS="-I/usr/include -ffunction-sections -fdata-sections" \
			LDFLAGS="/usr/lib/x86_64-linux-gnu,-Wl,--gc-sections" \
			make -j$(nproc) PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" MULTI=1 STATIC=1 strip || exit
		cp dropbearmulti ../../initrd/bin
		cd ..
		cd ..
	} 2>&1 | tee -i -a "$BOOTLOG" >"$LOGGER"
}

function create_initrd {
	info_msg "$(gettext "Construindo Initramfs...")"
	{
		##initrd
		[[ -d initrd ]] || mkdir -p initrd
		cd $LOCALDIR/initrd
		mkdir -p dev etc/init.d lib mnt proc run sys tmp usr/bin var
		ln -sf usr/bin bin
		ln -sf usr/bin sbin
		[[ -e /dev/console ]] || mknod dev/console c 5 1
		[[ -e /dev/ttyS0 ]] || mknod /dev/ttyS0 c 4 64
		[[ -e /dev/null ]] || mknod dev/null c 1 3
	} 2>&1 | tee -i -a "$BOOTLOG" >"$LOGGER"

	info_msg "$(gettext "Linkando Busybox")"
	{
		cd $LOCALDIR/initrd
		pushd bin || die "cd bin"
		if cp $LOCALDIR/src/busybox-$BUSYBOX_VERSION/busybox ./; then
			for prog in $(./busybox --list); do
				ln -sfv busybox ./$prog
			done
		else
			die "cp $LOCADIR/src/busybox-$BUSYBOX_VERSION/busybox ./"
		fi
		popd
	} 2>&1 | tee -i -a "$BOOTLOG" >"$LOGGER"

	#create_dropbear
	info_msg "$(gettext "Linkando Dropbear")"
	{
		cd $LOCALDIR/initrd/bin
		dbmtoollets=(scp dropbearkey dropbearconvert dropbear ssh dbclient)
		for i in "${dbmtoollets[@]}"; do
			ln -sf dropbearmulti $i
		done
		cd -
	} 2>&1 | tee -i -a "$BOOTLOG" >"$LOGGER"

	{
		cd $LOCALDIR/initrd
		cat > etc/issue <<-EOF
			Bem vindo ao OneLinux
  ___             _     _
 / _ \ _ __   ___| |   (_)_ __  _   ___  __
| | | | '_ \ / _ \ |   | | '_ \| | | \ \/ /
| |_| | | | |  __/ |___| | | | | |_| |>  <
 \___/|_| |_|\___|_____|_|_| |_|\__,_/_/\_\

EOF
		cat > etc/inittab <<-EOF
			# Executed on startup
			::sysinit:/etc/init.d/rc.sysinit
			# Stuff to do when restarting the init process
			::restart:/bin/init
			# Run daemons
			#::wait:/etc/init.d/rc start
			::wait:/etc/init.d/network start
			#::once:/bin/syscheck&
			# Stuff to do before rebooting
			::shutdown:/etc/init.d/rc stop
			::shutdown:/etc/init.d/rc.stop
			::shutdown:/bin/umount -a -r
			::ctrlaltdel:/bin/reboot
			#null::respawn:/bin/infctld -m -c
			#null::respawn:/sbin/ntpclient -n -s -c 0 -l -h 10.0.0.254
			#null::respawn:/bin/dropbear -F -r /etc/persistent/dropbear_dss_host_key -r /etc/persistent/dropbear_rsa_host_key -p 22 
			#null::respawn:/bin/lighttpd -D -f /etc/lighttpd.conf
			#null::respawn:/bin/tinysnmpd /etc/snmp.conf /lib/tinysnmp
			null::respawn:/bin/telnetd -F -p 23
			#null::respawn:/bin/udapi-bridge -w -g -k -p 61780
			#null::respawn:/bin/udapi-server -g
			# Start an "askfirst" shell on the console
			ttyS0::askfirst:/sbin/getty -L ttyS0 115200 vt100
			#::askfirst:/bin/sh
		EOF

		cat > bin/syscheck <<-EOF
		#!/bin/sh
		#source /usr/etc/rc.d/rc.funcs
		fs() {
		        local SYSLOG_TAG=FileSystem
		        log_msg "${SYSLOG_TAG}" Start check...
		        sqfsck /dev/mtd3
		        if [ ! $? -eq 0 ]; then
		                log_msg "${SYSLOG_TAG}" Failed: $i
		                /bin/support /tmp/emerg /etc/persistent/emerg.supp emerg 1;
		        fi
		        sysctl -w vm.drop_caches=3 2>&1 > /dev/null
		        log_msg "${SYSLOG_TAG}" End check.
		}
		fs
		EOF

		cat > etc/passwd <<-EOF
			root:x:0:0:root:/root:/bin/sh
		EOF

		cat > etc/inittab.old <<-EOF
			# Executed on startup
			::sysinit:/etc/init.d/rc.sysinit
			# Stuff to do when restarting the init process
			::restart:/bin/init
			::askfirst:/bin/sh
			::ctrlaltdel:/bin/reboot
			::shutdown:/bin/umount -a -r
		EOF

		cat > etc/init.d/rc.sysinit <<-EOF
			#!/bin/sh

			#reset root password
			passwd -d root

			#mount -t proc none /proc
			#mount -t sysfs none /sys

			#service telnet
			#/usr/bin/telnetd
			#cat /etc/issue
			##https://busybox.net/FAQ.html#job_control
			#setsid sh -c 'exec sh </dev/tty1 >/dev/tty1 2>&1'
		EOF

		cat > etc/profile <<-EOF
			PATH="/usr/bin:/bin:/usr/sbin:/sbin"
			export PATH PS1

			# habits from distros...
			alias sudo=''
			alias ..='cd ..'
			alias .1='cd ..'
			alias .2='cd ../..'
			alias .3='cd ../../..'
			alias CD='cd'
			alias dir='ls -la --color=auto'
			alias DIR='dir'
			alias ED='nano'
			alias ack='ack -n --color-match=red'
			alias cls='clear'
			alias copy='cp'
			alias cp='cp -v'
			alias dcomprimtar='tar -vzxf'
			alias dd='dd status=progress'
			alias ddel='find -name  | xargs rm -fvR'
			alias debug='set -o nounset; set -o xtrace'
			alias del='rm'
			alias deltraco='rm --'
			alias df='df -hT --total'
			alias dfc='dfc -afTnc always | sort -k2 -k1'
			alias diff='diff --color=auto'
			alias dirm='ls -h -ls -Sr --color=auto'
			alias dirt='la -h -ls -Sr -rt --color=auto'
			alias disable='systemctl disable'
			alias discos='udisksctl status'
			alias dmesg='dmesg -T -x'
			alias dmesgerr='dmesg -T -x | grep -P '\''(:err |:warn )'\'''
			alias du='du -h'
			alias dude='wine /root/.wine/drive_c/'\''Program Files'\''/Dude/dude &'
			alias dut='du -hs * | sort -h'
			alias ed='nano'
			alias egrep='egrep --color=auto'
			alias enable='systemctl enable'
			alias fdisk='fdisk -l'
			alias fgrep='fgrep --color=auto'
			alias fs='file -s'
			alias github='cd /github ; ls'
			alias grep='grep --color=auto'
			alias gvs='sudo vgs'
			alias h='history'
			alias j='jobs -l'
			alias kk='ll'
			alias l='ls -CF'
			alias la='ls -A'
			alias lc='ls -ltcr'
			alias libpath='echo -e ${LD_LIBRARY_PATH//:/\\n}'
			alias listen='netstat -anp | grep :'
			alias lk='ls -lSr'
			alias ll='ls -l'
			alias lm='ll |more'
			alias lr='ll -R'
			alias ls='ls -CF -h --color=auto --group-directories-first'
			alias lt='ls -ltr'
			alias lu='ls -ltur'
			alias lvma='lvm vgchange -a y -v'
			alias lvs='sudo lvs'
			alias lx='ls -lXB'
			alias make='xtitle Making chili-onelinux ; make'
			alias maketar='chili-maketar'
			alias md='mkdir'
			alias mem='free -h'
			alias mkd='make install DESTDIR=$l'
			alias mkdir='mkdir -pv'
			alias moer='more'
			alias moew='more'
			alias more='less'
			alias mv='mv -v'
			alias nm-ativo='systemctl --type=service'
			alias ouvindo='netstat -anp | grep :'
			alias pkgdir='echo $PWD'
			alias port='sudo sockstat | grep .'
			alias portas='sudo nmap -sS -p- localhost | grep .'
			alias portas1='sudo lsof -i | grep .'
			alias pvs='sudo pvs'
			alias pxe='cd /mnt/NTFS/software'
			alias pyc='python -OO -c '\''import py_compile; py_compile.main()'\'''
			alias r='echo $OLDPWD'
			alias rd='rmdir'
			alias ren='mv'
			alias rm='rm -v'
			alias rmake='[ ! -d /tmp/.hbmk ] && { mkdir -p /tmp/.hbmk; }; hbmk2 -info -comp=gcc   -cpp=yes -jobs=36'
			alias rsync='rsync --progress -Cravzp'
			alias rsync-pbw='rsync --progress -Cravzp --rsh='\''ssh -v -l backup'\'' backup@10.0.0.254:/ /home/vcatafesta/backup/rb-3011/'
			alias rsync-pmv='rsync --progress -Cravzp --rsh='\''ssh -v -l backup'\'' backup@primavera.sybernet.changeip.org:/ /home/vcatafesta/backup/primavera'
			alias sc='sudo sftp -P 65002 u356719782@185.211.7.40:/home/u356719782/domains/chililinux.com/public_html/packages/core/'
			alias sci='cd /home/sci-work/; ./sci'
			alias sl='cd /home/vcatafesta/sci/src.linux ; ls'
			alias smbmount='mount -t cifs -o username=vcatafesta,password=451960 //10.0.0.68/c /root/windows'
			alias src='cd /sources/blfs'
			alias srcdir='/${srcdir%%/*}'
			alias start='sr'
			alias status='systemctl status'
			alias stop='st'
			alias tarbz2='tar -xvjf'
			alias targz='tar -xzvf'
			alias tarxz='tar -Jxvf'
			alias tmd='tail -f /var/log/dnsmasq.log'
			alias tmk='multitail -f /var/log/mikrotik/10.0.0.254.2018.01.log'
			alias tml='tail -f /var/log/lastlog'
			alias tmm='tail -f /var/log/mail.log | grep .'
			alias top='xtitle Processes on  && top'
			alias untar='tar -xvf'
			alias vdir='vdir --color=auto'
			alias ver='lsb_release -a'
			alias versao='lsb_release -a'
			alias vf='cd'
			alias vgs='sudo vgs'
			alias wget='wget --no-check-certificate'
			alias win='lightdm'
			alias xcopy='cp -Rpva'
			alias xcopyn='cp -Rpvan'
			alias xcopyu='cp --recursive -p --verbose --archive --update'
			alias xs='cd'
			# shortcuts
			alias la='ls $LS_OPTIONS -all -h'
			umask 022

			# set a fancy prompt (non-color, overwrite the one in /etc/profile)
			if [ $(id -u) -eq 0 ]; then
			  # root user
			  export PS1='\n\e[31m\e[1m\u@\h\e[0m \e[94m\w\n \e[31m\e[1m#\e[0m\e[0m\e[39m\e[49m '
			else
			  # non root
			  export PS1='\n\e[92m\e[1m\u@\h\e[0m \e[94m\w\n \e[92m\e[1m$\e[0m\e[0m\e[39m\e[49m '
			fi

			# Set up a red prompt for root and a green one for users.
			#NORMAL="\[\e[0m\]"
			#RED="\[\e[1;31m\]"
			#GREEN="\[\e[1;32m\]"
			#if [[ $EUID == 0 ]] ; then
			  #PS1="$RED\u [ $NORMAL\w$RED ]# $NORMAL"
			#else
			  #PS1="$GREEN\u [ $NORMAL\w$GREEN ]\$ $NORMAL"
			#fi
		EOF

		cat > etc/init.d/network <<-EOF
			#configure network
			#ifconfig lo up
			#ifconfig eth0 up
			#udhcpc -i eth0
			ip link set lo up
			ip link set eth0 up
			ip addr add 10.0.2.10/24 broadcast 10.0.2.255 dev eth0
			ip route add 10.0.2.2 via 10.0.2.10 dev eth0
		EOF

		cat > etc/hosts <<-EOF
			127.0.0.1       localhost.localdomain   localhost
		EOF

		cat > etc/resolv.conf <<-EOF
			nameserver      8.8.8.8
		EOF

		touch etc/fstab

		chmod +x etc/init.d/rc.sysinit
		chmod +x etc/init.d/network

		cat > init <<-EOF
			#!/bin/sh

			# crucial mountpoints
			mount -t proc none /proc
			mount -t sysfs none /sys
			#mount -t sysfs sysfs /sys
			#mount -t tmpfs dev /dev
			mount -t devtmpfs udev /dev
			if [ -d /sys/kernel/debug ]
			then
				mount -t debugfs none /sys/kernel/debug
			fi
			mount -n tmpfs /var -t tmpfs -o size=9437184
			sysctl -w kernel.printk="2 4 1 7"

			# setup console, consider using ptmx?
			CIN=/dev/console
			COUT=/dev/console
			exec </dev/console &>/dev/console
			mknod /dev/gpio c 127 0
			mkdir /dev/pts /dev/shm
			# rest of the mounts
			mount none /dev/pts -t devpts
			if [ -e /proc/bus/usb ]; then
		        mount none /proc/bus/usb -t usbfs
			fi
			echo "...mounts done"
			mkdir -p /var/run /var/tmp /var/log /var/etc /var/etc/persistent /var/lock
			echo "...filesystem init done"

			echo "...running /sbin/init"
			exec /sbin/init
			echo "INTERNAL ERROR!!! Cannot run /sbin/init."
EOF
#/bin/sh
#poweroff -f
		chmod -R 777 .
		chmod 1777 tmp
		find . | cpio -o -H newc >../initrd.img
		cd ..
	} 2>&1 | tee -i -a "$BOOTLOG" >"$LOGGER"
}

function run_image {
	if [[ -e bzImage && -e initrd.img ]]; then
		qemu-system-x86_64 \
			-smp "$(nproc)" \
			-k pt-br \
			-machine accel=kvm \
			-m 1024 \
			-kernel bzImage \
			-initrd initrd.img \
			-net nic -net user \
			-nographic \
			-append "console=ttyS0"
	else
		die "$(gettext "Kernel (bzImage) ou Initramfs (initrd.img) não encontrado. Cancelado!")"
	fi
}

function sh_checkroot {
	if [ "$(id -u)" -ne 0 ]; then
		die "$APP: $(gettext "precisa de permissões de root para continuar, saindo.")"
	fi
}

function sh_usage {
	cat <<-EOF
		Usage: $APP ${red}[$(gettext "operação")]${reset}
			${red}$(gettext "operação:")${reset}
		        -A          ${cyan}$(gettext "Criar todo sistema (default)")${reset}
		        -B          ${cyan}$(gettext "Criar somente Busybox")${reset}
		        -D          ${cyan}$(gettext "Criar somente Dropbear")${reset}
		        -K          ${cyan}$(gettext "Criar somente Kernel")${reset}
		        -I          ${cyan}$(gettext "Criar somente Initramfs")${reset}
		        -R          ${cyan}$(gettext "Executar image")${reset}
		        -n          ${cyan}$(gettext "Desativar cores na saída")${reset}
		        -h          ${cyan}$(gettext "Este help")${reset}
	EOF
	exit 0
}

sh_config
[[ $# -eq 0 ]] && die "nenhuma operação especificada (use -h para obter ajuda)"
[[ $1 = -h ]] && sh_usage

sh_checkDependencies
# Process command line options using getopts
while getopts "ABDKIiRrnh" opt; do
	case $opt in
	A)
		info_msg "$(gettext "Construindo... Verifique log:") ${white}tail -f $BOOTLOG${reset}"
		create_kernel
		create_busybox
		create_dropbear
		create_initrd
		exit 0
		;;
	B)
		info_msg "$(gettext "Construindo... Verifique log:") ${white}tail -f $BOOTLOG${reset}"
		create_busybox
		exit 0
		;;
	D)
		info_msg "$(gettext "Construindo... Verifique log:") ${white}tail -f $BOOTLOG${reset}"
		create_dropbear
		exit 0
		;;
	K)
		info_msg "$(gettext "Construindo... Verifique log:") ${white}tail -f $BOOTLOG${reset}"
		create_kernel
		exit 0
		;;
	i|I)
		info_msg "$(gettext "Construindo... Verifique log:") ${white}tail -f $BOOTLOG${reset}"
		create_initrd
		exit 0
		;;
	r|R)
		info_msg "$(gettext "Construindo... Verifique log:") ${white}tail -f $BOOTLOG${reset}"
		run_image
		exit 0
		;;
	h)
		sh_usage
		;;
	n)
		use_color=0
		sh_unsetVarColors
		;;
	\? | --)
		die "$(gettext "Operação inválida"): -$OPTARG"
		;;
	esac
done
shift $((OPTIND - 1))
