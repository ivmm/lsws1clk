#!/bin/bash
# /***************************************************************
# LiteSpeed Latest
# WordPress Latest 
# LSCache Latest 
# PHP 7.3 
# MariaDB 10.4
# Memcached
# Redis
# PHPMyAdmin Latest
# ****************************************************************/
### Author: Cold Egg

CMDFD='/opt'
WWWFD='/var/www'
DOCROOT='/var/www/html'
PHPMYFD='/var/www/phpmyadmin'
PHPMYCONF="${PHPMYFD}/config.inc.php"
LSDIR='/usr/local/lsws'
LSCONF="${LSDIR}/conf/httpd_config.xml"
LSVCONF="${LSDIR}/DEFAULT/conf/vhconf.xml"
USER=''
GROUP=''
THEME='twentytwenty'
MARIAVER='10.4'
PHPVER='73'
PHP_M='7'
PHP_S='3'
FIREWALLLIST="22 80 443"
PHP_BIN="${LSDIR}/lsphp${PHPVER}/bin/lsphp"
PHPINICONF=""
WPCFPATH="${DOCROOT}/wp-config.php"
REPOPATH=''
WP_CLI='/usr/local/bin/wp'
MEMCACHECONF=''
REDISSERVICE=''
REDISCONF=''
WPCONSTCONF="${DOCROOT}/wp-content/plugins/litespeed-cache/data/const.default.ini"
PLUGIN='litespeed-cache.zip'
BANNERNAME='wordpress'
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
BANNERDST=''
SKIP_WP=0
SKIP_REDIS=0
SKIP_MEMCA=0
OSNAMEVER=''
OSNAME=''
OSVER=''

silent() {
  if [[ $debug ]] ; then
    "$@"
  else
    "$@" >/dev/null 2>&1
  fi
}

create_doc_fd(){
    if [ ! -d ${DOCROOT} ]; then
        echoG "Create ${DOCROOT} folder"
        mkdir -p ${DOCROOT}
    fi
}

echoY() {
    echo -e "\033[38;5;148m${1}\033[39m"
}
echoG() {
    echo -e "\033[38;5;71m${1}\033[39m"
}
echoR()
{
    echo -e "\033[38;5;203m${1}\033[39m"
}

help_message(){
    case ${1} in
    "1")
    echoY 'Installation finished, please reopen the ssh console to see the banner.'
    ;;
    esac
}

get_ip(){
    if [ -e /sys/devices/virtual/dmi/id/product_uuid ] && [ "$(sudo cat /sys/devices/virtual/dmi/id/product_uuid | cut -c 1-3)" = 'EC2' ]; then
        MYIP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
    elif [ "$(sudo dmidecode -s bios-vendor)" = 'Google' ]; then
        MYIP=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
    elif [ "$(dmidecode -s system-manufacturer)" = 'Microsoft Corporation' ];then
        MYIP=$(curl -s http://checkip.amazonaws.com || printf "0.0.0.0")
    elif [ "$(dmidecode -s system-product-name | cut -c 1-7)" = 'Alibaba' ]; then
        MYIP=$(curl -s http://100.100.100.200/latest/meta-data/eipv4)
    else
        MYIP=$(ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n')
    fi
}

line_change(){
    LINENUM=$(grep -v '#' ${2} | grep -n "${1}" | cut -d: -f 1)
    if [ -n "$LINENUM" ] && [ "$LINENUM" -eq "$LINENUM" ] 2>/dev/null; then
        sed -i "${LINENUM}d" ${2}
        sed -i "${LINENUM}i${3}" ${2}
    fi
}

cked()
{
    if [ -f /bin/ed ]; then
        echoG "ed exist"
    else
        echoG "no ed, ready to install"
        if [ "${OSNAME}" = 'ubuntu' ] || [ "${OSNAME}" = 'debian' ]; then
            apt-get install ed -y > /dev/null 2>&1
        elif [ "${OSNAME}" = 'centos' ]; then
            yum install ed -y > /dev/null 2>&1
        fi
    fi
}

check_os()
{
    OSTYPE=$(uname -m)
    MARIADBCPUARCH=
    if [ -f /etc/redhat-release ] ; then
        OSVER=$(cat /etc/redhat-release | awk '{print substr($4,1,1)}')
        if [ ${?} = 0 ] ; then
            OSNAMEVER=CENTOS${OSVER}
            OSNAME=centos
            rpm -ivh http://rpms.litespeedtech.com/centos/litespeed-repo-1.1-1.el${OSVER}.noarch.rpm >/dev/null 2>&1
        fi
    elif [ -f /etc/lsb-release ] ; then
        OSNAME=ubuntu
        wget -qO - http://rpms.litespeedtech.com/debian/enable_lst_debain_repo.sh | bash >/dev/null 2>&1
        UBUNTU_V=$(grep 'DISTRIB_RELEASE' /etc/lsb-release | awk -F '=' '{print substr($2,1,2)}')
        if [ ${UBUNTU_V} = 14 ] ; then
            OSNAMEVER=UBUNTU14
            OSVER=trusty
            MARIADBCPUARCH="arch=amd64,i386,ppc64el"
        elif [ ${UBUNTU_V} = 16 ] ; then
            OSNAMEVER=UBUNTU16
            OSVER=xenial
            MARIADBCPUARCH="arch=amd64,i386,ppc64el"
        elif [ ${UBUNTU_V} = 18 ] ; then
            OSNAMEVER=UBUNTU18
            OSVER=bionic
            MARIADBCPUARCH="arch=amd64"
        fi
    elif [ -f /etc/debian_version ] ; then
        OSNAME=debian
        wget -O - http://rpms.litespeedtech.com/debian/enable_lst_debain_repo.sh | bash
        DEBIAN_V=$(awk -F '.' '{print $1}' /etc/debian_version)
        if [ ${DEBIAN_V} = 7 ] ; then
            OSNAMEVER=DEBIAN7
            OSVER=wheezy
            MARIADBCPUARCH="arch=amd64,i386"
        elif [ ${DEBIAN_V} = 8 ] ; then
            OSNAMEVER=DEBIAN8
            OSVER=jessie
            MARIADBCPUARCH="arch=amd64,i386"
        elif [ ${DEBIAN_V} = 9 ] ; then
            OSNAMEVER=DEBIAN9
            OSVER=stretch
            MARIADBCPUARCH="arch=amd64,i386"
        elif [ ${DEBIAN_V} = 10 ] ; then
            OSNAMEVER=DEBIAN10
            OSVER=buster
        fi
    fi
    if [ "${OSNAMEVER}" = "" ] ; then
        echoR "Sorry, currently one click installation only supports Centos(6-8), Debian(7-10) and Ubuntu(14,16,18)."
        echoR "You can download the source code and build from it."
        exit 1
    else
        if [ "${OSNAME}" = "centos" ] ; then
            echoG "Current platform is ${OSNAME} ${OSVER}"
        else
            export DEBIAN_FRONTEND=noninteractive
            echoG "Current platform is ${OSNAMEVER} ${OSNAME} ${OSVER}."
        fi
    fi
}

path_update(){
    if [ "${OSNAME}" = "centos" ] ; then
        USER='nobody'
        GROUP='nobody'
        REPOPATH='/etc/yum.repos.d'
        PHPINICONF="${LSDIR}/lsphp${PHPVER}/etc/php.ini"
        REDISSERVICE='/lib/systemd/system/redis.service'
        REDISCONF='/etc/redis.conf'
        MEMCACHESERVICE='/etc/systemd/system/memcached.service'
        MEMCACHECONF='/etc/sysconfig/memcached'
        BANNERDST='/etc/profile.d/99-one-click.sh'
    elif [ "${OSNAME}" = 'ubuntu' ] || [ "${OSNAME}" = 'debian' ]; then
        USER='www-data'
        GROUP='www-data'
        REPOPATH='/etc/apt/sources.list.d'
        PHPINICONF="${LSDIR}/lsphp${PHPVER}/etc/php/${PHP_M}.${PHP_S}/litespeed/php.ini"
        REDISSERVICE='/lib/systemd/system/redis-server.service'
        REDISCONF='/etc/redis/redis.conf'
        MEMCACHECONF='/etc/memcached.conf'
        BANNERDST='/etc/update-motd.d/99-one-click'
    fi
}

provider_ck()
{
    if [ -e /sys/devices/virtual/dmi/id/product_uuid ] && [ "$(sudo cat /sys/devices/virtual/dmi/id/product_uuid | cut -c 1-3)" = 'EC2' ]; then
        PROVIDER='aws'
    elif [ "$(dmidecode -s bios-vendor)" = 'Google' ];then
        PROVIDER='google'
    elif [ "$(dmidecode -s bios-vendor)" = 'DigitalOcean' ];then
        PROVIDER='do'
    elif [ "$(dmidecode -s system-product-name | cut -c 1-7)" = 'Alibaba' ];then
        PROVIDER='aliyun'
    elif [ "$(dmidecode -s system-manufacturer)" = 'Microsoft Corporation' ];then
        PROVIDER='azure'
    else
        PROVIDER='undefined'
    fi
}

os_hm_path()
{
    if [ ${PROVIDER} = 'aws' ] && [ -d /home/ubuntu ]; then
        HMPATH='/home/ubuntu'
    elif [ ${PROVIDER} = 'google' ] && [ -d /home/ubuntu ]; then
        HMPATH='/home/ubuntu'
    elif [ ${PROVIDER} = 'aliyun' ] && [ -d /home/ubuntu ]; then
        HMPATH='/home/ubuntu'
    else
        HMPATH='/root'
    fi
    ADMIN_PASS_PATH="${HMPATH}/.litespeed_password"
    DB_PASS_PATH="${HMPATH}/.db_password"
}

KILL_PROCESS(){
    PROC_NUM=$(pidof ${1})
    if [ ${?} = 0 ]; then
        kill -9 ${PROC_NUM}
    fi
}

ubuntu_sysupdate(){
    echoG 'System update'
    silent apt-get update
    silent DEBIAN_FRONTEND=noninteractive apt-get -y \
    -o Dpkg::Options::='--force-confdef' \
    -o Dpkg::Options::='--force-confold' upgrade
    silent DEBIAN_FRONTEND=noninteractive apt-get -y \
    -o Dpkg::Options::='--force-confdef' \
    -o Dpkg::Options::='--force-confold' dist-upgrade
}

centos_sysupdate(){
    echoG 'System update'
    silent yum update -y
    setenforce 0
}

remove_file(){
    if [ -e ${1} ]; then
        rm -rf ${1}
    fi
}

backup_old(){
    if [ -f ${1} ] && [ ! -f ${1}_old ]; then
       mv ${1} ${1}_old
    fi
}

linechange(){
    LINENUM=$(grep -n "${1}" ${2} | cut -d: -f 1)
    if [ -n "$LINENUM" ] && [ "$LINENUM" -eq "$LINENUM" ] 2>/dev/null; then
        sed -i "${LINENUM}d" ${2}
        sed -i "${LINENUM}i${3}" ${2}
    fi

}
gen_password(){
    if [ ! -f ${ADMIN_PASS_PATH} ]; then
        ADMIN_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 ; echo '')
    else
        ADMIN_PASS=$(grep admin_pass ${ADMIN_PASS_PATH} | awk -F'"' '{print $2}')
    fi
    if [ ! -f ${DB_PASS_PATH} ]; then
        MYSQL_ROOT_PASS=$(openssl rand -hex 24)
        MYSQL_USER_PASS=$(openssl rand -hex 24)
    else
        MYSQL_ROOT_PASS=$(grep root_mysql_pass ${DB_PASS_PATH} | awk -F'=' '{print $2}')
        MYSQL_USER_PASS=$(grep wordpress_mysql_pass ${DB_PASS_PATH} | awk -F'=' '{print $2}')
    fi
}

gen_salt(){
    GEN_SALT=$(</dev/urandom tr -dc 'a-zA-Z0-9!@#%^&*()-_[]{}<>~+=' | head -c 64 | sed -e 's/[\/&]/\&/g')
}

gen_pass_file(){
    if [ -f "${ADMIN_PASS_PATH}" ]; then
        rm -f ${ADMIN_PASS_PATH}
    fi
    if [ -f "${DB_PASS_PATH}" ]; then
        rm -f ${DB_PASS_PATH}
    fi
    echoG 'Generate .litespeed_password file'
    touch ${ADMIN_PASS_PATH}
    echoG 'Generate .db_password file'
    touch ${DB_PASS_PATH}
}

update_pass_file(){
    cat >> ${ADMIN_PASS_PATH} <<EOM
admin_pass="${ADMIN_PASS}"
EOM

    cat >> ${DB_PASS_PATH} <<EOM
root_mysql_pass="${MYSQL_ROOT_PASS}"
wordpress_mysql_pass="${MYSQL_USER_PASS}"
EOM
}

rm_old_pkg(){
    silent systemctl stop ${1}
    if [ ${OSNAME} = 'centos' ]; then
        silent yum remove ${1} -y
    else
        silent apt remove ${1} -y
    fi
    if [ $(systemctl is-active ${1}) != 'active' ]; then
        echoG "[OK] remove ${1}"
    else
        echoR "[Failed] remove ${1}"
    fi
}

restart_lsws(){
    echoG 'Restart LiteSpeed Web Server'
    ${LSDIR}/bin/lswsctrl restart >/dev/null 2>&1
}

ubuntu_pkg_basic(){
    echoG 'Install basic packages'
    silent apt-get install lsb-release -y
    silent apt-get install curl wget unzip -y
    silent apt-get install curl unzip software-properties-common -y
}

ubuntu_pkg_postfix(){
    if [ -e /usr/sbin/postfix ]; then
        echoG 'Postfix already installed'
    else
        echoG 'Installing postfix'
        DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' \
        -o Dpkg::Options::='--force-confold' install postfix >/dev/null 2>&1
        [[ -e /usr/sbin/postfix ]] && echoG 'Install postfix Success' || echoR 'Install postfix Failed'
    fi
}

ubuntu_pkg_memcached(){
    echoG 'Install Memcached'
    apt-get -y install memcached > /dev/null 2>&1
    if [ ${?} != 0 ]; then
        echoR 'Memcache install failed, please  check!'
        SKIP_MEMCA=1
    else    
        systemctl start memcached > /dev/null 2>&1
        systemctl enable memcached > /dev/null 2>&1
    fi    
}

ubuntu_pkg_redis(){
    echoG 'Install Redis'
    apt-get -y install redis > /dev/null 2>&1
    if [ ${?} != 0 ]; then
        echoR 'Redis install failed, please check!'
        SKIP_REDIS=1
    else    
        systemctl start redis > /dev/null 2>&1
    fi
}

pkg_phpmyadmin(){
    if [ ! -f ${PHPMYFD}/changelog.php ]; then
        cd ${CMDFD}/
        echoG 'Install phpmyadmin'
        wget -q --no-check-certificate https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip
        unzip phpMyAdmin-latest-all-languages.zip > /dev/null 2>&1
        rm -f phpMyAdmin-latest-all-languages.zip
        mv phpMyAdmin-*-all-languages ${PHPMYFD}
        mv ${PHPMYFD}/config.sample.inc.php ${PHPMYCONF}
    else
        echoY "phpMyAdmin exist, skip!"
    fi
}

ubuntu_pkg_phpmyadmin(){
    pkg_phpmyadmin
}

ubuntu_pkg_ufw(){
    if [ ! -f /usr/sbin/ufw ]; then
        echoG 'Install ufw'
        apt-get install ufw -y > /dev/null 2>&1
    fi    
}

ubuntu_pkg_certbot(){
    echoG "Install CertBot"
    add-apt-repository universe > /dev/null 2>&1
    echo -ne '\n' | add-apt-repository ppa:certbot/certbot > /dev/null 2>&1
    apt-get update > /dev/null 2>&1
    apt-get -y install certbot > /dev/null 2>&1
    if [ -e /usr/bin/certbot ] || [ -e /usr/local/bin/certbot ]; then
        echoG 'Install CertBot finished'
    else
        echoR 'Please check CertBot'
    fi
}

ubuntu_pkg_system(){
    if [ -e /usr/sbin/dmidecode ]; then
        echoG 'dmidecode already installed'
    else
        echoG 'Install dmidecode'
        silent apt-get install dmidecode -y
        [[ -e /usr/sbin/dmidecode ]] && echoG 'Install dmidecode Success' || echoR 'Install dmidecode Failed'
    fi
}

ubuntu_pkg_mariadb(){
    apt list --installed 2>/dev/null | grep mariadb-server-${MARIAVER} >/dev/null 2>&1
    if [ ${?} = 0 ]; then
        echoG "Mariadb ${MARIAVER} already installed"
    else
        if [ -e /etc/mysql/mariadb.cnf ]; then
            echoY 'Remove old mariadb'
            rm_old_pkg mariadb-server
        fi
        echoG "Install Mariadb ${MARIAVER}"
        silent apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
        silent add-apt-repository "deb [arch=amd64,arm64,ppc64el] http://mirror.lstn.net/mariadb/repo/${MARIAVER}/ubuntu bionic main"
        if [ "$(grep "mariadb.*${MARIAVER}" /etc/apt/sources.list)" = '' ]; then
            echoR '[Failed] to add MariaDB repository'
        fi
        silent apt update
        DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' \
            -o Dpkg::Options::='--force-confold' install mariadb-server >/dev/null 2>&1
    fi
    systemctl start mariadb
    local DBSTATUS=$(systemctl is-active mariadb)
    if [ ${DBSTATUS} = active ]; then
        echoG "MARIADB is: ${DBSTATUS}"
    else
        echoR "[Failed] Mariadb is: ${DBSTATUS}"
    fi
}

centos_pkg_basic(){
    echoG 'Install basic packages'
    silent yum install epel-release -y
    silent yum update -y
    silent yum install curl yum-utils wget unzip -y
    if [[ -z "$(rpm -qa epel-release)" ]]; then
        silent yum install epel-release -y
    fi
    if [ ! -e /usr/bin/yum-config-manager ]; then
        silent yum install yum-utils -y
    fi
    if [ ! -e /usr/bin/curl ]; then
        silent yum install curl -y
    fi
}

centos_pkg_postfix(){
    if [ -e /usr/sbin/postfix ]; then
        echoG 'Postfix already installed'
    else
        echoG 'Installing postfix'
        yum install postfix -y >/dev/null 2>&1
        [[ -e /usr/sbin/postfix ]] && echoG 'Install postfix Success' || echoR 'Install postfix Failed'
    fi
}

centos_pkg_memcached(){
    echoG 'Install Memcached'
    yum -y install memcached > /dev/null 2>&1
    if [ ${?} != 0 ]; then
        echoR 'Memcache install failed, please  check!'
        SKIP_MEMCA=1
    else        
        systemctl start memcached > /dev/null 2>&1
        systemctl enable memcached > /dev/null 2>&1
    fi    
}

centos_pkg_redis(){
    echoG 'Install Redis'
    yum -y install redis > /dev/null 2>&1
    if [ ${?} != 0 ]; then
        echoR 'Redis install failed, please check!'
        SKIP_REDIS=1
    else    
        systemctl start redis > /dev/null 2>&1
    fi    
}

centos_pkg_phpmyadmin(){
    pkg_phpmyadmin
}

centos_pkg_certbot(){
    echoG "Install CertBot"
    if [ ${OSVER} = 8 ]; then
        wget -q https://dl.eff.org/certbot-auto
        mv certbot-auto /usr/local/bin/certbot
        chown root /usr/local/bin/certbot
        chmod 0755 /usr/local/bin/certbot
        echo "y" | /usr/local/bin/certbot > /dev/null 2>&1
    else
        yum -y install certbot  > /dev/null 2>&1
    fi
    if [ -e /usr/bin/certbot ] || [ -e /usr/local/bin/certbot ]; then
        echoG 'Install CertBot finished'
    else
        echoR 'Please check CertBot'
    fi
}

centos_pkg_system(){
    if [ -e /usr/sbin/dmidecode ]; then
        echoG 'dmidecode already installed'
    else
        echoG 'Install dmidecode'
        silent yum install dmidecode -y
        [[ -e /usr/sbin/dmidecode ]] && echoG 'Install dmidecode Success' || echoR 'Install dmidecode Failed'
    fi
}

centos_pkg_mariadb(){
    silent rpm -qa | grep mariadb-server-${MARIAVER}

    if [ ${?} = 0 ]; then
        echoG "Mariadb ${MARIAVER} already installed"
    else
        if [ -e /etc/mysql/mariadb.cnf ]; then
            echoY 'Remove old mariadb'
            rm_old_pkg mariadb-server
        fi

        echoG "InstallMariadb ${MARIAVER}"

        if [ "${OSTYPE}" != "x86_64" ] ; then
            CENTOSVER=centos${OSVER}-x86
        else
            CENTOSVER=centos${OSVER}-amd64
        fi

        cat > ${REPOPATH}/MariaDB.repo << EOM
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/${MARIAVER}/${CENTOSVER}
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOM
        if [ "${OSNAMEVER}" = "CENTOS8" ] ; then
            silent yum install -y boost-program-options
            silent yum --disablerepo=AppStream install -y MariaDB-server MariaDB-client
        else
            silent yum install MariaDB-server MariaDB-client -y
        fi
    fi
    systemctl start mariadb
    local DBSTATUS=$(systemctl is-active mariadb)
    if [ ${DBSTATUS} = active ]; then
        echoG "MARIADB is: ${DBSTATUS}"
    else
        echoR "[Failed] Mariadb is: ${DBSTATUS}"
        echoR "You may want to manually run the command 'yum -y install MariaDB-server MariaDB-client' to check. Aborting installation!"
        exit 1
    fi
}

set_mariadb_root(){
    SQLVER=$(mysql -u root -e 'status' | grep 'Server version')
    SQLVER_1=$(echo ${SQLVER} | awk '{print substr ($3,1,2)}')
    SQLVER_2=$(echo ${SQLVER} | awk -F '.' '{print $2}')
    if (( ${SQLVER_1} >=11 )); then
        mysql -u root -e "ALTER USER root@localhost IDENTIFIED VIA mysql_native_password USING PASSWORD('${MYSQL_ROOT_PASS}');"
    elif (( ${SQLVER_1} ==10 )) && (( ${SQLVER_2} >=4 && ${SQLVER_2}<=9 )); then
        mysql -u root -e "ALTER USER root@localhost IDENTIFIED VIA mysql_native_password USING PASSWORD('${MYSQL_ROOT_PASS}');"
    elif (( ${SQLVER_1} ==10 )) && (( ${SQLVER_2} ==3 )); then
        mysql -u root -e "UPDATE mysql.user SET authentication_string = '' WHERE user = 'root';"
        mysql -u root -e "UPDATE mysql.user SET plugin = '' WHERE user = 'root';"  
    elif (( ${SQLVER_1} == 10 )) && (( ${SQLVER_2} == 2 )); then
        mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${MYSQL_ROOT_PASS}');"
    else
        echo 'Please check DB version!'
        mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';"
    fi
}

install_lsws(){
    cd ${CMDFD}/
    if [ -e ${CMDFD}/lsws* ] || [ -d ${LSDIR} ]; then
        echoY 'Remove existing LSWS'
        silent systemctl stop lsws
        KILL_PROCESS litespeed
        rm -rf ${CMDFD}/lsws*
        rm -rf ${LSDIR}
    fi
    echoG 'Download LiteSpeed Web Server'
    wget -q --no-check-certificate https://www.litespeedtech.com/packages/5.0/lsws-5.4-ent-x86_64-linux.tar.gz -P ${CMDFD}/
    silent tar -zxvf lsws-*-ent-x86_64-linux.tar.gz
    rm -f lsws-*.tar.gz
    cd lsws-*
    wget -q --no-check-certificate http://license.litespeedtech.com/reseller/trial.key
    sed -i '/^license$/d' install.sh
    sed -i 's/read TMPS/TMPS=0/g' install.sh
    sed -i 's/read TMP_YN/TMP_YN=N/g' install.sh
    sed -i '/read [A-Z]/d' functions.sh
    sed -i 's/HTTP_PORT=$TMP_PORT/HTTP_PORT=443/g' functions.sh
    sed -i 's/ADMIN_PORT=$TMP_PORT/ADMIN_PORT=7080/g' functions.sh
    sed -i "/^license()/i\
    PASS_ONE=${ADMIN_PASS}\
    PASS_TWO=${ADMIN_PASS}\
    TMP_USER=${USER}\
    TMP_GROUP=${GROUP}\
    TMP_PORT=''\
    TMP_DEST=''\
    ADMIN_USER=''\
    ADMIN_EMAIL=''
    " functions.sh

    echoG 'Install LiteSpeed Web Server'
    silent /bin/bash install.sh
    echoG 'Upgrade to Latest stable release'
    silent ${LSDIR}/admin/misc/lsup.sh -f
    silent ${LSDIR}/bin/lswsctrl start
    SERVERV=$(cat /usr/local/lsws/VERSION)
    echoG "Version: lsws ${SERVERV}"
    rm -rf ${CMDFD}/lsws-*
    cd /
}

ubuntu_install_lsws(){
    install_lsws
}

centos_install_lsws(){
    install_lsws
}

ubuntu_reinstall(){
    apt --installed list 2>/dev/null | grep ${1} >/dev/null
    if [ ${?} = 0 ]; then
        OPTIONAL='--reinstall'
    else
        OPTIONAL=''
    fi
}

centos_reinstall(){
    rpm -qa | grep ${1} >/dev/null
    if [ ${?} = 0 ]; then
        OPTIONAL='reinstall'
    else
        OPTIONAL='install'
    fi
}

ubuntu_install_php(){
    echoG 'Install PHP & Packages for LSWS'
    ubuntu_reinstall "lsphp${PHPVER}"
    for PKG in '' -common -curl -gd -json -mysql -imagick -imap -memcached -msgpack -redis -mcrypt -opcache ; do
        /usr/bin/apt ${OPTIONAL} install -y lsphp${PHPVER}${PKG} >/dev/null 2>&1
    done
}

centos_install_php(){
    echoG 'Install PHP & Packages'
    for PKG in '' -common -gd -pdo -imap -mbstring -imagick -mysqlnd -memcached -mcrypt -process -opcache -redis -json -xml -xmlrpc; do
        /usr/bin/yum install lsphp${PHPVER}${PKG} -y >/dev/null 2>&1
    done

}

set_mariadb_user(){
    mysql -u root -p${MYSQL_ROOT_PASS} -e "DELETE FROM mysql.user WHERE User = '${WP_USER}';"
    mysql -u root -p${MYSQL_ROOT_PASS} -e "CREATE DATABASE IF NOT EXISTS ${WP_NAME};"
    if [ ${?} = 0 ]; then
        mysql -u root -p${MYSQL_ROOT_PASS} -e "grant all privileges on ${WP_NAME}.* to '${WP_USER}'@'localhost' identified by '${WP_PASS}';"
    else
        echoR "Failed to create database ${WP_NAME}. It may already exist. Skip WordPress setup!"
        SKIP_WP=1
    fi
}

install_WP_CLI(){
    if [ -e ${WP_CLI} ]; then
        echoG 'WP CLI already exist'
    else
        curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        silent ${PHP_BIN} wp-cli.phar --info --allow-root
        if [ ${?} != 0 ]; then
            echoR 'Issue with wp-cli.phar, Please check PHP!'
        else
            mv wp-cli.phar ${WP_CLI}
        fi
    fi
}

install_wordpress(){
    if [ -e ${WPCFPATH} ]; then
        echoY 'WordPress already exist, skip WordPress setup !'
    else
        install_WP_CLI
        silent mysql -u root -e 'status'
        if [ ${?} = 0 ]; then
            set_mariadb_root
            WP_NAME='wordpress'
            WP_USER='wordpress'
            WP_PASS="${MYSQL_USER_PASS}"
            echoG 'Install WordPress...'
            cd ${DOCROOT}
            set_mariadb_user
            if [ ${SKIP_WP} = 0 ]; then
                wget -q --no-check-certificate https://wordpress.org/latest.zip
                unzip -q latest.zip
                mv wordpress/* ${DOCROOT}
                rm -rf latest.zip wordpress
            fi
        fi
    fi
}

gen_selfsigned_cert(){
    echoG 'Generate Cert'
    KEYNAME="${LSDIR}/conf/example.key"
    CERTNAME="${LSDIR}/conf/example.crt"
    ### ECDSA 256bit
    openssl ecparam  -genkey -name prime256v1 -out ${KEYNAME}
    silent openssl req -x509 -nodes -days 365 -new -key ${KEYNAME} -out ${CERTNAME} <<csrconf
US
NJ
Virtual
LiteSpeedCommunity
Testing
webadmin
.
.
.
csrconf
}

config_htaccess(){
    echoG 'Setting WordPress'
    if [ ! -f ${DOCROOT}/.htaccess ]; then
        touch ${DOCROOT}/.htaccess
    fi
    cat << EOM > ${DOCROOT}/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOM
}

config_wp(){
    if [ -e "${DOCROOT}/wp-config-sample.php" ]; then
        sed -e "s/database_name_here/${WP_NAME}/" -e "s/username_here/wordpress/" -e "s/password_here/${MYSQL_USER_PASS}/" \
        "${DOCROOT}/wp-config-sample.php" > "${WPCFPATH}"
    else
        echoR 'WordPress setup skip, wp-config-sample.php does not exist!'
    fi

    echoG "Install ${PLUGIN}"
    wget -q -P ${DOCROOT}/wp-content/plugins/ https://downloads.wordpress.org/plugin/${PLUGIN}
    if [ ${?} = 0 ]; then
        unzip -qq -o ${DOCROOT}/wp-content/plugins/${PLUGIN} -d ${DOCROOT}/wp-content/plugins/
    else
        echoR "${PLUGINLIST} FAILED to download"
    fi
    rm -f ${DOCROOT}/wp-content/plugins/*.zip
}

config_lscache(){
    cd ${SCRIPTPATH}
    backup_old ${WPCONSTCONF}
    cp conf/const.default.ini ${DOCROOT}/wp-content/plugins/litespeed-cache/data/

    if [ ! -f ${DOCROOT}/wp-content/themes/${THEME}/functions.php.bk ]; then
        cp ${DOCROOT}/wp-content/themes/${THEME}/functions.php ${DOCROOT}/wp-content/themes/${THEME}/functions.php.bk
        cked
        ed ${DOCROOT}/wp-content/themes/${THEME}/functions.php << END >>/dev/null 2>&1
2i
require_once( WP_CONTENT_DIR.'/../wp-admin/includes/plugin.php' );
\$path = 'litespeed-cache/litespeed-cache.php' ;
if (!is_plugin_active( \$path )) {
    activate_plugin( \$path ) ;
    rename( __FILE__ . '.bk', __FILE__ );
}
.
w
q
END
    fi
}

check_spec(){
    CPU_NUM=$(nproc)
}

cpu_process(){
    check_spec
    if [[ ${CPU_NUM} > 1 ]]; then
        sed -i 's/<binding>1<\/binding>/<binding><\/binding>/g' ${LSCONF}
        sed -i 's/<reusePort>0<\/reusePort>/<reusePort>1<\/reusePort>/g' ${LSCONF}
    fi
}

change_owner(){
    echoG 'Change Owner'
    chown -R ${USER}:${GROUP} ${1}
}

setup_lsws(){
    echoG 'Setting LSWS Config'
    cd ${SCRIPTPATH}
    backup_old ${LSCONF}
    backup_old ${LSVCONF}
    cp conf/httpd_config.xml ${LSDIR}/conf/
    cp conf/vhconf.xml ${LSDIR}/DEFAULT/conf/    
     if [ "${OSNAME}" = 'centos' ]; then
        sed -i "s/www-data/${USER}/g" ${LSCONF}
        sed -i "s|/usr/local/lsws/lsphp${PHP_P}${PHP_S}/bin/lsphp|/usr/bin/lsphp|g" ${LSCONF}
    fi
    gen_selfsigned_cert
}

landing_pg(){
    echoG 'Setting Landing Page'
    curl -s https://raw.githubusercontent.com/litespeedtech/ls-cloud-image/master/Static/wp-landing.html \
    -o ${DOCLAND}/index.html
    if [ -e ${DOCLAND}/index.html ]; then
        echoG 'Landing Page finished'
    else
        echoR "Please check Landing Page here ${DOCLAND}/index.html"
    fi
}

config_php(){
    echoG 'Updating PHP Paremeter'
    NEWKEY='max_execution_time = 360'
    linechange 'max_execution_time' ${PHPINICONF} "${NEWKEY}"

    NEWKEY='post_max_size = 100M'
    linechange 'post_max_size' ${PHPINICONF} "${NEWKEY}"

    NEWKEY='upload_max_filesize = 100M'
    linechange 'upload_max_filesize' ${PHPINICONF} "${NEWKEY}"
    echoG 'Finish PHP Paremeter'
}

ubuntu_config_memcached(){
    if [ ${SKIP_MEMCA} = 0 ]; then
        echoG 'Setting Memcached'
        service memcached stop > /dev/null 2>&1
        cat >> "${MEMCACHECONF}" <<END
-s /var/www/memcached.sock
-a 0770
-p /tmp/memcached.pid
END
        NEWKEY="-u ${USER}"
        linechange '\-u memcache' ${MEMCACHECONF} "${NEWKEY}"
        systemctl daemon-reload > /dev/null 2>&1
        change_owner /var/run/memcached
        change_owner ${WWWFD}
        service memcached stop > /dev/null 2>&1
        service memcached start > /dev/null 2>&1
    else
        echo 'Skip Memcached config!'
    fi        
}

ubuntu_config_redis(){
    if [ ${SKIP_REDIS} = 0 ]; then
        echoG 'Setting Redis'
        service redis-server stop > /dev/null 2>&1
        NEWKEY="Group=${GROUP}"
        linechange 'Group=' ${REDISSERVICE} "${NEWKEY}"
        cat >> "${REDISCONF}" <<END
unixsocket /var/run/redis/redis-server.sock
unixsocketperm 775
END
        systemctl daemon-reload > /dev/null 2>&1
        service redis-server start > /dev/null 2>&1
    else
        echo 'Skip Redis config!'    
    fi    
}

centos_config_memcached(){
    if [ ${SKIP_MEMCA} = 0 ]; then
        echoG 'Setting memcached'
        service memcached stop > /dev/null 2>&1
        cat >> "${MEMCACHESERVICE}" <<END
[Unit]
Description=Memcached
Before=httpd.service
After=network.target
[Service]
User=${USER}
Group=${GROUP}
Type=simple
EnvironmentFile=-/etc/sysconfig/memcached
ExecStart=/usr/bin/memcached -u \$USER -p \$PORT -m \$CACHESIZE -c \$MAXCONN \$OPTIONS
[Install]
WantedBy=multi-user.target
END
        cat > "${MEMCACHECONF}" <<END
PORT="11211"
USER="${USER}"
MAXCONN="1024"
CACHESIZE="64"
OPTIONS="-s /var/www/memcached.sock -a 0770 -U 0 -l 127.0.0.1"
END
        ### SELINUX permissive Mode
        if [ ! -f /usr/sbin/semanage ]; then
            yum install -y policycoreutils-python-utils > /dev/null 2>&1
        fi
        semanage permissive -a memcached_t > /dev/null 2>&1
        setsebool -P httpd_can_network_memcache 1 > /dev/null 2>&1
        systemctl daemon-reload > /dev/null 2>&1

        change_owner ${WWWFD}
        service memcached start > /dev/null 2>&1
    else
        echo 'Skip Memcached setup!'
    fi        
}

centos_config_redis(){
    if [ ${SKIP_REDIS} = 0 ]; then
        service redis stop > /dev/null 2>&1
        NEWKEY="Group=${GROUP}"
        linechange 'Group=' ${REDISSERVICE} "${NEWKEY}"
        cat >> "${REDISCONF}" <<END
unixsocket /var/run/redis/redis-server.sock
unixsocketperm 775
END
        systemctl daemon-reload > /dev/null 2>&1
        service redis start > /dev/null 2>&1
    else
        echo 'Skip Redis config!'
    fi    
}

ubuntu_firewall_add(){
    echoG 'Setting Firewall'
    ufw status verbose | grep inactive > /dev/null 2>&1
    if [ $? = 0 ]; then
        for PORT in ${FIREWALLLIST}; do
            ufw allow ${PORT} > /dev/null 2>&1
        done
        echo "y" | ufw enable > /dev/null 2>&1
        ufw status | grep '80.*ALLOW' > /dev/null 2>&1
        if [ $? = 0 ]; then
            echoG 'firewalld rules setup success'
        else
            echoR 'Please check ufw rules'
        fi
    else
        echoG "ufw already enabled"
    fi
}

centos_firewall_add(){
    echoG 'Setting Firewall'
    if [ ! -e /usr/sbin/firewalld ]; then
        yum -y install firewalld > /dev/null 2>&1
    fi
    service firewalld start  > /dev/null 2>&1
    systemctl enable firewalld > /dev/null 2>&1
    for PORT in ${FIREWALLLIST}; do
        firewall-cmd --permanent --add-port=${PORT}/tcp > /dev/null 2>&1
    done
    firewall-cmd --reload > /dev/null 2>&1
    firewall-cmd --list-all | grep 80 > /dev/null 2>&1
    if [ $? = 0 ]; then
        echoG 'firewalld rules setup success'
    else
        echoR 'Please check firewalld rules'
    fi
}

add_profile(){
    echo "${1}" >> /etc/profile
}

setup_domain(){
    cd ${SCRIPTPATH}
    backup_old ${CMDFD}/domainsetup.sh
    cp tools/domainsetup.sh ${CMDFD}/
    chmod +x ${CMDFD}/domainsetup.sh
    add_profile "sudo ${CMDFD}/domainsetup.sh"
}

rm_dummy(){
    remove_file /etc/update-motd.d/00-header
    remove_file /etc/update-motd.d/10-help-text
    remove_file /etc/update-motd.d/50-landscape-sysinfo
    remove_file /etc/update-motd.d/50-motd-news
    remove_file /etc/update-motd.d/51-cloudguest
    backup_old /etc/legal
}

set_banner(){
    echoG 'Set Banner'
    rm_dummy
    if [ ! -e ${BANNERDST} ]; then
        curl -s https://raw.githubusercontent.com/litespeedtech/ls-cloud-image/master/Banner/${BANNERNAME} \
        -o ${BANNERDST}
        if [ ${?} != 0 ];  then
            curl -s https://cloud.litespeed.sh/Banner/${BANNERNAME} -o ${BANNERDST}
        fi
        chmod +x ${BANNERDST}
    fi
	setup_domain
    help_message 1
}

filepermission_update(){
    chmod 600 ${HMPATH}/.db_password
    chmod 600 ${HMPATH}/.litespeed_password
}

renew_wpsalt(){
    for KEY in "'AUTH_KEY'" "'SECURE_AUTH_KEY'" "'LOGGED_IN_KEY'" "'NONCE_KEY'" "'AUTH_SALT'" "'SECURE_AUTH_SALT'" "'LOGGED_IN_SALT'" "'NONCE_SALT'"
    do
        gen_salt
        LINENUM=$(grep -n "${KEY}" ${WPCFPATH} | cut -d: -f 1)
        sed -i "${LINENUM}d" ${WPCFPATH}
        NEWSALT="define(${KEY}, '${GEN_SALT}');"
        sed -i "${LINENUM}i${NEWSALT}" ${WPCFPATH}
    done
}

renew_blowfish(){
    gen_salt
    LINENUM=$(grep -n "'blowfish_secret'" ${PHPMYCONF} | cut -d: -f 1)
    sed -i "${LINENUM}d" ${PHPMYCONF}
    NEW_SALT="\$cfg['blowfish_secret'] = '${GEN_SALT}';"
    sed -i "${LINENUM}i${NEW_SALT}" ${PHPMYCONF}
}

config_wp_main(){
    config_htaccess
    config_wp
    config_lscache
}

more_secure(){
    echoG "Update key"
    filepermission_update
    renew_wpsalt
    renew_blowfish
}

init_check(){
    check_os
    path_update
    provider_ck
    os_hm_path
}

init_setup(){
    gen_password
    gen_pass_file
    update_pass_file
    create_doc_fd
}

ubuntu_pkg_main(){
    ubuntu_pkg_basic
    ubuntu_pkg_postfix
    ubuntu_pkg_memcached
    ubuntu_pkg_redis
    ubuntu_pkg_ufw
    ubuntu_pkg_phpmyadmin
    ubuntu_pkg_certbot
    ubuntu_pkg_system
    ubuntu_pkg_mariadb
}

ubuntu_main_install(){
    ubuntu_sysupdate
    ubuntu_pkg_main
    ubuntu_install_lsws
    ubuntu_install_php
    ubuntu_firewall_add
}

ubuntu_main_config(){
    setup_lsws
    cpu_process
    install_wordpress
    config_wp_main
    config_php
    ubuntu_config_memcached
    ubuntu_config_redis
    restart_lsws
    change_owner ${DOCROOT}
}

centos_pkg_main(){
    centos_pkg_basic
    centos_pkg_postfix
    centos_pkg_memcached
    centos_pkg_redis
    centos_pkg_phpmyadmin
    centos_pkg_certbot
    centos_pkg_system
    centos_pkg_mariadb
}

centos_main_install(){
    centos_sysupdate
    centos_pkg_main
    centos_install_lsws
    centos_install_php
    centos_firewall_add
}

centos_main_config(){
    setup_lsws
    cpu_process
    install_wordpress
    config_wp_main
    config_php
    centos_config_memcached
    centos_config_redis
    restart_lsws
    change_owner ${DOCROOT}
}

main(){
    init_check
    init_setup
    if [ ${OSNAME} = 'centos' ]; then
        centos_main_install
        centos_main_config
    else
        ubuntu_main_install
        ubuntu_main_config
    fi
    more_secure
    set_banner
}
main
