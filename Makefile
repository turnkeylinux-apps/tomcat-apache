COMMON_OVERLAYS = tomcat tomcat-apache tomcat-welcome tkl-webcp
COMMON_CONF = tomcat tkl-webcp

include $(FAB_PATH)/common/mk/turnkey/mysql.mk
include $(FAB_PATH)/common/mk/turnkey/apache.mk
include $(FAB_PATH)/common/mk/turnkey.mk
