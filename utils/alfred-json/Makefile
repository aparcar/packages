include $(TOPDIR)/rules.mk

PKG_NAME:=alfred-json
PKG_VERSION=v0.3.1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/ffnord/alfred-json
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=51b6b2682106e53254fe236890c0b4bb5db0a9ef
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz
PKG_MIRROR_HASH:=df5cd7d395c0e9c44e7cc5342e61f23bc4b5e43f77d53a22f8a1d760de1d145f

PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1
CMAKE_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/$(PKG_NAME)
 SECTION:=net
 CATEGORY:=Network
 TITLE:=$(PKG_NAME)
 MAINTAINER:=??
 DEPENDS:=+alfred +jansson +zlib
 PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
  Output Alfred data as JSON
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin/
	$(CP) $(PKG_BUILD_DIR)/src/alfred-json $(1)/usr/bin/alfred-json
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
