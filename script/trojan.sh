#!/bin/bash

# Simple install Trojan-GFW

trojan_home="/etc/trojan"
caddy_home="/etc/caddy"
trojan_config="/etc/trojan/config.json"
caddy_config="/etc/caddy/Caddyfile"
trojan_ssl="$trojan_home/ssl"
caddy_ssl="/root/.caddy/acme/acme-v02.api.letsencrypt.org/sites"
service_dir="/etc/init.d"

install_dir=$( dirname "$(readlink -f -- "$0")" )
pushd $install_dir


install_caddy(){
        local download_link="https://github.com/jimmyrealfun/onekey/raw/master/caddy/caddy"
        local tls_config_url="https://raw.githubusercontent.com/jimmyrealfun/onekey/master/caddy/Caddyfile_tls"
        local http_config_url="https://raw.githubusercontent.com/jimmyrealfun/onekey/master/caddy/Caddyfile_80"
        local service_url="https://raw.githubusercontent.com/jimmyrealfun/onekey/master/caddy/caddy.init"
        echo "下载Caddy程序文件..."
        wget --no-check-certificate -cq -t3 -T60 -P /usr/local/bin/ "$download_link"
        chmod +x /usr/local/bin/caddy
        [ ! -d $caddy_home ] && mkdir -p $caddy_home
        echo "下载配置文件和系统服务文件..."
        wget --no-check-certificate -cq -t3 -T60 -P "$caddy_home" "$tls_config_url"
        wget --no-check-certificate -cq -t3 -T60 -P "$caddy_home" "$http_config_url"
        wget --no-check-certificate -cq -t3 -T60 -O "$service_dir/caddy" "$service_url"
        chmod +x $service_dir/caddy
}


ssl(){
        local domain=$1
        sed -i "s/DOMAIN/$domain/g" $caddy_home/Caddyfile_tls
        cp $caddy_home/Caddyfile_tls $caddy_config
        $service_dir/caddy start
        echo "证书申请中，稍等片刻..."
        sleep 15
        echo | openssl s_client -servername $domain -connect $domain:443 &> /dev/null
        [ $? -ne 0 ] && echo "证书申请失败，安装完成后需自行申请！"
        $service_dir/caddy stop
        cp $caddy_home/Caddyfile_80 $caddy_config
        echo "配置伪装网站..."
        wget --no-check-certificate -cq -t3 -T60 -O template_site.zip https://templated.co/hielo/download
        [ ! -d $caddy_home/wwwroot ] && mkdir -p $caddy_home/wwwroot && unzip -q template_site.zip -d $caddy_home/wwwroot
        rm -f template_site.zip
}


install_trojan(){
        local domain=$1
        local passwd=$2
        local version=`wget --no-check-certificate -qO- https://api.github.com/repos/trojan-gfw/trojan/releases/latest | grep tag_name | awk -F '"' '{print $(NF-1)}' | awk -F "v" '{print $NF}'`
        local download_link="https://github.com/trojan-gfw/trojan/releases/download/v${version}/trojan-${version}-linux-amd64.tar.xz"
        local tj_file="trojan.tar.xz"
        local config_url="https://raw.githubusercontent.com/jimmyrealfun/onekey/master/trojan/config.json"
        local service_url="https://raw.githubusercontent.com/jimmyrealfun/onekey/master/trojan/trojan.init"
        echo "下载Trojan程序文件..."
        wget --no-check-certificate -cq -t3 -T60 -O "$tj_file" "$download_link"
        [ $? -ne 0 ] && echo "Trojan-GFW下载失败！" && exit 1
        [ ! -d $trojan_home ] && mkdir -p $trojan_home
        tar -xJf $tj_file -C /usr/local/bin/ --strip-components 1 trojan/trojan
        chmod +x /usr/local/bin/trojan
        rm -f $tj_file
        echo "下载配置文件和系统服务文件..."
        wget --no-check-certificate -cq -t3 -T60 -P "$trojan_home" "$config_url"
        sed -i -e "s/DOMAIN/$domain/g" -e "s/PASSWD/$passwd/g" $trojan_config
        wget --no-check-certificate -cq -t3 -T60 -O "$service_dir/trojan" "$service_url"
        chmod +x $service_dir/trojan
        [ ! -d $trojan_ssl ] && mkdir -p $trojan_ssl
        ln -s $caddy_ssl/$domain/$domain.key $trojan_ssl/
        ln -s $caddy_ssl/$domain/$domain.crt $trojan_ssl/
}


uninstall_all(){
        ps -ef | grep /usr/local/bin/caddy | grep -v grep | awk -F " " '{print $2}' | xargs kill -9
        ps -ef | grep /usr/local/bin/trojan | grep -v grep | awk -F " " '{print $2}' | xargs kill -9
        rm -f /usr/local/bin/caddy /usr/local/bin/trojan $service_dir/caddy $service_dir/trojan
        rm -rf /etc/caddy /etc/trojan
}

read -p "输入域名：" domain_name
read -p "Trojan密码：" trojan_pwd
resolv_ip=`dig +short $domain_name`
host_ip=`curl -s ifconfig.me`
[ "$resolv_ip" != "$host_ip" ] && echo "域名解析错误！" && exit 1
echo "检查执行卸载..."
uninstall_all
echo "安装Caddy..."
install_caddy
echo "申请证书..."
ssl $domain_name
echo "安装Trojan..."
install_trojan $domain_name $trojan_pwd


ps -ef | grep /usr/local/bin/caddy | grep -v grep | awk -F " " '{print $2}' | xargs kill -9
$service_dir/caddy start
ps -ef | grep /usr/local/bin/trojan | grep -v grep | awk -F " " '{print $2}' | xargs kill -9
$service_dir/trojan start
ps -ef | grep -v grep | grep -q -E /usr/local/bin/caddy
[ $? -ne 0 ] && echo "Caddy启动失败！"
ps -ef | grep -v grep | grep -q -E /usr/local/bin/trojan
if [ $? -ne 0 ];then
        echo "Trojan-GFW启动失败！"
else
        clear
        echo "Trojan地址：$domain_name"
        echo "Trojan端口：443"
        echo "Trojan密码：$trojan_pwd"
fi

popd
