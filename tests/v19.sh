#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
response=/tmp/tkl-tomcat-apache-response.$$
headers=/tmp/tkl-tomcat-apache-headers.$$
apache_modules=/tmp/tkl-tomcat-apache-modules.$$
policy=/tmp/tkl-tomcat-apache-policy.$$
probe=/var/lib/tomcat10/webapps/cp/tkl-v19-probe.jsp
database=tkl_tomcat_apache_v19_acceptance
database_created=false

cleanup() {
    rm -f -- "$response" "$headers" "$apache_modules" "$policy" "$probe"
    if $database_created; then
        mariadb --execute "DROP DATABASE IF EXISTS $database" || true
    fi
}
trap cleanup EXIT

systemctl --quiet is-active apache2.service tomcat10.service mariadb.service \
    multi-user.target
systemctl --quiet is-enabled apache2.service tomcat10.service mariadb.service
test "$(systemctl show --property=User --value tomcat10.service)" = tomcat
apache2ctl configtest
apache2ctl -M >"$apache_modules"
grep -Fq ' jk_module ' "$apache_modules"
test -L /etc/apache2/sites-enabled/jktomcat.conf
test ! -e /etc/apache2/sites-enabled/000-default.conf

tomcat_package=$(dpkg-query -W -f='${Version}' tomcat10)
tomcat_admin_package=$(dpkg-query -W -f='${Version}' tomcat10-admin)
apache_package=$(dpkg-query -W -f='${Version}' apache2)
jk_package=$(dpkg-query -W -f='${Version}' libapache2-mod-jk)
java_package=$(dpkg-query -W -f='${Version}' openjdk-21-jre-headless)
mariadb_package=$(dpkg-query -W -f='${Version}' mariadb-server)
java_version=$(java -version 2>&1 | head -n 1)
tomcat_version=$(/usr/share/tomcat10/bin/version.sh 2>&1 | \
    awk -F': ' '/Server number/ {print $2}')

grep -q '^10\.1\.' <<<"$tomcat_version"
grep -q 'version "21\.' <<<"$java_version"
java_binary=$(readlink -f "$(command -v java)")
dpkg-query -S /usr/share/tomcat10/bin/catalina.sh "$java_binary" \
    /usr/lib/apache2/modules/mod_jk.so >/dev/null
dpkg-query -W turnkey-tomcat-apache-19.0 webmin-apache webmin-mysql \
    >/dev/null

test -d /var/lib/tomcat10/webapps/cp
test ! -d /var/lib/tomcat10/webapps/ROOT
test -d /var/lib/tomcat10/webapps/manager
test -d /var/lib/tomcat10/webapps/host-manager
test -d /var/lib/tomcat10/webapps/docs
grep -q 'CATALINA_HOME="/usr/share/tomcat10"' /etc/environment
grep -q 'JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"' /etc/environment
grep -q '^JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64' \
    /etc/default/tomcat10

python3 - /etc/tomcat10/server.xml <<'PYTHON'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
connectors = root.findall("./Service/Connector")
assert len(connectors) == 1
connector = connectors[0]
assert connector.get("protocol") == "AJP/1.3"
assert connector.get("address") == "127.0.0.1"
assert connector.get("port") == "8009"
assert connector.get("secretRequired") == "false"
PYTHON

listeners=$(ss -ltnH)
grep -Eq '127\.0\.0\.1:8009[[:space:]]' <<<"$listeners"
! grep -Eq ':8080[[:space:]]' <<<"$listeners"
grep -Fq 'worker.ajp13_worker.host=127.0.0.1' \
    /etc/libapache2-mod-jk/workers.properties
grep -Fq 'worker.ajp13_worker.port=8009' \
    /etc/libapache2-mod-jk/workers.properties
grep -Fq 'Include         /etc/tomcat10/mod_jk.conf' \
    /etc/apache2/sites-available/jktomcat.conf
grep -Fq 'JkMount /cp/*' /etc/tomcat10/mod_jk.conf
grep -Fq 'JkMount /manager/*' /etc/tomcat10/mod_jk.conf

curl --fail --silent --show-error http://127.0.0.1/ >"$response"
grep -Fq 'window.location = "/cp"' "$response"
curl --insecure --fail --silent --show-error --dump-header "$headers" \
    https://127.0.0.1/cp/ >"$response"
grep -qi '^Server: Apache' "$headers"
grep -q '<title>TurnKey Tomcat Apache</title>' "$response"
grep -q 'href="/manager/html"' "$response"
grep -q 'href="/host-manager/html"' "$response"

anonymous_status=$(curl --insecure --silent --output /dev/null \
    --write-out '%{http_code}' https://127.0.0.1/manager/html)
test "$anonymous_status" = 401
curl --insecure --fail --silent --show-error --user "admin:$password" \
    https://127.0.0.1/manager/html >"$response"
grep -q 'Tomcat Web Application Manager' "$response"
curl --insecure --fail --silent --show-error --user "admin:$password" \
    https://127.0.0.1/manager/text/serverinfo >"$response"
grep -q '^OK - Server version:' "$response"
curl --insecure --fail --silent --show-error --user "admin:$password" \
    https://127.0.0.1/manager/text/list >"$response"
grep -Eq '^/cp:running:' "$response"
grep -Eq '^/docs:running:' "$response"

python3 - /etc/tomcat10/tomcat-users.xml "$password" <<'PYTHON'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
admin = next(user for user in root.findall("user")
             if user.get("username") == "admin")
assert admin.get("password") == sys.argv[2]
roles = set(admin.get("roles", "").split(","))
assert {"admin-gui", "admin-script", "manager-gui", "manager-script"} <= roles
PYTHON

cat >"$probe" <<'EOF'
<%@ page contentType="text/plain" %>turnkey-tomcat-apache-v19-jsp-ok
EOF
chown tomcat:tomcat "$probe"
curl --retry 5 --retry-delay 1 --insecure --fail --silent --show-error \
    https://127.0.0.1/cp/tkl-v19-probe.jsp >"$response"
grep -Fxq 'turnkey-tomcat-apache-v19-jsp-ok' "$response"
rm -f -- "$probe"

curl --insecure --fail --silent --show-error --head \
    https://127.0.0.1:12321/ >/dev/null
mariadb --execute "CREATE DATABASE $database"
database_created=true
mariadb "$database" --execute \
    'CREATE TABLE probe (value VARCHAR(32)); INSERT INTO probe VALUES ("database-ok")'
mariadb --batch --skip-column-names "$database" \
    --execute 'SELECT value FROM probe' | grep -Fxq 'database-ok'
mariadb --execute "DROP DATABASE $database"
database_created=false

before="$tomcat_package|$tomcat_admin_package|$apache_package|$jk_package|$java_package|$mariadb_package"
apt-get update >/dev/null
for package in tomcat10 tomcat10-admin apache2 libapache2-mod-jk \
        openjdk-21-jre-headless mariadb-server webmin-apache webmin-mysql; do
    apt-cache policy "$package" >"$policy"
    candidate=$(awk '/Candidate:/ {print $2}' "$policy")
    test -n "$candidate"
    test "$candidate" != '(none)'
    grep -Eq 'trixie|deb13' "$policy"
done
after="$(dpkg-query -W -f='${Version}' tomcat10)|$(dpkg-query -W -f='${Version}' tomcat10-admin)|$(dpkg-query -W -f='${Version}' apache2)|$(dpkg-query -W -f='${Version}' libapache2-mod-jk)|$(dpkg-query -W -f='${Version}' openjdk-21-jre-headless)|$(dpkg-query -W -f='${Version}' mariadb-server)"
test "$after" = "$before"
grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
! grep -Rqi bookworm /etc/apt/sources.list.d

cat >"$result" <<EOF
package_source=Debian 13 Trixie APT repositories for Tomcat 10.1, Apache, mod_jk, OpenJDK 21 and MariaDB; TurnKey Trixie APT for Webmin
installed_version=tomcat10 $tomcat_package (Tomcat $tomcat_version); apache2 $apache_package; libapache2-mod-jk $jk_package; openjdk-21-jre-headless $java_package ($java_version); mariadb-server $mariadb_package
runtime_checks=normal init; Apache, Tomcat and MariaDB supervision; localhost-only AJP and disabled HTTP connector; Apache HTTPS to Tomcat control panel; anonymous manager denial; authenticated manager HTML and text API; deployed JSP execution through mod_jk; MariaDB roundtrip; Webmin endpoint
updater_command=apt-get update; apt-cache policy tomcat10 tomcat10-admin apache2 libapache2-mod-jk openjdk-21-jre-headless mariadb-server webmin-apache webmin-mysql
updater_result=signed metadata refreshed; eligible Trixie candidates found; installed versions unchanged
updater_channel=Debian Trixie and TurnKey Trixie APT repositories
integrity_evidence=APT accepted signed repository metadata through configured Deb822 sources and keyrings; no Bookworm source remained
EOF
