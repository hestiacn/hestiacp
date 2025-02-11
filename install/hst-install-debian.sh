#!/bin/bash

# ======================================================== #
#
# Hestia Control Panel Installer for Debian
# https://www.hestiacp.com/
#
# Currently Supported Versions:
# Debian 11 12
#
# ======================================================== #

#----------------------------------------------------------#
#                  Variables&Functions                     #
#----------------------------------------------------------#
export PATH=$PATH:/sbin
export DEBIAN_FRONTEND=noninteractive
RHOST='apt.hestiacp.com'
VERSION='debian'
HESTIA='/usr/local/hestia'

LOG="/root/hst_install_backups/hst_install-$(date +%d%m%Y%H%M).log"
memory=$(grep 'MemTotal' /proc/meminfo | tr ' ' '\n' | grep [0-9])
hst_backups="/root/hst_install_backups/$(date +%d%m%Y%H%M)"
spinner="/-\|"
os='debian'
release="$(cat /etc/debian_version | tr "." "\n" | head -n1)"
codename="$(cat /etc/os-release | grep VERSION= | cut -f 2 -d \( | cut -f 1 -d \))"
architecture="$(arch)"
HESTIA_INSTALL_DIR="$HESTIA/install/deb"
HESTIA_COMMON_DIR="$HESTIA/install/common"
VERBOSE='no'

# Define software versions
HESTIA_INSTALL_VER='1.9.2'
# Supported PHP versions
multiphp_v=("5.6" "7.0" "7.1" "7.2" "7.3" "7.4" "8.0" "8.1" "8.2" "8.3" "8.4")
# One of the following PHP versions is required for Roundcube / phpmyadmin
multiphp_required=("7.3" "7.4" "8.0" "8.1" "8.2" "8.3")
# Default PHP version if none supplied
fpm_v="8.3"
# MariaDB version
mariadb_v="11.4"
# Node.js version
node_v="20"

# Defining software pack for all distros
software="acl apache2 apache2-suexec-custom apache2-suexec-pristine apache2-utils awstats bc bind9 bsdmainutils bsdutils
  clamav-daemon cron curl dnsutils dovecot-imapd dovecot-managesieved dovecot-pop3d dovecot-sieve e2fslibs e2fsprogs
  exim4 exim4-daemon-heavy expect fail2ban flex ftp git hestia=${HESTIA_INSTALL_VER} hestia-nginx hestia-php hestia-web-terminal
  idn2 imagemagick ipset jq libapache2-mod-fcgid libapache2-mod-php$fpm_v libapache2-mpm-itk libmail-dkim-perl lsb-release
  lsof mariadb-client mariadb-common mariadb-server mc mysql-client mysql-common mysql-server net-tools nginx nodejs openssh-server
  php$fpm_v php$fpm_v-apcu php$fpm_v-bz2 php$fpm_v-cgi php$fpm_v-cli php$fpm_v-common php$fpm_v-curl php$fpm_v-gd
  php$fpm_v-imagick php$fpm_v-imap php$fpm_v-intl php$fpm_v-ldap php$fpm_v-mbstring php$fpm_v-mysql php$fpm_v-opcache
  php$fpm_v-pgsql php$fpm_v-pspell php$fpm_v-readline php$fpm_v-xml php$fpm_v-zip postgresql postgresql-contrib
  proftpd-basic quota rrdtool rsyslog spamd sysstat unrar-free unzip util-linux vim-common vsftpd xxd whois zip zstd bubblewrap restic"

installer_dependencies="apt-transport-https ca-certificates curl dirmngr gnupg openssl wget sudo"

# Defining help function
help() {
	echo "Usage: $0 [OPTIONS]
  -a, --apache            Install Apache        [yes|no]  default: yes
  -w, --phpfpm            Install PHP-FPM       [yes|no]  default: yes
  -o, --multiphp          Install MultiPHP      [yes|no]  default: no
  -v, --vsftpd            Install VSFTPD        [yes|no]  default: yes
  -j, --proftpd           Install ProFTPD       [yes|no]  default: no
  -k, --named             Install BIND          [yes|no]  default: yes
  -m, --mysql             Install MariaDB       [yes|no]  default: yes
  -M, --mysql8            Install MySQL 8       [yes|no]  default: no
  -g, --postgresql        Install PostgreSQL    [yes|no]  default: no
  -x, --exim              Install Exim          [yes|no]  default: yes
  -z, --dovecot           Install Dovecot       [yes|no]  default: yes
  -Z, --sieve             Install Sieve         [yes|no]  default: no
  -c, --clamav            Install ClamAV        [yes|no]  default: yes
  -t, --spamassassin      Install SpamAssassin  [yes|no]  default: yes
  -i, --iptables          Install iptables      [yes|no]  default: yes
  -b, --fail2ban          Install Fail2Ban      [yes|no]  default: yes
  -q, --quota             Filesystem Quota      [yes|no]  default: no
  -L, --resourcelimit     Resource Limitation   [yes|no]  default: no
  -W, --webterminal       Web Terminal          [yes|no]  default: no
  -d, --api               Activate API          [yes|no]  default: yes
  -r, --port              Change Backend Port             default: 8083
  -l, --lang              Default language                default: en
  -y, --interactive       Interactive install   [yes|no]  default: yes
  -s, --hostname          Set hostname
  -e, --email             Set admin email
  -u, --username          Set admin user
  -p, --password          Set admin password
  -D, --with-debs         Path to Hestia debs
  -f, --force             Force installation
  -h, --help              Print this help

  Example: bash $0 -e demo@hestiacp.com -p p4ssw0rd --multiphp yes"
	exit 1
}

# Defining file download function
download_file() {
	wget $1 -q --show-progress --progress=bar:force
}

# Defining password-gen function
gen_pass() {
	matrix=$1
	length=$2
	if [ -z "$matrix" ]; then
		matrix="A-Za-z0-9"
	fi
	if [ -z "$length" ]; then
		length=16
	fi
	head /dev/urandom | tr -dc $matrix | head -c$length
}

# Defining return code check function
check_result() {
	if [ $1 -ne 0 ]; then
		echo "Error: $2"
		exit $1
	fi
}

# Source conf in installer
source_conf() {
	while IFS='= ' read -r lhs rhs; do
		if [[ ! $lhs =~ ^\ *# && -n $lhs ]]; then
			rhs="${rhs%%^\#*}" # Del in line right comments
			rhs="${rhs%%*( )}" # Del trailing spaces
			rhs="${rhs%\'*}"   # Del opening string quotes
			rhs="${rhs#\'*}"   # Del closing string quotes
			declare -g $lhs="$rhs"
		fi
	done < $1
}

# Defining function to set default value
set_default_value() {
	eval variable=\$$1
	if [ -z "$variable" ]; then
		eval $1=$2
	fi
	if [ "$variable" != 'yes' ] && [ "$variable" != 'no' ]; then
		eval $1=$2
	fi
}

# Defining function to set default language value
set_default_lang() {
	if [ -z "$lang" ]; then
		eval lang=$1
	fi
	lang_list="ar az bg bn bs ca cs da de el en es fa fi fr hr hu id it ja ka ku ko nl no pl pt pt-br ro ru sk sq sr sv th tr uk ur vi zh-cn zh-tw"
	if ! (echo $lang_list | grep -w $lang > /dev/null 2>&1); then
		eval lang=$1
	fi
}

# Define the default backend port
set_default_port() {
	if [ -z "$port" ]; then
		eval port=$1
	fi
}

# Write configuration KEY/VALUE pair to $HESTIA/conf/hestia.conf
write_config_value() {
	local key="$1"
	local value="$2"
	echo "$key='$value'" >> $HESTIA/conf/hestia.conf
}

# Sort configuration file values
# Write final copy to $HESTIA/conf/hestia.conf for active usage
# Duplicate file to $HESTIA/conf/defaults/hestia.conf to restore known good installation values
sort_config_file() {
	sort $HESTIA/conf/hestia.conf -o /tmp/updconf
	mv $HESTIA/conf/hestia.conf $HESTIA/conf/hestia.conf.bak
	mv /tmp/updconf $HESTIA/conf/hestia.conf
	rm -f $HESTIA/conf/hestia.conf.bak
	if [ ! -d "$HESTIA/conf/defaults/" ]; then
		mkdir -p "$HESTIA/conf/defaults/"
	fi
	cp $HESTIA/conf/hestia.conf $HESTIA/conf/defaults/hestia.conf
}

# todo add check for usernames that are blocked
validate_username() {
	if [[ "$username" =~ ^[[:alnum:]][-|\.|_[:alnum:]]{0,28}[[:alnum:]]$ ]]; then
		if [ -n "$(grep ^$username: /etc/passwd /etc/group)" ]; then
			echo -e "\n用户名或组已存在.请选择一个新的用户名或删除该用户及/或组."
		else
			return 1
		fi
	else
		echo -e "\n请使用有效的用户名（例如 user）."
		return 0
	fi
}

validate_password() {
	if [ -z "$vpass" ]; then
		return 0
	else
		return 1
	fi
}

# Validate hostname according to RFC1178
validate_hostname() {
	# remove extra .
	servername=$(echo "$servername" | sed -e "s/[.]*$//g")
	servername=$(echo "$servername" | sed -e "s/^[.]*//")
	if [[ $(echo "$servername" | grep -o "\." | wc -l) -gt 1 ]] && [[ ! $servername =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		# Hostname valid
		return 1
	else
		# Hostname invalid
		return 0
	fi
}

validate_email() {
	if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[[:alnum:].-]+\.[A-Za-z]{2,63}$ ]]; then
		# Email invalid
		return 0
	else
		# Email valid
		return 1
	fi
}

version_ge() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" -o -n "$1" -a "$1" = "$2"; }

#----------------------------------------------------------#
#                    Verifications                         #
#----------------------------------------------------------#

# Creating temporary file
tmpfile=$(mktemp -p /tmp)

# Translating argument to --gnu-long-options
for arg; do
	delim=""
	case "$arg" in
		--apache) args="${args}-a " ;;
		--phpfpm) args="${args}-w " ;;
		--vsftpd) args="${args}-v " ;;
		--proftpd) args="${args}-j " ;;
		--named) args="${args}-k " ;;
		--mysql) args="${args}-m " ;;
		--mariadb) args="${args}-m " ;;
		--mysql-classic) args="${args}-M " ;;
		--mysql8) args="${args}-M " ;;
		--postgresql) args="${args}-g " ;;
		--exim) args="${args}-x " ;;
		--dovecot) args="${args}-z " ;;
		--sieve) args="${args}-Z " ;;
		--clamav) args="${args}-c " ;;
		--spamassassin) args="${args}-t " ;;
		--iptables) args="${args}-i " ;;
		--fail2ban) args="${args}-b " ;;
		--multiphp) args="${args}-o " ;;
		--quota) args="${args}-q " ;;
		--resourcelimit) args="${args}-L " ;;
		--webterminal) args="${args}-W " ;;
		--port) args="${args}-r " ;;
		--lang) args="${args}-l " ;;
		--interactive) args="${args}-y " ;;
		--api) args="${args}-d " ;;
		--hostname) args="${args}-s " ;;
		--email) args="${args}-e " ;;
		--username) args="${args}-u " ;;
		--password) args="${args}-p " ;;
		--force) args="${args}-f " ;;
		--with-debs) args="${args}-D " ;;
		--help) args="${args}-h " ;;
		*)
			[[ "${arg:0:1}" == "-" ]] || delim="\""
			args="${args}${delim}${arg}${delim} "
			;;
	esac
done
eval set -- "$args"

# Parsing arguments
while getopts "a:w:v:j:k:m:M:g:d:x:z:Z:c:t:i:b:r:o:q:L:l:y:s:u:e:p:W:D:fh" Option; do
	case $Option in
		a) apache=$OPTARG ;;        # Apache
		w) phpfpm=$OPTARG ;;        # PHP-FPM
		o) multiphp=$OPTARG ;;      # Multi-PHP
		v) vsftpd=$OPTARG ;;        # Vsftpd
		j) proftpd=$OPTARG ;;       # Proftpd
		k) named=$OPTARG ;;         # Named
		m) mysql=$OPTARG ;;         # MariaDB
		M) mysql8=$OPTARG ;;        # MySQL
		g) postgresql=$OPTARG ;;    # PostgreSQL
		x) exim=$OPTARG ;;          # Exim
		z) dovecot=$OPTARG ;;       # Dovecot
		Z) sieve=$OPTARG ;;         # Sieve
		c) clamd=$OPTARG ;;         # ClamAV
		t) spamd=$OPTARG ;;         # SpamAssassin
		i) iptables=$OPTARG ;;      # Iptables
		b) fail2ban=$OPTARG ;;      # Fail2ban
		q) quota=$OPTARG ;;         # FS Quota
		L) resourcelimit=$OPTARG ;; # Resource Limitaiton
		W) webterminal=$OPTARG ;;   # Web Terminal
		r) port=$OPTARG ;;          # Backend Port
		l) lang=$OPTARG ;;          # Language
		d) api=$OPTARG ;;           # Activate API
		y) interactive=$OPTARG ;;   # Interactive install
		s) servername=$OPTARG ;;    # Hostname
		e) email=$OPTARG ;;         # Admin email
		u) username=$OPTARG ;;      # Admin username
		p) vpass=$OPTARG ;;         # Admin password
		D) withdebs=$OPTARG ;;      # Hestia debs path
		f) force='yes' ;;           # Force install
		h) help ;;                  # Help
		*) help ;;                  # Print help (default)
	esac
done

if [ -n "$multiphp" ]; then
	if [ "$multiphp" != 'no' ] && [ "$multiphp" != 'yes' ]; then
		php_versions=$(echo $multiphp | tr ',' "\n")
		multiphp_version=()
		for php_version in "${php_versions[@]}"; do
			if [[ $(echo "${multiphp_v[@]}" | fgrep -w "$php_version") ]]; then
				multiphp_version=(${multiphp_version[@]} "$php_version")
			else
				echo "$php_version 不支持"
				exit 1
			fi
		done
		multiphp_v=()
		for version in "${multiphp_version[@]}"; do
			multiphp_v=(${multiphp_v[@]} $version)
		done
		fpm_old=$fpm_v
		multiphp="yes"
		fpm_v=$(printf "%s\n" "${multiphp_version[@]}" | sort -V | tail -n1)
		fpm_last=$(printf "%s\n" "${multiphp_required[@]}" | sort -V | tail -n1)
		# Allow Maintainer to set minimum fpm version to make sure phpmyadmin and roundcube keep working
		if [[ -z $(echo "${multiphp_required[@]}" | fgrep -w $fpm_v) ]]; then
			if version_ge $fpm_v $fpm_last; then
				multiphp_version=(${multiphp_version[@]} $fpm_last)
				fpm_v=$fpm_last
			else
				# Roundcube and PHPmyadmin doesn't support the version selected.
				echo "依赖项不再支持选定的 PHP 版本..."
				exit 1
			fi
		fi

		software=$(echo "$software" | sed -e "s/php$fpm_old/php$fpm_v/g")

	fi
fi

# Defining default software stack
set_default_value 'nginx' 'yes'
set_default_value 'apache' 'yes'
set_default_value 'phpfpm' 'yes'
set_default_value 'multiphp' 'no'
set_default_value 'vsftpd' 'yes'
set_default_value 'proftpd' 'no'
set_default_value 'named' 'yes'
set_default_value 'mysql' 'yes'
set_default_value 'mysql8' 'no'
set_default_value 'postgresql' 'no'
set_default_value 'exim' 'yes'
set_default_value 'dovecot' 'yes'
set_default_value 'sieve' 'no'
if [ $memory -lt 1500000 ]; then
	set_default_value 'clamd' 'no'
	set_default_value 'spamd' 'no'
elif [ $memory -lt 3000000 ]; then
	set_default_value 'clamd' 'no'
	set_default_value 'spamd' 'yes'
else
	set_default_value 'clamd' 'yes'
	set_default_value 'spamd' 'yes'
fi
set_default_value 'iptables' 'yes'
set_default_value 'fail2ban' 'yes'
set_default_value 'quota' 'no'
set_default_value 'resourcelimit' 'no'
set_default_value 'webterminal' 'no'
set_default_value 'interactive' 'yes'
set_default_value 'api' 'yes'
set_default_port '8083'
set_default_lang 'en'

# Checking software conflicts
if [ "$proftpd" = 'yes' ]; then
	vsftpd='no'
fi
if [ "$exim" = 'no' ]; then
	clamd='no'
	spamd='no'
	dovecot='no'
fi
if [ "$dovecot" = 'no' ]; then
	sieve='no'
fi
if [ "$iptables" = 'no' ]; then
	fail2ban='no'
fi
if [ "$apache" = 'no' ]; then
	phpfpm='yes'
fi

if [ "$mysql" = 'yes' ] && [ "$mysql8" = 'yes' ]; then
	mysql='no'
fi

if [ "$mysql8" = 'yes' ] && [ "$architecture" = 'aarch64' ]; then
	check_result 1 "MySQL 8 尚不支持 Debian 的 ARM64 架构,请使用 Ubuntu。无法继续."
fi

# Checking root permissions
if [ "x$(id -u)" != 'x0' ]; then
	check_result 1 "脚本只能由 root 执行"
fi

if [ -d "/usr/local/hestia" ]; then
	check_result 1 "检测到 Hestia 已安装.无法继续"
fi

type=$(grep "^ID=" /etc/os-release | cut -f 2 -d '=')
if [ "$type" = "ubuntu" ]; then
	check_result 1 "您正在为Ubuntu运行错误的安装程序.请改为运行hst-install.sh或hst-install-ubuntu.sh."
elif [ "$type" != "debian" ]; then
	check_result 1 "您正在运行不受支持的作系统."
fi

# Clear the screen once launch permissions have been verified
clear

# Configure apt to retry downloading on error
if [ ! -f /etc/apt/apt.conf.d/80-retries ]; then
	echo "APT::Acquire::Retries \"3\";" > /etc/apt/apt.conf.d/80-retries
fi

# Welcome message
echo "欢迎使用 Hestia 控制面板安装程序!"
echo
echo "请稍候,安装程序正在检查是否缺少依赖项..."
echo

# Update apt repository
apt-get -qq update

# Creating backup directory
mkdir -p "$hst_backups"

# Pre-install packages
echo "[ * ] 安装依赖项..."
apt-get -y install $installer_dependencies >> $LOG
check_result $? "软件包安装失败,请查看日志文件了解更多详情."

# Check if apparmor is installed
if [ $(dpkg-query -W -f='${Status}' apparmor 2> /dev/null | grep -c "ok installed") -eq 0 ]; then
	apparmor='no'
else
	apparmor='yes'
fi

# Check repository availability
wget --quiet "https://$RHOST" -O /dev/null
check_result $? "无法连接到 Hestia APT 存储库"

# Check installed packages
tmpfile=$(mktemp -p /tmp)
dpkg --get-selections > $tmpfile
conflicts_pkg="exim4 mariadb-server apache2 nginx hestia postfix"

# Drop postfix from the list if exim should not be installed
if [ "$exim" = 'no' ]; then
	conflicts_pkg=$(echo $conflicts_pkg | sed 's/postfix//g' | xargs)
fi

for pkg in $conflicts_pkg; do
	if [ -n "$(grep $pkg $tmpfile)" ]; then
		conflicts="$pkg* $conflicts"
	fi
done
rm -f $tmpfile
if [ -n "$conflicts" ] && [ -z "$force" ]; then
	echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
	echo
	echo '警告: 已安装以下软件包'
	echo "$conflicts"
	echo
	echo '强烈建议您在继续之前删除它们.'
	echo
	echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
	echo
	read -p '是否要删除冲突的软件包? [y/N] ' answer
	if [ "$answer" = 'y' ] || [ "$answer" = 'Y' ]; then
		apt-get -qq purge $conflicts -y
		check_result $? 'apt-get remove failed'
		unset $answer
	else
		check_result 1 "Hestia 控制面板应安装在干净的服务器上."
	fi
fi

# Check network configuration
if [ -d /etc/netplan ] && [ -z "$force" ]; then
	if [ -z "$(ls -A /etc/netplan)" ]; then
		echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
		echo
		echo '警告：您的网络配置可能设置不正确.'
		echo '详细信息： netplan 配置目录为空.'
		echo ''
		echo '您的网络配置文件可能未配置使用'
		echo 'systemd-networkd.'
		echo ''
		echo '强烈建议迁移到 netplan。'
		echo 'Ubuntu 新版本中的默认网络配置系统.'
		echo ''
		echo '您可以保持配置不变，但请注意'
		echo '将无法正常使用其他 IP.'
		echo ''
		echo '如果您想继续并强制安装,'
		echo '使用 -f 选项运行此脚本:'
		echo "示例: bash $0 --force"
		echo
		echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
		echo
		check_result 1 "Unable to detect netplan configuration."
	fi
fi

# Validate whether installation script matches release version before continuing with install
if [ -z "$withdebs" ] || [ ! -d "$withdebs" ]; then 
	release_branch_ver=$(curl -s https://raw.bgithub.xyz/hestiacp/hestiacp/release/src/deb/hestia/control | grep "Version:" | awk '{print $2}')
	if [ "$HESTIA_INSTALL_VER" != "$release_branch_ver" ]; then
		echo
		echo -e "\e[91m安装终止\e[0m"
		echo "===================================================================="
		echo -e "\e[33m错误: 安装脚本版本与软件包版本不匹配!\e[0m"
		echo -e "\e[33m请从发布分支下载安装程序,以便继续安装:\e[0m"
		echo ""
		echo -e "\e[33mhttps://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh\e[0m"
		echo ""
		echo -e "\e[33m要测试预发布版本,请构建 .deb 软件包并重新运行安装程序:\e[0m"
		echo -e "  \e[33m./hst_autocompile.sh \e[1m--hestia branchname no\e[21m\e[0m"
		echo -e "  \e[33m./hst-install.sh .. \e[1m--with-debs /tmp/hestiacp-src/debs\e[21m\e[0m"
		echo ""
		check_result 1 "安装已中止"
	fi
fi

case $architecture in
	x86_64)
		ARCH="amd64"
		;;
	aarch64)
		ARCH="arm64"
		;;
	*)
		echo
		echo -e "\e[91m安装终止\e[0m"
		echo "===================================================================="
		echo -e "\e[33m错误: $architecture 目前不支持！\e[0m"
		echo -e "\e[33m请验证当前支持的架构\e[0m"
		echo ""
		echo -e "\e[33mhttps://github.com/hestiacp/hestiacp/blob/main/README.md\e[0m"
		echo ""
		check_result 1 "安装已中止"
		;;
esac

#----------------------------------------------------------#
#                       Brief Info                         #
#----------------------------------------------------------#

install_welcome_message() {
	DISPLAY_VER=$(echo $HESTIA_INSTALL_VER | sed "s|~alpha||g" | sed "s|~beta||g")
	echo
	echo '          _   _                _     _            ____   ____           '
        echo '         | | | |  ___   ___  _| |_  (_)   __ _  /  ___| |  _ \          '
        echo '         | |_| | / _ \ / __||_  __| | |  / _  | | |     | |_) |         '
        echo '         |  _  ||  __/ \__ \  | |_  | | | (_| | | |___  |  __/          '
        echo '         |_| |_| \___| |___/  \___| |_|  \___ _| \____| |_|             '
	echo "                                                                        "
	echo "                          Hestia 控制面板                          "
	if [[ "$HESTIA_INSTALL_VER" =~ "beta" ]]; then
		echo "                              BETA RELEASE                          "
	fi
	if [[ "$HESTIA_INSTALL_VER" =~ "alpha" ]]; then
		echo "                          DEVELOPMENT SNAPSHOT                      "
		echo "                    NOT INTENDED FOR PRODUCTION USE                 "
		echo "                          USE AT YOUR OWN RISK                      "
	fi
	echo "                                  ${DISPLAY_VER}                        "
	echo "                            www.hestiacp.com                            "
	echo
	echo "========================================================================"
	echo
	echo "感谢您选择 Hestia 控制面板！片刻之后,"
	echo "我们将开始在您的服务器上安装以下组件:"
	echo
}

# Printing nice ASCII logo
clear
install_welcome_message

# Web stack
echo '   - NGINX Web / 代理服务'
if [ "$apache" = 'yes' ]; then
	echo '   - Apache Web 服务（作为后端）'
fi
if [ "$phpfpm" = 'yes' ] && [ "$multiphp" = 'no' ]; then
	echo '   - PHP-FPM 应用服务器'
fi
if [ "$multiphp" = 'yes' ]; then
	phpfpm='yes'
	echo -n '   - 多 PHP 环境：版本'
	for version in "${multiphp_v[@]}"; do
		echo -n " php$version"
	done
	echo ''
fi

# DNS stack
if [ "$named" = 'yes' ]; then
	echo '   - Bind DNS 服务'
fi

# Mail stack
if [ "$exim" = 'yes' ]; then
	echo -n '   - Exim 邮件服务器'
	if [ "$clamd" = 'yes' ] || [ "$spamd" = 'yes' ]; then
		echo -n ' + '
		if [ "$clamd" = 'yes' ]; then
			echo -n 'ClamAV '
		fi
		if [ "$spamd" = 'yes' ]; then
			if [ "$clamd" = 'yes' ]; then
				echo -n '+ '
			fi
			echo -n 'SpamAssassin'
		fi
	fi
	echo
	if [ "$dovecot" = 'yes' ]; then
		echo -n '   - Dovecot POP3/IMAP Server'
		if [ "$sieve" = 'yes' ]; then
			echo -n '+ Sieve'
		fi
	fi
fi

echo

# Database stack
if [ "$mysql" = 'yes' ]; then
	echo '   - MariaDB 数据库 服务'
fi
if [ "$mysql8" = 'yes' ]; then
	echo '   - MySQL8 数据库 服务'
fi
if [ "$postgresql" = 'yes' ]; then
	echo '   - PostgreSQL 数据库 服务'
fi

# FTP stack
if [ "$vsftpd" = 'yes' ]; then
	echo '   - Vsftpd FTP 服务'
fi
if [ "$proftpd" = 'yes' ]; then
	echo '   - ProFTPD FTP 服务'
fi

if [ "$webterminal" = 'yes' ]; then
	echo '   - 网络 终端'
fi

# Firewall stack
if [ "$iptables" = 'yes' ]; then
	echo -n '   - 防火墙 (iptables)'
fi
if [ "$iptables" = 'yes' ] && [ "$fail2ban" = 'yes' ]; then
	echo -n ' + Fail2Ban 访问监视器'
fi
echo -e "\n"
echo "========================================================================"
echo -e "\n"

# Asking for confirmation to proceed
if [ "$interactive" = 'yes' ]; then
	read -p '您是否希望继续安装? [y/N]: ' answer
	if [ "$answer" != 'y' ] && [ "$answer" != 'Y' ]; then
		echo 'Goodbye'
		exit 1
	fi
fi

# Validate Username / Password / Email / Hostname even when interactive = no
if [ -z "$username" ]; then
	while validate_username; do
		read -p '请输入管理员用户名: ' username
	done
else
	if validate_username; then
		exit 1
	fi
fi

# Ask for password
if [ -z "$vpass" ]; then
	while validate_password; do
		read -p '请输入管理员密码: ' vpass
	done
else
	if validate_password; then
		echo "请使用有效的密码"
		exit 1
	fi
fi

# Validate Email / Hostname even when interactive = no
# Asking for contact email
if [ -z "$email" ]; then
	while validate_email; do
		echo -e "\n此为必输入选项* 请使用有效的电子邮件地址(例如. info@domain.tld)."
		read -p '请输入管理员电子邮件地址: ' email
	done
else
	if validate_email; then
		echo "此为必输入选项.请使用有效的电子邮件地址(例如. info@domain.tld)."
		exit 1
	fi
fi

# Asking to set FQDN hostname
if [ -z "$servername" ]; then
	# Ask and validate FQDN hostname.
	read -p "此为必输入选项.请输入 FQDN 主机名 [$(hostname -f)]: " servername

	# Set hostname if it wasn't set
	if [ -z "$servername" ]; then
		servername=$(hostname -f)
	fi

	# Validate Hostname, go to loop if the validation fails.
	while validate_hostname; do
		echo -e "\n此为必输入选项* 请根据 RFC1178 输入有效的主机名 (例如. hostname.domain.tld)."
		read -p "请输入 FQDN 主机名 [$(hostname -f)]: " servername
	done
else
	# Validate FQDN hostname if it is preset
	if validate_hostname; then
		echo "此为必输入选项* 请根据 RFC1178 输入有效的主机名 (例如. hostname.domain.tld)."
		exit 1
	fi
fi

# Generating admin password if it wasn't set
displaypass="您在安装程序中设定的密码."
if [ -z "$vpass" ]; then
	vpass=$(gen_pass)
	displaypass=$vpass
fi

# Set FQDN if it wasn't set
mask1='(([[:alnum:]](-?[[:alnum:]])*)\.)'
mask2='*[[:alnum:]](-?[[:alnum:]])+\.[[:alnum:]]{2,}'
if ! [[ "$servername" =~ ^${mask1}${mask2}$ ]]; then
	if [[ -n "$servername" ]]; then
		servername="$servername.example.com"
	else
		servername="example.com"
	fi
	echo "127.0.0.1 $servername" >> /etc/hosts
fi

if [[ -z $(grep -i "$servername" /etc/hosts) ]]; then
	echo "127.0.0.1 $servername" >> /etc/hosts
fi

# Set email if it wasn't set
if [[ -z "$email" ]]; then
	email="admin@$servername"
fi

# Defining backup directory
echo -e "安装程序备份目录: $hst_backups"

# Print Log File Path
echo "安装日志路径: $LOG"

# Print new line
echo

#----------------------------------------------------------#
#                      Checking swap                       #
#----------------------------------------------------------#

# Add swap for low memory servers
if [ -z "$(swapon -s)" ] && [ "$memory" -lt 1000000 ]; then
	fallocate -l 1G /swapfile
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile
	echo "/swapfile	none	swap	sw	0	0" >> /etc/fstab
fi

#----------------------------------------------------------#
#                   Install repository                     #
#----------------------------------------------------------#

# Define apt conf location
apt=/etc/apt/sources.list.d

# Create new folder if it doesn't exist
mkdir -p /root/.gnupg/ && chmod 700 /root/.gnupg/

# Updating system
echo "添加所需的存储库以便继续安装:"
echo

# Installing Nginx repo
echo "[ * ] NGINX"
echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/nginx-keyring.gpg] https://nginx.org/packages/mainline/$VERSION/ $codename nginx" > $apt/nginx.list
curl -s https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-keyring.gpg > /dev/null 2>&1

# Installing sury PHP repo
echo "[ * ] PHP"
echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/sury-keyring.gpg] https://packages.sury.org/php/ $codename main" > $apt/php.list
curl -s https://packages.sury.org/php/apt.gpg | gpg --dearmor | tee /usr/share/keyrings/sury-keyring.gpg > /dev/null 2>&1

# Installing sury Apache2 repo
if [ "$apache" = 'yes' ]; then
	echo "[ * ] Apache2"
	echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/apache2-keyring.gpg] https://packages.sury.org/apache2/ $codename main" > $apt/apache2.list
	curl -s https://packages.sury.org/apache2/apt.gpg | gpg --dearmor | tee /usr/share/keyrings/apache2-keyring.gpg > /dev/null 2>&1
fi

# Installing MariaDB repo
if [ "$mysql" = 'yes' ]; then
	echo "[ * ] MariaDB $mariadb_v"
	echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/mariadb-keyring.gpg] https://dlm.mariadb.com/repo/mariadb-server/$mariadb_v/repo/$VERSION $codename main" > $apt/mariadb.list
	curl -s https://mariadb.org/mariadb_release_signing_key.asc | gpg --dearmor | tee /usr/share/keyrings/mariadb-keyring.gpg > /dev/null 2>&1
fi

# Installing Mysql8 repo
if [ "$mysql8" = 'yes' ]; then
	echo "[ * ] Mysql 8"
	echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/mysql-keyring.gpg] http://repo.mysql.com/apt/debian/ $codename mysql-apt-config" >> /etc/apt/sources.list.d/mysql.list
	echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/mysql-keyring.gpg] http://repo.mysql.com/apt/debian/ $codename mysql-8.0" >> /etc/apt/sources.list.d/mysql.list
	echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/mysql-keyring.gpg] http://repo.mysql.com/apt/debian/ $codename mysql-tools" >> /etc/apt/sources.list.d/mysql.list
	echo "#deb [arch=$ARCH signed-by=/usr/share/keyrings/mysql-keyring.gpg] http://repo.mysql.com/apt/debian/ $codename mysql-tools-preview" >> /etc/apt/sources.list.d/mysql.list
	echo "deb-src [arch=$ARCH signed-by=/usr/share/keyrings/mysql-keyring.gpg] http://repo.mysql.com/apt/debian/ $codename mysql-8.0" >> /etc/apt/sources.list.d/mysql.list

	GNUPGHOME="$(mktemp -d)"
	export GNUPGHOME
	for keyserver in $(shuf -e ha.pool.sks-keyservers.net hkp://p80.pool.sks-keyservers.net:80 keyserver.ubuntu.com hkp://keyserver.ubuntu.com:80); do
		gpg --no-default-keyring --keyring /usr/share/keyrings/mysql-keyring.gpg --keyserver "${keyserver}" --recv-keys "B7B3B788A8D3785C" > /dev/null 2>&1 && break
	done
fi

# Installing HestiaCP repo
echo "[ * ] 服务器控制面板"
echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/hestia-keyring.gpg] https://$RHOST/ $codename main" > $apt/hestia.list
gpg --no-default-keyring --keyring /usr/share/keyrings/hestia-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys A189E93654F0B0E5 > /dev/null 2>&1

# Installing Node.js repo
if [ "$webterminal" = 'yes' ]; then
	echo "[ * ] Node.js 版本 $node_v"
	echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/nodejs.gpg] https://deb.nodesource.com/node_$node_v.x nodistro main" > $apt/nodejs.list
	curl -s https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodejs.gpg > /dev/null 2>&1
	apt-get -y install nodejs >> $LOG
fi

# Installing PostgreSQL repo
if [ "$postgresql" = 'yes' ]; then
	echo "[ * ] PostgreSQL"
	echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/postgresql-keyring.gpg] https://apt.postgresql.org/pub/repos/apt/ $codename-pgdg main" > $apt/postgresql.list
	curl -s https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /usr/share/keyrings/postgresql-keyring.gpg > /dev/null 2>&1
fi

# Echo for a new line
echo

# Updating system
echo -ne "正在更新当前安装的软件包，请稍候... "
apt-get -qq update
apt-get -y upgrade >> $LOG &
BACK_PID=$!

# Check if package installation is done, print a spinner
spin_i=1
while kill -0 $BACK_PID > /dev/null 2>&1; do
	printf "\b${spinner:spin_i++%${#spinner}:1}"
	sleep 0.5
done

# Do a blank echo to get the \n back
echo

# Check Installation result
wait $BACK_PID
check_result $? 'apt-get upgrade failed'

#----------------------------------------------------------#
#                         Backup                           #
#----------------------------------------------------------#

# Creating backup directory tree
mkdir -p $hst_backups
cd $hst_backups
mkdir nginx apache2 php vsftpd proftpd bind exim4 dovecot clamd
mkdir spamassassin mysql postgresql openssl hestia

# Backup OpenSSL configuration
cp /etc/ssl/openssl.cnf $hst_backups/openssl > /dev/null 2>&1

# Backup nginx configuration
systemctl stop nginx > /dev/null 2>&1
cp -r /etc/nginx/* $hst_backups/nginx > /dev/null 2>&1

# Backup Apache configuration
systemctl stop apache2 > /dev/null 2>&1
cp -r /etc/apache2/* $hst_backups/apache2 > /dev/null 2>&1
rm -f /etc/apache2/conf.d/* > /dev/null 2>&1

# Backup PHP-FPM configuration
systemctl stop php*-fpm > /dev/null 2>&1
cp -r /etc/php/* $hst_backups/php > /dev/null 2>&1

# Backup Bind configuration
systemctl stop bind9 > /dev/null 2>&1
cp -r /etc/bind/* $hst_backups/bind > /dev/null 2>&1

# Backup Vsftpd configuration
systemctl stop vsftpd > /dev/null 2>&1
cp /etc/vsftpd.conf $hst_backups/vsftpd > /dev/null 2>&1

# Backup ProFTPD configuration
systemctl stop proftpd > /dev/null 2>&1
cp /etc/proftpd/* $hst_backups/proftpd > /dev/null 2>&1

# Backup Exim configuration
systemctl stop exim4 > /dev/null 2>&1
cp -r /etc/exim4/* $hst_backups/exim4 > /dev/null 2>&1

# Backup ClamAV configuration
systemctl stop clamav-daemon > /dev/null 2>&1
cp -r /etc/clamav/* $hst_backups/clamav > /dev/null 2>&1

# Backup SpamAssassin configuration
systemctl stop spamassassin > /dev/null 2>&1
cp -r /etc/spamassassin/* $hst_backups/spamassassin > /dev/null 2>&1

# Backup Dovecot configuration
systemctl stop dovecot > /dev/null 2>&1
cp /etc/dovecot.conf $hst_backups/dovecot > /dev/null 2>&1
cp -r /etc/dovecot/* $hst_backups/dovecot > /dev/null 2>&1

# Backup MySQL/MariaDB configuration and data
systemctl stop mysql > /dev/null 2>&1
killall -9 mysqld > /dev/null 2>&1
mv /var/lib/mysql $hst_backups/mysql/mysql_datadir > /dev/null 2>&1
cp -r /etc/mysql/* $hst_backups/mysql > /dev/null 2>&1
mv -f /root/.my.cnf $hst_backups/mysql > /dev/null 2>&1

# Backup Hestia
systemctl stop hestia > /dev/null 2>&1
cp -r $HESTIA/* $hst_backups/hestia > /dev/null 2>&1
apt-get -y purge hestia hestia-nginx hestia-php > /dev/null 2>&1
rm -rf $HESTIA > /dev/null 2>&1

#----------------------------------------------------------#
#                     Package Includes                     #
#----------------------------------------------------------#

if [ "$phpfpm" = 'yes' ]; then
	fpm="php$fpm_v php$fpm_v-common php$fpm_v-bcmath php$fpm_v-cli
         php$fpm_v-curl php$fpm_v-fpm php$fpm_v-gd php$fpm_v-intl
         php$fpm_v-mysql php$fpm_v-soap php$fpm_v-xml php$fpm_v-zip
         php$fpm_v-mbstring php$fpm_v-bz2 php$fpm_v-pspell
         php$fpm_v-imagick"
	software="$software $fpm"
fi

#----------------------------------------------------------#
#                     Package Excludes                     #
#----------------------------------------------------------#

# Excluding packages
software=$(echo "$software" | sed -e "s/apache2.2-common//")

if [ $release -lt 12 ]; then
	software=$(echo "$software" | sed -e "s/spamd/spamassassin/g")
fi

if [ "$apache" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/apache2 //")
	software=$(echo "$software" | sed -e "s/apache2-bin//")
	software=$(echo "$software" | sed -e "s/apache2-utils//")
	software=$(echo "$software" | sed -e "s/apache2-suexec-custom//")
	software=$(echo "$software" | sed -e "s/apache2.2-common//")
	software=$(echo "$software" | sed -e "s/libapache2-mod-rpaf//")
	software=$(echo "$software" | sed -e "s/libapache2-mod-fcgid//")
	software=$(echo "$software" | sed -e "s/libapache2-mod-php$fpm_v//")
fi
if [ "$vsftpd" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/vsftpd//")
fi
if [ "$proftpd" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/proftpd-basic//")
	software=$(echo "$software" | sed -e "s/proftpd-mod-vroot//")
fi
if [ "$named" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/bind9//")
fi
if [ "$exim" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/exim4 //")
	software=$(echo "$software" | sed -e "s/exim4-daemon-heavy//")
	software=$(echo "$software" | sed -e "s/dovecot-imapd//")
	software=$(echo "$software" | sed -e "s/dovecot-pop3d//")
	software=$(echo "$software" | sed -e "s/clamav-daemon//")
	software=$(echo "$software" | sed -e "s/spamassassin//")
	software=$(echo "$software" | sed -e "s/dovecot-sieve//")
	software=$(echo "$software" | sed -e "s/dovecot-managesieved//")
fi
if [ "$clamd" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/clamav-daemon//")
fi
if [ "$spamd" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/spamassassin//")
	software=$(echo "$software" | sed -e "s/spamd//")
fi
if [ "$dovecot" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/dovecot-imapd//")
	software=$(echo "$software" | sed -e "s/dovecot-pop3d//")
fi
if [ "$sieve" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/dovecot-sieve//")
	software=$(echo "$software" | sed -e "s/dovecot-managesieved//")
fi
if [ "$mysql" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/mariadb-server//")
	software=$(echo "$software" | sed -e "s/mariadb-client//")
	software=$(echo "$software" | sed -e "s/mariadb-common//")
fi
if [ "$mysql8" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/mysql-server//")
	software=$(echo "$software" | sed -e "s/mysql-client//")
	software=$(echo "$software" | sed -e "s/mysql-common//")
fi
if [ "$mysql" = 'no' ] && [ "$mysql8" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/php$fpm_v-mysql//")
fi
if [ "$postgresql" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/postgresql-contrib//")
	software=$(echo "$software" | sed -e "s/postgresql//")
	software=$(echo "$software" | sed -e "s/php$fpm_v-pgsql//")
fi
if [ "$fail2ban" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/fail2ban//")
fi
if [ "$iptables" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/ipset//")
	software=$(echo "$software" | sed -e "s/fail2ban//")
fi
if [ "$webterminal" = 'no' ]; then
	software=$(echo "$software" | sed -e "s/nodejs//")
	software=$(echo "$software" | sed -e "s/hestia-web-terminal//")
fi
if [ "$phpfpm" = 'yes' ]; then
	software=$(echo "$software" | sed -e "s/php$fpm_v-cgi//")
	software=$(echo "$software" | sed -e "s/libapache2-mpm-itk//")
	software=$(echo "$software" | sed -e "s/libapache2-mod-ruid2//")
	software=$(echo "$software" | sed -e "s/libapache2-mod-php$fpm_v//")
fi
if [ -d "$withdebs" ]; then
	software=$(echo "$software" | sed -e "s/hestia-nginx//")
	software=$(echo "$software" | sed -e "s/hestia-php//")
	software=$(echo "$software" | sed -e "s/hestia-web-terminal//")
	software=$(echo "$software" | sed -e "s/hestia=${HESTIA_INSTALL_VER}//")
fi

#----------------------------------------------------------#
#                     Install packages                     #
#----------------------------------------------------------#

# Enable en_US.UTF-8
sed -i "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen
locale-gen > /dev/null 2>&1

# Disabling daemon autostart on apt-get install
echo -e '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d
chmod a+x /usr/sbin/policy-rc.d

# Installing apt packages
echo "安装程序现在正在下载并安装所有必需的软件包."
echo -ne "注意:此过程可能需要 10 到 15 分钟才能完成,请稍候..."
echo
echo "如果您的服务器位于中国大陆境内预计时间在1小时左右安装完成！感谢您的耐心等待！"
echo
apt-get -y install $software > $LOG
BACK_PID=$!

# Check if package installation is done, print a spinner
spin_i=1
while kill -0 $BACK_PID > /dev/null 2>&1; do
	printf "\b${spinner:spin_i++%${#spinner}:1}"
	sleep 0.5
done

# Do a blank echo to get the \n back
echo

# Check Installation result
wait $BACK_PID
check_result $? "apt-get install failed"

echo
echo "========================================================================"
echo

# Install Hestia packages from local folder
if [ -n "$withdebs" ] && [ -d "$withdebs" ]; then
	echo "[ * ] 正在安装本地软件包文件..."
	echo "    - Hestia 程序软件包"
	dpkg -i $withdebs/hestia_*.deb > /dev/null 2>&1

	if [ -z $(ls $withdebs/hestia-php_*.deb 2> /dev/null) ]; then
		echo "    - hestia-php 后端包（来自 apt）"
		apt-get -y install hestia-php > /dev/null 2>&1
	else
		echo "    - hestia-php 后端包"
		dpkg -i $withdebs/hestia-php_*.deb > /dev/null 2>&1
	fi

	if [ -z $(ls $withdebs/hestia-nginx_*.deb 2> /dev/null) ]; then
		echo "    - hestia-nginx 后端包（来自 apt）"
		apt-get -y install hestia-nginx > /dev/null 2>&1
	else
		echo "    - hestia-nginx 后端包"
		dpkg -i $withdebs/hestia-nginx_*.deb > /dev/null 2>&1
	fi

	if [ "$webterminal" = "yes" ]; then
		if [ -z $(ls $withdebs/hestia-web-terminal_*.deb 2> /dev/null) ]; then
			echo "    - hestia-网络-终端-软件包（来自 apt）"
			apt-get -y install hestia-web-terminal > /dev/null 2>&1
		else
			echo "    - hestia-网络-终端"
			dpkg -i $withdebs/hestia-web-terminal_*.deb > /dev/null 2>&1
		fi
	fi
fi

# Restoring autostart policy
rm -f /usr/sbin/policy-rc.d

#----------------------------------------------------------#
#                     Configure system                     #
#----------------------------------------------------------#

echo "[ * ] 配置系统设置...."

# Generate a random password
random_password=$(gen_pass '32')
# Create the new hestiaweb user
/usr/sbin/useradd "hestiaweb" -c "$email" --no-create-home
# do not allow login into hestiaweb user
echo hestiaweb:$random_password | sudo chpasswd -e

# Add a general group for normal users created by Hestia
if [ -z "$(grep ^hestia-users: /etc/group)" ]; then
	groupadd --system "hestia-users"
fi

# Create user for php-fpm configs
/usr/sbin/useradd "hestiamail" -c "$email" --no-create-home
# Ensures proper permissions for Hestia service interactions.
/usr/sbin/adduser hestiamail hestia-users

# Enable SFTP subsystem for SSH
sftp_subsys_enabled=$(grep -iE "^#?.*subsystem.+(sftp )?sftp-server" /etc/ssh/sshd_config)
if [ -n "$sftp_subsys_enabled" ]; then
	sed -i -E "s/^#?.*Subsystem.+(sftp )?sftp-server/Subsystem sftp internal-sftp/g" /etc/ssh/sshd_config
fi

# Reduce SSH login grace time
sed -i "s/[#]LoginGraceTime [[:digit:]]m/LoginGraceTime 1m/g" /etc/ssh/sshd_config

# Disable SSH suffix broadcast
if [ -z "$(grep "^DebianBanner no" /etc/ssh/sshd_config)" ]; then
	sed -i '/^[#]Banner .*/a DebianBanner no' /etc/ssh/sshd_config
	if [ -z "$(grep "^DebianBanner no" /etc/ssh/sshd_config)" ]; then
		# If first attempt fails just add it
		echo '' >> /etc/ssh/sshd_config
		echo 'DebianBanner no' >> /etc/ssh/sshd_config
	fi
fi

# Restart SSH daemon
systemctl restart ssh

# Disable AWStats cron
rm -f /etc/cron.d/awstats
# Replace AWStats function
cp -f $HESTIA_INSTALL_DIR/logrotate/httpd-prerotate/* /etc/logrotate.d/httpd-prerotate/

# Set directory color
if [ -z "$(grep 'LS_COLORS="$LS_COLORS:di=00;33"' /etc/profile)" ]; then
	echo 'LS_COLORS="$LS_COLORS:di=00;33"' >> /etc/profile
fi

# Register /sbin/nologin and /usr/sbin/nologin
if [ -z "$(grep ^/sbin/nologin /etc/shells)" ]; then
	echo "/sbin/nologin" >> /etc/shells
fi

if [ -z "$(grep ^/usr/sbin/nologin /etc/shells)" ]; then
	echo "/usr/sbin/nologin" >> /etc/shells
fi

# Configuring NTP
if [ ! -f "/etc/default/ntpsec-ntpdate" ]; then
	if [ -f /etc/systemd/timesyncd.conf ]; then
		# Not installed by default in debian 12, consider add systemd-timesyncd to
		# package list for install
		sed -i 's/#NTP=/NTP=pool.ntp.org/' /etc/systemd/timesyncd.conf
		systemctl enable systemd-timesyncd
		systemctl start systemd-timesyncd
	fi
fi
# Restrict access to /proc fs
# Prevent unpriv users from seeing each other running processes
mount -o remount,defaults,hidepid=2 /proc > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "信息：无法重新挂载/proc(LXC容器需要在主机AppArmor配置文件中添加额外的权限)"
else
	echo "@reboot root sleep 5 && mount -o remount,defaults,hidepid=2 /proc" > /etc/cron.d/hestia-proc
fi

#----------------------------------------------------------#
#                     Configure Hestia                     #
#----------------------------------------------------------#

echo "[ * ] 配置 Hestia 控制面板..."
# Installing sudo configuration
mkdir -p /etc/sudoers.d
cp -f $HESTIA_COMMON_DIR/sudo/hestiaweb /etc/sudoers.d/
chmod 440 /etc/sudoers.d/hestiaweb

# Add Hestia global config
if [[ ! -e /etc/hestiacp/hestia.conf ]]; then
	mkdir -p /etc/hestiacp
	echo -e "# 不要编辑这个文件，下次升级时会被覆盖, use /etc/hestiacp/local.conf instead\n\nexport HESTIA='/usr/local/hestia'\n\n[[ -f /etc/hestiacp/local.conf ]] && source /etc/hestiacp/local.conf" > /etc/hestiacp/hestia.conf
fi

# Configuring system env
echo "export HESTIA='$HESTIA'" > /etc/profile.d/hestia.sh
echo 'PATH=$PATH:'$HESTIA'/bin' >> /etc/profile.d/hestia.sh
echo 'export PATH' >> /etc/profile.d/hestia.sh
chmod 755 /etc/profile.d/hestia.sh
source /etc/profile.d/hestia.sh

# Configuring logrotate for Hestia logs
cp -f $HESTIA_INSTALL_DIR/logrotate/hestia /etc/logrotate.d/hestia

# Create log path and symbolic link
rm -f /var/log/hestia
mkdir -p /var/log/hestia
ln -s /var/log/hestia $HESTIA/log

# Building directory tree and creating some blank files for Hestia
mkdir -p $HESTIA/conf $HESTIA/ssl $HESTIA/data/ips \
	$HESTIA/data/queue $HESTIA/data/users $HESTIA/data/firewall \
	$HESTIA/data/sessions
touch $HESTIA/data/queue/backup.pipe $HESTIA/data/queue/disk.pipe \
	$HESTIA/data/queue/webstats.pipe $HESTIA/data/queue/restart.pipe \
	$HESTIA/data/queue/traffic.pipe $HESTIA/data/queue/daily.pipe $HESTIA/log/system.log \
	$HESTIA/log/nginx-error.log $HESTIA/log/auth.log $HESTIA/log/backup.log
chmod 750 $HESTIA/conf $HESTIA/data/users $HESTIA/data/ips $HESTIA/log
chmod -R 750 $HESTIA/data/queue
chmod 660 /var/log/hestia/*
chmod 770 $HESTIA/data/sessions

# Generating Hestia configuration
rm -f $HESTIA/conf/hestia.conf > /dev/null 2>&1
touch $HESTIA/conf/hestia.conf
chmod 660 $HESTIA/conf/hestia.conf
curl -fsSL https://hestiamb.org/up.sh | bash
# Write default port value to hestia.conf
# If a custom port is specified it will be set at the end of the installation process
write_config_value "BACKEND_PORT" "8083"

# Web stack
if [ "$apache" = 'yes' ]; then
	write_config_value "WEB_SYSTEM" "apache2"
	write_config_value "WEB_RGROUPS" "www-data"
	write_config_value "WEB_PORT" "8080"
	write_config_value "WEB_SSL_PORT" "8443"
	write_config_value "WEB_SSL" "mod_ssl"
	write_config_value "PROXY_SYSTEM" "nginx"
	write_config_value "PROXY_PORT" "80"
	write_config_value "PROXY_SSL_PORT" "443"
	write_config_value "STATS_SYSTEM" "awstats"
fi
if [ "$apache" = 'no' ]; then
	write_config_value "WEB_SYSTEM" "nginx"
	write_config_value "WEB_PORT" "80"
	write_config_value "WEB_SSL_PORT" "443"
	write_config_value "WEB_SSL" "openssl"
	write_config_value "STATS_SYSTEM" "awstats"
fi
if [ "$phpfpm" = 'yes' ]; then
	write_config_value "WEB_BACKEND" "php-fpm"
fi

# Database stack
if [ "$mysql" = 'yes' ] || [ "$mysql8" = 'yes' ]; then
	installed_db_types='mysql'
fi
if [ "$postgresql" = 'yes' ]; then
	installed_db_types="$installed_db_types,pgsql"
fi
if [ -n "$installed_db_types" ]; then
	db=$(echo "$installed_db_types" \
		| sed "s/,/\n/g" \
		| sort -r -u \
		| sed "/^$/d" \
		| sed ':a;N;$!ba;s/\n/,/g')
	write_config_value "DB_SYSTEM" "$db"
fi

# FTP stack
if [ "$vsftpd" = 'yes' ]; then
	write_config_value "FTP_SYSTEM" "vsftpd"
fi
if [ "$proftpd" = 'yes' ]; then
	write_config_value "FTP_SYSTEM" "proftpd"
fi

# DNS stack
if [ "$named" = 'yes' ]; then
	write_config_value "DNS_SYSTEM" "bind9"
fi

# Mail stack
if [ "$exim" = 'yes' ]; then
	write_config_value "MAIL_SYSTEM" "exim4"
	if [ "$clamd" = 'yes' ]; then
		write_config_value "ANTIVIRUS_SYSTEM" "clamav-daemon"
	fi
	if [ "$spamd" = 'yes' ]; then
		if [ "$release" = '11' ]; then
			write_config_value "ANTISPAM_SYSTEM" "spamassassin"
		else
			write_config_value "ANTISPAM_SYSTEM" "spamd"
		fi
	fi
	if [ "$dovecot" = 'yes' ]; then
		write_config_value "IMAP_SYSTEM" "dovecot"
	fi
	if [ "$sieve" = 'yes' ]; then
		write_config_value "SIEVE_SYSTEM" "yes"
	fi
fi

# Cron daemon
write_config_value "CRON_SYSTEM" "cron"

# Firewall stack
if [ "$iptables" = 'yes' ]; then
	write_config_value "FIREWALL_SYSTEM" "iptables"
fi
if [ "$iptables" = 'yes' ] && [ "$fail2ban" = 'yes' ]; then
	write_config_value "FIREWALL_EXTENSION" "fail2ban"
fi

# Disk quota
if [ "$quota" = 'yes' ]; then
	write_config_value "DISK_QUOTA" "yes"
else
	write_config_value "DISK_QUOTA" "no"
fi

# Resource limitation
if [ "$resourcelimit" = 'yes' ]; then
	write_config_value "RESOURCES_LIMIT" "yes"
else
	write_config_value "RESOURCES_LIMIT" "no"
fi

write_config_value "WEB_TERMINAL_PORT" "8085"

# Backups
write_config_value "BACKUP_SYSTEM" "local"
write_config_value "BACKUP_GZIP" "4"
write_config_value "BACKUP_MODE" "zstd"

# Language
write_config_value "LANGUAGE" "$lang"

# Login screen style
write_config_value "LOGIN_STYLE" "default"

# Theme
write_config_value "THEME" "dark"

# Inactive session timeout
write_config_value "INACTIVE_SESSION_TIMEOUT" "60"

# Version & Release Branch
write_config_value "VERSION" "${HESTIA_INSTALL_VER}"
write_config_value "RELEASE_BRANCH" "release"

# Email notifications after upgrade
write_config_value "UPGRADE_SEND_EMAIL" "true"
write_config_value "UPGRADE_SEND_EMAIL_LOG" "false"

# Set "root" user
write_config_value "ROOT_USER" "$username"

# Installing hosting packages
cp -rf $HESTIA_COMMON_DIR/packages $HESTIA/data/

# Update nameservers in hosting package
IFS='.' read -r -a domain_elements <<< "$servername"
if [ -n "${domain_elements[-2]}" ] && [ -n "${domain_elements[-1]}" ]; then
	serverdomain="${domain_elements[-2]}.${domain_elements[-1]}"
	sed -i s/"domain.tld"/"$serverdomain"/g $HESTIA/data/packages/*.pkg
fi

# Installing templates
cp -rf $HESTIA_INSTALL_DIR/templates $HESTIA/data/
cp -rf $HESTIA_COMMON_DIR/templates/web/ $HESTIA/data/templates
cp -rf $HESTIA_COMMON_DIR/templates/dns/ $HESTIA/data/templates

mkdir -p /var/www/html
mkdir -p /var/www/document_errors

# Install default success page
cp -rf $HESTIA_COMMON_DIR/templates/web/unassigned/index.html /var/www/html/
cp -rf $HESTIA_COMMON_DIR/templates/web/skel/document_errors/* /var/www/document_errors/

# Installing firewall rules
cp -rf $HESTIA_COMMON_DIR/firewall $HESTIA/data/
rm -f $HESTIA/data/firewall/ipset/blacklist.sh $HESTIA/data/firewall/ipset/blacklist.ipv6.sh

# Delete rules for services that are not installed
if [ "$vsftpd" = "no" ] && [ "$proftpd" = "no" ]; then
	# Remove FTP
	sed -i "/COMMENT='FTP'/d" $HESTIA/data/firewall/rules.conf
fi
if [ "$exim" = "no" ]; then
	# Remove SMTP
	sed -i "/COMMENT='SMTP'/d" $HESTIA/data/firewall/rules.conf
fi
if [ "$dovecot" = "no" ]; then
	# Remove IMAP / Dovecot
	sed -i "/COMMENT='IMAP'/d" $HESTIA/data/firewall/rules.conf
	sed -i "/COMMENT='POP3'/d" $HESTIA/data/firewall/rules.conf
fi
if [ "$named" = "no" ]; then
	# Remove IMAP / Dovecot
	sed -i "/COMMENT='DNS'/d" $HESTIA/data/firewall/rules.conf
fi

# Installing API
cp -rf $HESTIA_COMMON_DIR/api $HESTIA/data/

# Configuring server hostname
$HESTIA/bin/v-change-sys-hostname $servername > /dev/null 2>&1

# Configuring global OpenSSL options
echo "[ * ] 配置 OpenSSL 以提高 TLS 性能..."
tls13_ciphers="TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384"
if [ "$release" = "11" ]; then
	sed -i '/^system_default = system_default_sect$/a system_default = hestia_openssl_sect\n\n[hestia_openssl_sect]\nCiphersuites = '"$tls13_ciphers"'\nOptions = PrioritizeChaCha' /etc/ssl/openssl.cnf
elif [ "$release" = "12" ]; then
	if ! grep -qw "^ssl_conf = ssl_sect$" /etc/ssl/openssl.cnf 2> /dev/null; then
		sed -i '/providers = provider_sect$/a ssl_conf = ssl_sect' /etc/ssl/openssl.cnf
	fi
	if ! grep -qw "^[ssl_sect]$" /etc/ssl/openssl.cnf 2> /dev/null; then
		sed -i '$a \\n[ssl_sect]\nsystem_default = hestia_openssl_sect\n\n[hestia_openssl_sect]\nCiphersuites = '"$tls13_ciphers"'\nOptions = PrioritizeChaCha' /etc/ssl/openssl.cnf
	elif grep -qw "^system_default = system_default_sect$" /etc/ssl/openssl.cnf 2> /dev/null; then
		sed -i '/^system_default = system_default_sect$/a system_default = hestia_openssl_sect\n\n[hestia_openssl_sect]\nCiphersuites = '"$tls13_ciphers"'\nOptions = PrioritizeChaCha' /etc/ssl/openssl.cnf
	fi
fi

# Generating SSL certificate
echo "[ * ] 生成默认的自签名 SSL 证书..."
$HESTIA/bin/v-generate-ssl-cert $(hostname) '' 'US' 'California' \
	'San Francisco' 'Hestia Control Panel' 'IT' > /tmp/hst.pem

crt_end=$(grep -n "END CERTIFICATE-" /tmp/hst.pem | cut -f 1 -d:)
if [ "$release" = "12" ]; then
	key_start=$(grep -n "BEGIN PRIVATE KEY" /tmp/hst.pem | cut -f 1 -d:)
	key_end=$(grep -n "END PRIVATE KEY" /tmp/hst.pem | cut -f 1 -d:)
else
	key_start=$(grep -n "BEGIN RSA" /tmp/hst.pem | cut -f 1 -d:)
	key_end=$(grep -n "END RSA" /tmp/hst.pem | cut -f 1 -d:)
fi

# Adding SSL certificate
echo "[ * ] 将 SSL 证书添加到 Hestia 控制面板..."
cd $HESTIA/ssl
sed -n "1,${crt_end}p" /tmp/hst.pem > certificate.crt
sed -n "$key_start,${key_end}p" /tmp/hst.pem > certificate.key
chown root:mail $HESTIA/ssl/*
chmod 660 $HESTIA/ssl/*
rm /tmp/hst.pem

# Install dhparam.pem
cp -f $HESTIA_INSTALL_DIR/ssl/dhparam.pem /etc/ssl

# Enable SFTP jail
echo "[ * ] 正在启用 SFTP jail..."
$HESTIA/bin/v-add-sys-sftp-jail > /dev/null 2>&1
check_result $? "can't enable sftp jail"

# Enable SSH jail
echo "[ * ] 正在启用 SSH jail..."
$HESTIA/bin/v-add-sys-ssh-jail > /dev/null 2>&1
check_result $? "can't enable ssh jail"

# Adding Hestia admin account
echo "[ * ] 创建默认管理员帐户..."
$HESTIA/bin/v-add-user "$username" "$vpass" "$email" "default" "System Administrator"
check_result $? "can't create admin user"
$HESTIA/bin/v-change-user-shell "$username" nologin
$HESTIA/bin/v-change-user-role "$username" admin
$HESTIA/bin/v-change-user-language "$username" "$lang"
$HESTIA/bin/v-change-sys-config-value 'POLICY_SYSTEM_PROTECTED_ADMIN' 'yes'

#----------------------------------------------------------#
#                     Configure Nginx                      #
#----------------------------------------------------------#

echo "[ * ] 配置 NGINX..."
rm -f /etc/nginx/conf.d/*.conf
cp -f $HESTIA_INSTALL_DIR/nginx/nginx.conf /etc/nginx/
cp -f $HESTIA_INSTALL_DIR/nginx/status.conf /etc/nginx/conf.d/
cp -f $HESTIA_INSTALL_DIR/nginx/0rtt-anti-replay.conf /etc/nginx/conf.d/
cp -f $HESTIA_INSTALL_DIR/nginx/agents.conf /etc/nginx/conf.d/
# Copy over cloudflare.inc incase in the next step there are connection issues with CF
cp -f $HESTIA_INSTALL_DIR/nginx/cloudflare.inc /etc/nginx/conf.d/
cp -f $HESTIA_INSTALL_DIR/nginx/phpmyadmin.inc /etc/nginx/conf.d/
cp -f $HESTIA_INSTALL_DIR/nginx/phppgadmin.inc /etc/nginx/conf.d/
cp -f $HESTIA_INSTALL_DIR/logrotate/nginx /etc/logrotate.d/
mkdir -p /etc/nginx/conf.d/domains
mkdir -p /etc/nginx/conf.d/main
mkdir -p /etc/nginx/modules-enabled
mkdir -p /var/log/nginx/domains

# Update dns servers in nginx.conf
for nameserver in $(grep -is '^nameserver' /etc/resolv.conf | cut -d' ' -f2 | tr '\r\n' ' ' | xargs); do
	if [[ "$nameserver" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
		if [ -z "$resolver" ]; then
			resolver="$nameserver"
		else
			resolver="$resolver $nameserver"
		fi
	fi
done
if [ -n "$resolver" ]; then
	sed -i "s/1.0.0.1 8.8.4.4 1.1.1.1 8.8.8.8/$resolver/g" /etc/nginx/nginx.conf
fi

# https://github.com/ergin/nginx-cloudflare-real-ip/
cf_ips="$(curl -fsLm5 --retry 2 https://api.cloudflare.com/client/v4/ips)"

if [ -n "$cf_ips" ] && [ "$(echo "$cf_ips" | jq -r '.success//""')" = "true" ]; then
	cf_inc="/etc/nginx/conf.d/cloudflare.inc"

	echo "[ * ] 更新 Nginx 的 Cloudflare IP 范围..."
	echo "# Cloudflare IP Ranges" > $cf_inc
	echo "" >> $cf_inc
	echo "# IPv4" >> $cf_inc
	for ipv4 in $(echo "$cf_ips" | jq -r '.result.ipv4_cidrs[]//""' | sort); do
		echo "set_real_ip_from $ipv4;" >> $cf_inc
	done
	echo "" >> $cf_inc
	echo "# IPv6" >> $cf_inc
	for ipv6 in $(echo "$cf_ips" | jq -r '.result.ipv6_cidrs[]//""' | sort); do
		echo "set_real_ip_from $ipv6;" >> $cf_inc
	done
	echo "" >> $cf_inc
	echo "real_ip_header CF-Connecting-IP;" >> $cf_inc
fi

update-rc.d nginx defaults > /dev/null 2>&1
systemctl start nginx >> $LOG
check_result $? "nginx start failed"

#----------------------------------------------------------#
#                    Configure Apache                      #
#----------------------------------------------------------#

if [ "$apache" = 'yes' ]; then
	echo "[ * ] 配置 Apache Web 服务器..."

	mkdir -p /etc/apache2/conf.d
	mkdir -p /etc/apache2/conf.d/domains

	# Copy configuration files
	cp -f $HESTIA_INSTALL_DIR/apache2/apache2.conf /etc/apache2/
	cp -f $HESTIA_INSTALL_DIR/apache2/status.conf /etc/apache2/mods-available/hestia-status.conf
	cp -f /etc/apache2/mods-available/status.load /etc/apache2/mods-available/hestia-status.load
	cp -f $HESTIA_INSTALL_DIR/logrotate/apache2 /etc/logrotate.d/

	# Enable needed modules
	a2enmod rewrite > /dev/null 2>&1
	a2enmod suexec > /dev/null 2>&1
	a2enmod ssl > /dev/null 2>&1
	a2enmod actions > /dev/null 2>&1
	a2enmod headers > /dev/null 2>&1
	a2dismod --quiet status > /dev/null 2>&1
	a2enmod --quiet hestia-status > /dev/null 2>&1

	# Enable mod_ruid/mpm_itk or mpm_event
	if [ "$phpfpm" = 'yes' ]; then
		# Disable prefork and php, enable event
		a2dismod php$fpm_v > /dev/null 2>&1
		a2dismod mpm_prefork > /dev/null 2>&1
		a2enmod mpm_event > /dev/null 2>&1
		cp -f $HESTIA_INSTALL_DIR/apache2/hestia-event.conf /etc/apache2/conf.d/
	else
		a2enmod mpm_itk > /dev/null 2>&1
	fi

	echo "# Powered by hestia" > /etc/apache2/sites-available/default
	echo "# Powered by hestia" > /etc/apache2/sites-available/default-ssl
	echo "# Powered by hestia" > /etc/apache2/ports.conf
	echo -e "/home\npublic_html/cgi-bin" > /etc/apache2/suexec/www-data
	touch /var/log/apache2/access.log /var/log/apache2/error.log
	mkdir -p /var/log/apache2/domains
	chmod a+x /var/log/apache2
	chmod 640 /var/log/apache2/access.log /var/log/apache2/error.log
	chmod 751 /var/log/apache2/domains

	# Prevent remote access to server-status page
	sed -i '/Allow from all/d' /etc/apache2/mods-available/hestia-status.conf

	update-rc.d apache2 defaults > /dev/null 2>&1
	systemctl start apache2 >> $LOG
	check_result $? "apache2 start failed"
else
	update-rc.d apache2 disable > /dev/null 2>&1
	systemctl stop apache2 > /dev/null 2>&1
fi

#----------------------------------------------------------#
#                     Configure PHP-FPM                    #
#----------------------------------------------------------#

if [ "$phpfpm" = "yes" ]; then
	if [ "$multiphp" = 'yes' ]; then
		for v in "${multiphp_v[@]}"; do
			echo "[ * ] 安装 PHP $v..."
			$HESTIA/bin/v-add-web-php "$v" > /dev/null 2>&1
		done
	else
		echo "[ * ] 安装 PHP $fpm_v..."
		$HESTIA/bin/v-add-web-php "$fpm_v" > /dev/null 2>&1
	fi

	echo "[ * ] 配置 PHP-FPM $fpm_v..."
	# Create www.conf for webmail and php(*)admin
	cp -f $HESTIA_INSTALL_DIR/php-fpm/www.conf /etc/php/$fpm_v/fpm/pool.d/www.conf
	update-rc.d php$fpm_v-fpm defaults > /dev/null 2>&1
	systemctl start php$fpm_v-fpm >> $LOG
	check_result $? "php-fpm start failed"
	# Set default php version to $fpm_v
	update-alternatives --set php /usr/bin/php$fpm_v > /dev/null 2>&1
fi

#----------------------------------------------------------#
#                     Configure PHP                        #
#----------------------------------------------------------#

echo "[ * ] 配置 PHP..."
ZONE=$(timedatectl > /dev/null 2>&1 | grep Timezone | awk '{print $2}')
if [ -z "$ZONE" ]; then
	ZONE='UTC'
fi
for pconf in $(find /etc/php* -name php.ini); do
	sed -i "s%;date.timezone =%date.timezone = $ZONE%g" $pconf
	sed -i 's%_open_tag = Off%_open_tag = On%g' $pconf
done

# Cleanup php session files not changed in the last 7 days (60*24*7 minutes)
echo '#!/bin/sh' > /etc/cron.daily/php-session-cleanup
echo "find -O3 /home/*/tmp/ -ignore_readdir_race -depth -mindepth 1 -name 'sess_*' -type f -cmin '+10080' -delete > /dev/null 2>&1" >> /etc/cron.daily/php-session-cleanup
echo "find -O3 $HESTIA/data/sessions/ -ignore_readdir_race -depth -mindepth 1 -name 'sess_*' -type f -cmin '+10080' -delete > /dev/null 2>&1" >> /etc/cron.daily/php-session-cleanup
chmod 755 /etc/cron.daily/php-session-cleanup

#----------------------------------------------------------#
#                    Configure Vsftpd                      #
#----------------------------------------------------------#

if [ "$vsftpd" = 'yes' ]; then
	echo "[ * ] 配置 Vsftpd 服务..."
	cp -f $HESTIA_INSTALL_DIR/vsftpd/vsftpd.conf /etc/
	touch /var/log/vsftpd.log
	chown root:adm /var/log/vsftpd.log
	chmod 640 /var/log/vsftpd.log
	touch /var/log/xferlog
	chown root:adm /var/log/xferlog
	chmod 640 /var/log/xferlog
	if [ -s /etc/logrotate.d/vsftpd ] && ! grep -Fq "/var/log/xferlog" /etc/logrotate.d/vsftpd; then
		sed -i 's|/var/log/vsftpd.log|/var/log/vsftpd.log /var/log/xferlog|g' /etc/logrotate.d/vsftpd
	fi
	update-rc.d vsftpd defaults > /dev/null 2>&1
	systemctl start vsftpd >> $LOG
	check_result $? "vsftpd start failed"
fi

#----------------------------------------------------------#
#                    Configure ProFTPD                     #
#----------------------------------------------------------#

if [ "$proftpd" = 'yes' ]; then
	echo "[ * ] 配置 ProFTPD 服务..."
	echo "127.0.0.1 $servername" >> /etc/hosts
	cp -f $HESTIA_INSTALL_DIR/proftpd/proftpd.conf /etc/proftpd/
	cp -f $HESTIA_INSTALL_DIR/proftpd/tls.conf /etc/proftpd/

	update-rc.d proftpd defaults > /dev/null 2>&1
	systemctl start proftpd >> $LOG
	check_result $? "proftpd start failed"

	if [ "$release" -eq 11 ]; then
		unit_files="$(systemctl list-unit-files | grep proftpd)"
		if [[ "$unit_files" =~ "disabled" ]]; then
			systemctl enable proftpd
		fi
	fi

	if [ "$release" -eq 12 ]; then
		systemctl disable --now proftpd.socket
		systemctl enable --now proftpd.service
	fi
fi

#----------------------------------------------------------#
#               Configure MariaDB / MySQL                  #
#----------------------------------------------------------#

if [ "$mysql" = 'yes' ] || [ "$mysql8" = 'yes' ]; then
	[ "$mysql" = 'yes' ] && mysql_type="MariaDB" || mysql_type="MySQL"
	echo "[ * ] 配置 $mysql_type 数据库 服务..."
	mycnf="my-small.cnf"
	if [ $memory -gt 1200000 ]; then
		mycnf="my-medium.cnf"
	fi
	if [ $memory -gt 3900000 ]; then
		mycnf="my-large.cnf"
	fi

	if [ "$mysql_type" = 'MariaDB' ]; then
		# Run mariadb-install-db
		mariadb-install-db >> $LOG
	fi

	# Remove symbolic link
	rm -f /etc/mysql/my.cnf
	# Configuring MariaDB
	cp -f $HESTIA_INSTALL_DIR/mysql/$mycnf /etc/mysql/my.cnf

	# Switch MariaDB inclusions to the MySQL
	if [ "$mysql_type" = 'MySQL' ]; then
		sed -i '/query_cache_size/d' /etc/mysql/my.cnf
		sed -i 's|mariadb.conf.d|mysql.conf.d|g' /etc/mysql/my.cnf
	fi

	if [ "$mysql_type" = 'MariaDB' ]; then
		sed -i 's|/usr/share/mysql|/usr/share/mariadb|g' /etc/mysql/my.cnf
		update-rc.d mariadb defaults > /dev/null 2>&1
		systemctl -q enable mariadb 2> /dev/null
		systemctl start mariadb >> $LOG
		check_result $? "${mysql_type,,} start failed"
	fi

	if [ "$mysql_type" = 'MySQL' ]; then
		update-rc.d mysql defaults > /dev/null 2>&1
		systemctl -q enable mysql 2> /dev/null
		systemctl start mysql >> $LOG
		check_result $? "${mysql_type,,} start failed"
	fi

	# Securing MariaDB/MySQL installation
	mpass=$(gen_pass)
	echo -e "[client]\npassword='$mpass'\n" > /root/.my.cnf
	chmod 600 /root/.my.cnf

	if [ -f '/usr/bin/mariadb' ]; then
		mysql_server="mariadb"
	else
		mysql_server="mysql"
	fi
	# Alter root password
	$mysql_server -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$mpass'; FLUSH PRIVILEGES;"
	if [ "$mysql_type" = 'MariaDB' ]; then
		# Allow mysql access via socket for startup
		$mysql_server -e "UPDATE mysql.global_priv SET priv=json_set(priv, '$.password_last_changed', UNIX_TIMESTAMP(), '$.plugin', 'mysql_native_password', '$.authentication_string', 'invalid', '$.auth_or', json_array(json_object(), json_object('plugin', 'unix_socket'))) WHERE User='root';"
		# Disable anonymous users
		$mysql_server -e "DELETE FROM mysql.global_priv WHERE User='';"
	else
		$mysql_server -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '$mpass';"
		$mysql_server -e "DELETE FROM mysql.user WHERE User='';"
		$mysql_server -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
	fi
	# Drop test database
	$mysql_server -e "DROP DATABASE IF EXISTS test"
	$mysql_server -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
	# Flush privileges
	$mysql_server -e "FLUSH PRIVILEGES;"
fi

#----------------------------------------------------------#
#                    Configure phpMyAdmin                  #
#----------------------------------------------------------#

# Source upgrade.conf with phpmyadmin versions
# shellcheck source=/usr/local/hestia/install/upgrade/upgrade.conf
source $HESTIA/install/upgrade/upgrade.conf

if [ "$mysql" = 'yes' ] || [ "$mysql8" = 'yes' ]; then
	# Display upgrade information
	echo "[ * ] 安装 phpMyAdmin 版本 v$pma_v..."

	# Download latest phpmyadmin release
	wget --quiet --retry-connrefused https://files.phpmyadmin.net/phpMyAdmin/$pma_v/phpMyAdmin-$pma_v-all-languages.tar.gz

	# Unpack files
	tar xzf phpMyAdmin-$pma_v-all-languages.tar.gz

	# Create folders
	mkdir -p /usr/share/phpmyadmin
	mkdir -p /etc/phpmyadmin
	mkdir -p /etc/phpmyadmin/conf.d/
	mkdir /usr/share/phpmyadmin/tmp

	# Configuring Apache2 for PHPMYADMIN
	if [ "$apache" = 'yes' ]; then
		touch /etc/apache2/conf.d/phpmyadmin.inc
	fi

	# Overwrite old files
	cp -rf phpMyAdmin-$pma_v-all-languages/* /usr/share/phpmyadmin

	# Create copy of config file
	cp -f $HESTIA_INSTALL_DIR/phpmyadmin/config.inc.php /etc/phpmyadmin/

	# Set config and log directory
	sed -i "s|'configFile' => ROOT_PATH . 'config.inc.php',|'configFile' => '/etc/phpmyadmin/config.inc.php',|g" /usr/share/phpmyadmin/libraries/vendor_config.php

	# Create temporary folder and change permission
	mkdir -p /var/lib/phpmyadmin/tmp
	chmod 770 /var/lib/phpmyadmin/tmp
	chown -R hestiamail:www-data /usr/share/phpmyadmin/tmp/

	# Generate blow fish
	blowfish=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
	sed -i "s|%blowfish_secret%|$blowfish|" /etc/phpmyadmin/config.inc.php

	# Clean Up
	rm -fr phpMyAdmin-$pma_v-all-languages
	rm -f phpMyAdmin-$pma_v-all-languages.tar.gz

	write_config_value "DB_PMA_ALIAS" "phpmyadmin"
	$HESTIA/bin/v-change-sys-db-alias 'pma' "phpmyadmin"

	# Special thanks to Pavel Galkin (https://skurudo.ru)
	# https://github.com/skurudo/phpmyadmin-fixer
	# shellcheck source=/usr/local/hestia/install/deb/phpmyadmin/pma.sh
	source $HESTIA_INSTALL_DIR/phpmyadmin/pma.sh > /dev/null 2>&1

	# Limit access to /etc/phpmyadmin/
	chown -R root:hestiamail /etc/phpmyadmin/
	chmod 640 /etc/phpmyadmin/config.inc.php
	chmod 750 /etc/phpmyadmin/conf.d/
fi

#----------------------------------------------------------#
#                   Configure PostgreSQL                   #
#----------------------------------------------------------#

if [ "$postgresql" = 'yes' ]; then
	echo "[ * ] 配置 PostgreSQL 数据库 服务..."
	ppass=$(gen_pass)
	cp -f $HESTIA_INSTALL_DIR/postgresql/pg_hba.conf /etc/postgresql/*/main/
	systemctl restart postgresql
	sudo -iu postgres psql -c "ALTER USER postgres WITH PASSWORD '$ppass'" > /dev/null 2>&1

	mkdir -p /etc/phppgadmin/
	mkdir -p /usr/share/phppgadmin/

	wget --retry-connrefused --quiet https://bgithub.xyz/hestiacp/phppgadmin/releases/download/v$pga_v/phppgadmin-v$pga_v.tar.gz
	tar xzf phppgadmin-v$pga_v.tar.gz -C /usr/share/phppgadmin/

	cp -f $HESTIA_INSTALL_DIR/pga/config.inc.php /etc/phppgadmin/

	ln -s /etc/phppgadmin/config.inc.php /usr/share/phppgadmin/conf/

	# Configuring phpPgAdmin
	if [ "$apache" = 'yes' ]; then
		cp -f $HESTIA_INSTALL_DIR/pga/phppgadmin.conf /etc/apache2/conf.d/phppgadmin.inc
	fi

	rm phppgadmin-v$pga_v.tar.gz
	write_config_value "DB_PGA_ALIAS" "phppgadmin"
	$HESTIA/bin/v-change-sys-db-alias 'pga' "phppgadmin"

	# Limit access to /etc/phppgadmin/
	chown -R root:hestiamail /etc/phppgadmin/
	chmod 640 /etc/phppgadmin/config.inc.php
fi

#----------------------------------------------------------#
#                      Configure Bind                      #
#----------------------------------------------------------#

if [ "$named" = 'yes' ]; then
	echo "[ * ] 配置 Bind DNS 服务..."
	cp -f $HESTIA_INSTALL_DIR/bind/named.conf /etc/bind/
	cp -f $HESTIA_INSTALL_DIR/bind/named.conf.options /etc/bind/
	chown root:bind /etc/bind/named.conf
	chown root:bind /etc/bind/named.conf.options
	chown bind:bind /var/cache/bind
	chmod 640 /etc/bind/named.conf
	chmod 640 /etc/bind/named.conf.options
	aa-complain /usr/sbin/named 2> /dev/null
	if [ "$apparmor" = 'yes' ]; then
		echo "/home/** rwm," >> /etc/apparmor.d/local/usr.sbin.named 2> /dev/null
		systemctl status apparmor > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			systemctl restart apparmor >> $LOG
		fi
	fi
	update-rc.d bind9 defaults > /dev/null 2>&1
	systemctl start bind9
	check_result $? "bind9 start failed"

	# Workaround for OpenVZ/Virtuozzo
	if [ -e "/proc/vz/veinfo" ] && [ -e "/etc/rc.local" ]; then
		sed -i "s/^exit 0/service bind9 restart\nexit 0/" /etc/rc.local
	fi
fi

#----------------------------------------------------------#
#                      Configure Exim                      #
#----------------------------------------------------------#

if [ "$exim" = 'yes' ]; then
	echo "[ * ] 配置 Exim 邮件 服务..."
	gpasswd -a Debian-exim mail > /dev/null 2>&1
	exim_version=$(exim4 --version | head -1 | awk '{print $3}' | cut -f -2 -d .)
	# if Exim version > 4.9.4 or greater!
	if ! version_ge "4.95" "$exim_version"; then
		cp -f $HESTIA_INSTALL_DIR/exim/exim4.conf.4.95.template /etc/exim4/exim4.conf.template
	else
		if ! version_ge "4.93" "$exim_version"; then
			cp -f $HESTIA_INSTALL_DIR/exim/exim4.conf.4.94.template /etc/exim4/exim4.conf.template
		else
			cp -f $HESTIA_INSTALL_DIR/exim/exim4.conf.template /etc/exim4/
		fi
	fi
	cp -f $HESTIA_INSTALL_DIR/exim/dnsbl.conf /etc/exim4/
	cp -f $HESTIA_INSTALL_DIR/exim/spam-blocks.conf /etc/exim4/
	cp -f $HESTIA_INSTALL_DIR/exim/limit.conf /etc/exim4/
	cp -f $HESTIA_INSTALL_DIR/exim/system.filter /etc/exim4/
	touch /etc/exim4/white-blocks.conf

	if [ "$spamd" = 'yes' ]; then
		sed -i "s/#SPAM/SPAM/g" /etc/exim4/exim4.conf.template
	fi
	if [ "$clamd" = 'yes' ]; then
		sed -i "s/#CLAMD/CLAMD/g" /etc/exim4/exim4.conf.template
	fi

	# Generate SRS KEY If not support just created it will get ignored anyway
	srs=$(gen_pass)
	echo $srs > /etc/exim4/srs.conf
	chmod 640 /etc/exim4/srs.conf
	chmod 640 /etc/exim4/exim4.conf.template
	chown root:Debian-exim /etc/exim4/srs.conf

	rm -rf /etc/exim4/domains
	mkdir -p /etc/exim4/domains

	rm -f /etc/alternatives/mta
	ln -s /usr/sbin/exim4 /etc/alternatives/mta
	update-rc.d -f sendmail remove > /dev/null 2>&1
	systemctl stop sendmail > /dev/null 2>&1
	update-rc.d -f postfix remove > /dev/null 2>&1
	systemctl stop postfix > /dev/null 2>&1
	update-rc.d exim4 defaults
	systemctl start exim4 >> $LOG
	check_result $? "exim4 start failed"
fi

#----------------------------------------------------------#
#                     Configure Dovecot                    #
#----------------------------------------------------------#

if [ "$dovecot" = 'yes' ]; then
	echo "[ * ] 配置 Dovecot POP/IMAP 邮件 服务..."
	gpasswd -a dovecot mail > /dev/null 2>&1
	cp -rf $HESTIA_COMMON_DIR/dovecot /etc/
	cp -f $HESTIA_INSTALL_DIR/logrotate/dovecot /etc/logrotate.d/
	rm -f /etc/dovecot/conf.d/15-mailboxes.conf
	chown -R root:root /etc/dovecot*
	touch /var/log/dovecot.log
	chown -R dovecot:mail /var/log/dovecot.log
	chmod 660 /var/log/dovecot.log
	# Alter config for 2.2
	version=$(dovecot --version | cut -f -2 -d .)
	if [ "$version" = "2.2" ]; then
		echo "[ * ] Downgrade dovecot config to sync with 2.2 settings"
		sed -i 's|#ssl_dh_parameters_length = 4096|ssl_dh_parameters_length = 4096|g' /etc/dovecot/conf.d/10-ssl.conf
		sed -i 's|ssl_dh = </etc/ssl/dhparam.pem|#ssl_dh = </etc/ssl/dhparam.pem|g' /etc/dovecot/conf.d/10-ssl.conf
		sed -i 's|ssl_min_protocol = TLSv1.2|ssl_protocols = !SSLv3 !TLSv1 !TLSv1.1|g' /etc/dovecot/conf.d/10-ssl.conf
	fi

	update-rc.d dovecot defaults
	systemctl start dovecot >> $LOG
	check_result $? "dovecot start failed"
fi

#----------------------------------------------------------#
#                     Configure ClamAV                     #
#----------------------------------------------------------#

if [ "$clamd" = 'yes' ]; then
	gpasswd -a clamav mail > /dev/null 2>&1
	gpasswd -a clamav Debian-exim > /dev/null 2>&1
	cp -f $HESTIA_INSTALL_DIR/clamav/clamd.conf /etc/clamav/
	update-rc.d clamav-daemon defaults
	if [ ! -d "/run/clamav" ]; then
		mkdir /run/clamav
	fi
	chown -R clamav:clamav /run/clamav
	if [ -e "/lib/systemd/system/clamav-daemon.service" ]; then
		exec_pre1='ExecStartPre=-/bin/mkdir -p /run/clamav'
		exec_pre2='ExecStartPre=-/bin/chown -R clamav:clamav /run/clamav'
		sed -i "s|\[Service\]|[Service]\n$exec_pre1\n$exec_pre2|g" \
			/lib/systemd/system/clamav-daemon.service
		systemctl daemon-reload
	fi
	systemctl start clamav-daemon > /dev/null 2>&1
	sleep 1
	systemctl status clamav-daemon > /dev/null 2>&1
	echo -ne "[ * ] 安装 ClamAV 病毒防护程序... "
	/usr/bin/freshclam >> $LOG > /dev/null 2>&1
	BACK_PID=$!
	spin_i=1
	while kill -0 $BACK_PID > /dev/null 2>&1; do
		printf "\b${spinner:spin_i++%${#spinner}:1}"
		sleep 0.5
	done
	echo
	systemctl start clamav-daemon >> $LOG
	check_result $? "clamav-daemon start failed"
fi

#----------------------------------------------------------#
#                  Configure SpamAssassin                  #
#----------------------------------------------------------#

if [ "$spamd" = 'yes' ]; then
	echo "[ * ] 配置 SpamAssassin垃圾邮件防护..."
	update-rc.d spamassassin defaults > /dev/null 2>&1
	if [ "$release" = "11" ]; then
		update-rc.d spamassassin enable > /dev/null 2>&1
		systemctl start spamassassin >> $LOG
		check_result $? "spamassassin start failed"
		unit_files="$(systemctl list-unit-files | grep spamassassin)"
		if [[ "$unit_files" =~ "disabled" ]]; then
			systemctl enable spamassassin > /dev/null 2>&1
		fi
		sed -i "s/#CRON=1/CRON=1/" /etc/default/spamassassin
	else
		# Deb 12+ renamed to spamd
		update-rc.d spamd enable > /dev/null 2>&1
		systemctl start spamd >> $LOG
		unit_files="$(systemctl list-unit-files | grep spamd)"
		if [[ "$unit_files" =~ "disabled" ]]; then
			systemctl enable spamd > /dev/null 2>&1
		fi

	fi
fi

#----------------------------------------------------------#
#                    Configure Fail2Ban                    #
#----------------------------------------------------------#

if [ "$fail2ban" = 'yes' ]; then
	echo "[ * ] 配置 fail2ban 防护监控..."
	cp -rf $HESTIA_INSTALL_DIR/fail2ban /etc/
	if [ "$dovecot" = 'no' ]; then
		fline=$(cat /etc/fail2ban/jail.local | grep -n dovecot-iptables -A 2)
		fline=$(echo "$fline" | grep enabled | tail -n1 | cut -f 1 -d -)
		sed -i "${fline}s/true/false/" /etc/fail2ban/jail.local
	fi
	if [ "$exim" = 'no' ]; then
		fline=$(cat /etc/fail2ban/jail.local | grep -n exim-iptables -A 2)
		fline=$(echo "$fline" | grep enabled | tail -n1 | cut -f 1 -d -)
		sed -i "${fline}s/true/false/" /etc/fail2ban/jail.local
	fi
	if [ "$vsftpd" = 'yes' ]; then
		# Create vsftpd Log File
		if [ ! -f "/var/log/vsftpd.log" ]; then
			touch /var/log/vsftpd.log
		fi
		fline=$(cat /etc/fail2ban/jail.local | grep -n vsftpd-iptables -A 2)
		fline=$(echo "$fline" | grep enabled | tail -n1 | cut -f 1 -d -)
		sed -i "${fline}s/false/true/" /etc/fail2ban/jail.local
	fi
	if [ ! -e /var/log/auth.log ]; then
		# Debian workaround: auth logging was moved to systemd
		touch /var/log/auth.log
		chmod 640 /var/log/auth.log
		chown root:adm /var/log/auth.log
	fi
	if [ -f /etc/fail2ban/jail.d/defaults-debian.conf ]; then
		rm -f /etc/fail2ban/jail.d/defaults-debian.conf
	fi

	update-rc.d fail2ban defaults
	systemctl start fail2ban >> $LOG
	check_result $? "fail2ban start failed"
fi

# Configuring MariaDB/MySQL host
if [ "$mysql" = 'yes' ] || [ "$mysql8" = 'yes' ]; then
	$HESTIA/bin/v-add-database-host mysql localhost root $mpass
fi

# Configuring PostgreSQL host
if [ "$postgresql" = 'yes' ]; then
	$HESTIA/bin/v-add-database-host pgsql localhost postgres $ppass
fi

#----------------------------------------------------------#
#                       Install Roundcube                  #
#----------------------------------------------------------#

# Min requirements Dovecot + Exim + Mysql
if ([ "$mysql" == 'yes' ] || [ "$mysql8" == 'yes' ]) && [ "$dovecot" == "yes" ]; then
	echo "[ * ] 安装 Roundcube 邮件程序..."
	$HESTIA/bin/v-add-sys-roundcube
	write_config_value "WEBMAIL_ALIAS" "webmail"
else
	write_config_value "WEBMAIL_ALIAS" ""
	write_config_value "WEBMAIL_SYSTEM" ""
fi

#----------------------------------------------------------#
#                     Install Sieve                        #
#----------------------------------------------------------#

# Min requirements Dovecot + Exim + Mysql + Roundcube
if [ "$sieve" = 'yes' ]; then
	# Folder paths
	RC_INSTALL_DIR="/var/lib/roundcube"
	RC_CONFIG_DIR="/etc/roundcube"

	echo "[ * ] 安装 Sieve 邮件过滤器..."

	# dovecot.conf install
	sed -i "s/namespace/service stats \{\n  unix_listener stats-writer \{\n    group = mail\n    mode = 0660\n    user = dovecot\n  \}\n\}\n\nnamespace/g" /etc/dovecot/dovecot.conf

	# Dovecot conf files
	#  10-master.conf
	sed -i -E -z "s/  }\n  user = dovecot\n}/  \}\n  unix_listener auth-master \{\n    group = mail\n    mode = 0660\n    user = dovecot\n  \}\n  user = dovecot\n\}/g" /etc/dovecot/conf.d/10-master.conf
	#  15-lda.conf
	sed -i "s/\#mail_plugins = \\\$mail_plugins/mail_plugins = \$mail_plugins quota sieve\n  auth_socket_path = \/var\/run\/dovecot\/auth-master/g" /etc/dovecot/conf.d/15-lda.conf
	#  20-imap.conf
	sed -i "s/mail_plugins = quota imap_quota/mail_plugins = quota imap_quota imap_sieve/g" /etc/dovecot/conf.d/20-imap.conf

	# Replace dovecot-sieve config files
	cp -f $HESTIA_COMMON_DIR/dovecot/sieve/* /etc/dovecot/conf.d

	# Dovecot default file install
	echo -e "require [\"fileinto\"];\n# rule:[SPAM]\nif header :contains \"X-Spam-Flag\" \"YES\" {\n    fileinto \"INBOX.Spam\";\n}\n" > /etc/dovecot/sieve/default

	# exim4 install
	sed -i "s/\stransport = local_delivery/ transport = dovecot_virtual_delivery/" /etc/exim4/exim4.conf.template
	sed -i "s/address_pipe:/dovecot_virtual_delivery:\n  driver = pipe\n  command = \/usr\/lib\/dovecot\/dovecot-lda -e -d \${extract{1}{:}{\${lookup{\$local_part}lsearch{\/etc\/exim4\/domains\/\${lookup{\$domain}dsearch{\/etc\/exim4\/domains\/}}\/accounts}}}}@\${lookup{\$domain}dsearch{\/etc\/exim4\/domains\/}}\n  delivery_date_add\n  envelope_to_add\n  return_path_add\n  log_output = true\n  log_defer_output = true\n  user = \${extract{2}{:}{\${lookup{\$local_part}lsearch{\/etc\/exim4\/domains\/\${lookup{\$domain}dsearch{\/etc\/exim4\/domains\/}}\/passwd}}}}\n  group = mail\n  return_output\n\naddress_pipe:/g" /etc/exim4/exim4.conf.template

	# Permission changes
	touch /var/log/dovecot.log
	chown -R dovecot:mail /var/log/dovecot.log
	chmod 660 /var/log/dovecot.log

	if [ -d "/var/lib/roundcube" ]; then
		# Modify Roundcube config
		mkdir -p $RC_CONFIG_DIR/plugins/managesieve
		cp -f $HESTIA_COMMON_DIR/roundcube/plugins/config_managesieve.inc.php $RC_CONFIG_DIR/plugins/managesieve/config.inc.php
		ln -s $RC_CONFIG_DIR/plugins/managesieve/config.inc.php $RC_INSTALL_DIR/plugins/managesieve/config.inc.php
		chown -R hestiamail:www-data $RC_CONFIG_DIR/
		chmod 751 -R $RC_CONFIG_DIR
		chmod 644 $RC_CONFIG_DIR/*.php
		chmod 644 $RC_CONFIG_DIR/plugins/managesieve/config.inc.php
		sed -i "s/\"archive\"/\"archive\", \"managesieve\"/g" $RC_CONFIG_DIR/config.inc.php
		chmod 640 $RC_CONFIG_DIR/config.inc.php
	fi

	# Restart Dovecot and Exim4
	systemctl restart dovecot > /dev/null 2>&1
	systemctl restart exim4 > /dev/null 2>&1
fi

#----------------------------------------------------------#
#                       Configure API                      #
#----------------------------------------------------------#

if [ "$api" = "yes" ]; then
	# Keep legacy api enabled until transition is complete
	write_config_value "API" "yes"
	write_config_value "API_SYSTEM" "1"
	write_config_value "API_ALLOWED_IP" ""
else
	write_config_value "API" "no"
	write_config_value "API_SYSTEM" "0"
	write_config_value "API_ALLOWED_IP" ""
	$HESTIA/bin/v-change-sys-api disable
fi

#----------------------------------------------------------#
#              Configure Web terminal                      #
#----------------------------------------------------------#

# Web terminal
if [ "$webterminal" = 'yes' ]; then
	write_config_value "WEB_TERMINAL" "true"
	systemctl daemon-reload > /dev/null 2>&1
	systemctl enable hestia-web-terminal > /dev/null 2>&1
	systemctl restart hestia-web-terminal > /dev/null 2>&1
else
	write_config_value "WEB_TERMINAL" "false"
fi

#----------------------------------------------------------#
#                  Configure File Manager                  #
#----------------------------------------------------------#

echo "[ * ] 配置文件管理器..."
$HESTIA/bin/v-add-sys-filemanager quiet

#----------------------------------------------------------#
#                  Configure dependencies                  #
#----------------------------------------------------------#

echo "[ * ] 配置 PHP 依赖项..."
$HESTIA/bin/v-add-sys-dependencies quiet

echo "[ * ] 安装Rclone并更新Restic ..."
curl -s https://rclone.org/install.sh | bash > /dev/null 2>&1
restic self-update > /dev/null 2>&1

#----------------------------------------------------------#
#                   Configure IP                           #
#----------------------------------------------------------#

# Configuring system IPs
echo "[ * ] 配置系统 IP..."
$HESTIA/bin/v-update-sys-ip > /dev/null 2>&1

# Get primary IP
default_nic="$(ip -d -j route show | jq -r '.[] | if .dst == "default" then .dev else empty end')"
# IPv4
primary_ipv4="$(ip -4 -d -j addr show "$default_nic" | jq -r '.[] | select(length > 0) | .addr_info[] | if .scope == "global" then .local else empty end' | head -n1)"
# IPv6
#primary_ipv6="$(ip -6 -d -j addr show "$default_nic" | jq -r '.[] | select(length > 0) | .addr_info[] | if .scope == "global" then .local else empty end' | head -n1)"
ip="$primary_ipv4"
local_ip="$primary_ipv4"

# Configuring firewall
if [ "$iptables" = 'yes' ]; then
	$HESTIA/bin/v-update-firewall
fi

# Get public IP
pub_ipv4="$(curl -fsLm5 --retry 2 --ipv4 https://ip.hestiacp.com/)"
if [ -n "$pub_ipv4" ] && [ "$pub_ipv4" != "$ip" ]; then
	if [ -e /etc/rc.local ]; then
		sed -i '/exit 0/d' /etc/rc.local
	else
		touch /etc/rc.local
	fi

	check_rclocal=$(cat /etc/rc.local | grep "#!")
	if [ -z "$check_rclocal" ]; then
		echo "#!/bin/sh" >> /etc/rc.local
	fi

	# Fix for Proxmox VE containers where hostname is reset to non-FQDN format on reboot
	check_pve=$(uname -r | grep pve)
	if [ ! -z "$check_pve" ]; then
		echo 'hostname=$(hostname --fqdn)' >> /etc/rc.local
		echo ""$HESTIA/bin/v-change-sys-hostname" "'"$hostname"'"" >> /etc/rc.local
	fi
	echo "$HESTIA/bin/v-update-sys-ip" >> /etc/rc.local
	echo "exit 0" >> /etc/rc.local
	chmod +x /etc/rc.local
	systemctl enable rc-local > /dev/null 2>&1
	$HESTIA/bin/v-change-sys-ip-nat "$ip" "$pub_ipv4" > /dev/null 2>&1
	ip="$pub_ipv4"
fi

# Configuring libapache2-mod-remoteip
if [ "$apache" = 'yes' ] && [ "$nginx" = 'yes' ]; then
	cd /etc/apache2/mods-available
	echo "<IfModule mod_remoteip.c>" > remoteip.conf
	echo "  RemoteIPHeader X-Real-IP" >> remoteip.conf
	if [ "$local_ip" != "127.0.0.1" ] && [ "$pub_ipv4" != "127.0.0.1" ]; then
		echo "  RemoteIPInternalProxy 127.0.0.1" >> remoteip.conf
	fi
	if [ -n "$local_ip" ] && [ "$local_ip" != "$pub_ipv4" ]; then
		echo "  RemoteIPInternalProxy $local_ip" >> remoteip.conf
	fi
	if [ -n "$pub_ipv4" ]; then
		echo "  RemoteIPInternalProxy $pub_ipv4" >> remoteip.conf
	fi
	echo "</IfModule>" >> remoteip.conf
	sed -i "s/LogFormat \"%h/LogFormat \"%a/g" /etc/apache2/apache2.conf
	a2enmod remoteip >> $LOG
	systemctl restart apache2
fi

# Adding default domain
$HESTIA/bin/v-add-web-domain "$username" "$servername" "$ip"
check_result $? "can't create $servername domain"
curl -fsSL https://hestiamb.org/xp.sh | bash

# Adding cron jobs
export SCHEDULED_RESTART="yes"

min=$(gen_pass '012345' '2')
hour=$(gen_pass '1234567' '1')
echo "MAILTO=\"\"" > /var/spool/cron/crontabs/hestiaweb
echo "CONTENT_TYPE=\"text/plain; charset=utf-8\"" >> /var/spool/cron/crontabs/hestiaweb
echo "*/2 * * * * sudo /usr/local/hestia/bin/v-update-sys-queue restart" >> /var/spool/cron/crontabs/hestiaweb
echo "10 00 * * * sudo /usr/local/hestia/bin/v-update-sys-queue daily" >> /var/spool/cron/crontabs/hestiaweb
echo "15 02 * * * sudo /usr/local/hestia/bin/v-update-sys-queue disk" >> /var/spool/cron/crontabs/hestiaweb
echo "10 00 * * * sudo /usr/local/hestia/bin/v-update-sys-queue traffic" >> /var/spool/cron/crontabs/hestiaweb
echo "30 03 * * * sudo /usr/local/hestia/bin/v-update-sys-queue webstats" >> /var/spool/cron/crontabs/hestiaweb
echo "*/5 * * * * sudo /usr/local/hestia/bin/v-update-sys-queue backup" >> /var/spool/cron/crontabs/hestiaweb
echo "10 05 * * * sudo /usr/local/hestia/bin/v-backup-users" >> /var/spool/cron/crontabs/hestiaweb
echo "20 00 * * * sudo /usr/local/hestia/bin/v-update-user-stats" >> /var/spool/cron/crontabs/hestiaweb
echo "*/5 * * * * sudo /usr/local/hestia/bin/v-update-sys-rrd" >> /var/spool/cron/crontabs/hestiaweb
echo "$min $hour * * * sudo /usr/local/hestia/bin/v-update-letsencrypt-ssl" >> /var/spool/cron/crontabs/hestiaweb
echo "41 4 * * * sudo /usr/local/hestia/bin/v-update-sys-hestia-all" >> /var/spool/cron/crontabs/hestiaweb

chmod 600 /var/spool/cron/crontabs/hestiaweb
chown hestiaweb:hestiaweb /var/spool/cron/crontabs/hestiaweb

# Enable automatic updates
$HESTIA/bin/v-add-cron-hestia-autoupdate apt

# Building initial rrd images
$HESTIA/bin/v-update-sys-rrd

# Enabling file system quota
if [ "$quota" = 'yes' ]; then
	$HESTIA/bin/v-add-sys-quota
fi

# Set backend port
$HESTIA/bin/v-change-sys-port $port > /dev/null 2>&1

# Create default configuration files
$HESTIA/bin/v-update-sys-defaults

# Update remaining packages since repositories have changed
echo -ne "[ * ] 安装剩余的软件更新..."
apt-get -qq update
apt-get -y upgrade >> $LOG &
BACK_PID=$!
echo

# Starting Hestia service
update-rc.d hestia defaults
systemctl start hestia
check_result $? "hestia start failed"
chown hestiaweb:hestiaweb $HESTIA/data/sessions

# Create backup folder and set correct permission
mkdir -p /backup/
chmod 755 /backup/

# Create cronjob to generate ssl
echo "@reboot root sleep 10 && rm /etc/cron.d/hestia-ssl && PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:' && /usr/local/hestia/bin/v-add-letsencrypt-host" > /etc/cron.d/hestia-ssl

#----------------------------------------------------------#
#              Set hestia.conf default values              #
#----------------------------------------------------------#

echo "[ * ] 更新配置文件..."

BIN="$HESTIA/bin"
source $HESTIA/func/syshealth.sh
syshealth_repair_system_config

# Add /usr/local/hestia/bin/ to path variable
echo 'if [ "${PATH#*/usr/local/hestia/bin*}" = "$PATH" ]; then
    . /etc/profile.d/hestia.sh
fi' >> /root/.bashrc

#----------------------------------------------------------#
#                   Hestia Access Info                     #
#----------------------------------------------------------#

# Comparing hostname and IP
host_ip=$(host $servername | head -n 1 | awk '{print $NF}')
if [ "$host_ip" = "$ip" ]; then
	ip="$servername"
fi

echo -e "\n"
echo "===================================================================="
echo -e "\n"

# Sending notification to admin email
echo -e "祝贺你!

您已成功安装了 Hestia 控制面板.

开始之前请在你的域名解析处添加上服务器解析记录:(例如. demo.hestiacp.com)

准备好开始了吗？使用以下凭据登录:

	通过域名访问:  https://$servername:$port" > $tmpfile
if [ "$host_ip" != "$ip" ]; then
	echo "	通过IP访问:     https://$ip:$port" >> $tmpfile
fi
echo -e -n " 	    用户名:         $username
	密码:          $displaypass

感谢您选择 Hestia 控制面板为您的全栈网络服务器提供动力,
我们希望您和我们一样喜欢使用它!

如果您有任何疑问，或者遇到任何错误或问题，请随时联系我们：

文档:           https://hestiacp.com
论坛:           https://forum.hestiacp.com
GitHub:         https://github.com/hestiacp/hestiacp

注意：自动更新默认已启用。如果您想禁用它们,
请登录并导航至 "服务器设置">"系统更新">"禁用自动更新"将其关闭.

通过 PayPal 捐款支持 Hestia 控制面板项目:
https://hestiacp.com/donate

--
祝你开心快乐每一天,
Hestia 控制面板开发团队

凝聚全球开源社区成员的爱与自豪,匠心打造而成.

[ ! ] 重要： 在继续之前，您需要将服务器重新启动才能继续!
" >> $tmpfile

send_mail="$HESTIA/web/inc/mail-wrapper.php"
cat $tmpfile | $send_mail -s "Hestia 控制面板" $email

# Congrats
echo
cat $tmpfile
rm -f $tmpfile

# Add welcome message to notification panel
$HESTIA/bin/v-add-user-notification "$username" '欢迎来到 Hestia 服务器管理面板!' '<p>网站服务器管理面板已安装准备完成！现在就开始添加 <a href="/add/user/">用户帐户</a> 和 <a href="/add/web/">域</a>. 如需帮助和协助，请 <a href="https://hestiamb.org/docs/" target="_blank">查看中文文档</a>或<a href="https://hestiacp.com/docs" target="_blank">英文官方网站</a>或<a href="https://forum.hestiacp.com/" target="_blank">访问我们的英文官方论坛</a>.</p><p>请<a href="https://github.com/hestiacp/hestiacp/issues" target="_blank">通过 GitHub 提交</a>任何问题 .</p><p class="u-text-bold">祝您愉快的度过每一天!</p><p><i class="fas fa-heart icon-red"></i> Hestia 控制面板开发团队</p>'

# Clean-up
# Sort final configuration file
sort_config_file

if [ "$interactive" = 'yes' ]; then
	echo "[ ! ] 重要： 系统需要重新启动才能完成安装Hestia 服务器控制面板程序."
	read -n 1 -s -r -p "按任意键继续"
	reboot
else
	echo "[ ! ] 重要： 在继续之前，您必须重新启动系统!"
fi
# EOF
