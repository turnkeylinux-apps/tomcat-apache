COMMON_OVERLAYS = tomcat tomcat-apache tomcat-welcome tkl-webcp apache
COMMON_CONF = postfix-local tomcat tkl-webcp apache-vhost

include $(FAB_PATH)/common/mk/turnkey/mysql.mk
include $(FAB_PATH)/common/mk/turnkey.mk
