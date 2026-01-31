#
# Copyright (C) 2024 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=ucode-mod-yaml
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-or-later
PKG_MAINTAINER:=OpenWrt Community

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/ucode-mod-yaml
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=ucode
  TITLE:=YAML module for ucode
  DEPENDS:=+libucode +libyaml
endef

define Package/ucode-mod-yaml/description
  The YAML module provides parsing and serialization functions for YAML data
  in the ucode scripting language. It uses libyaml for YAML 1.1 support.

  Functions provided:
    yaml.parse(str) - Parse YAML string to ucode value
    yaml.stringify(val) - Convert ucode value to YAML string
    yaml.error() - Get last error message
endef

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Package/ucode-mod-yaml/install
	$(INSTALL_DIR) $(1)/usr/lib/ucode
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/lib/ucode/yaml.so $(1)/usr/lib/ucode/
endef

$(eval $(call BuildPackage,ucode-mod-yaml))
