include $(TOPDIR)/rules.mk

PKG_NAME:=scdoc
PKG_VERSION:=1.11.1
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://git.sr.ht/~sircmpwn/scdoc
PKG_SOURCE_VERSION:=$(PKG_VERSION)
PKG_MIRROR_HASH:=6a1531638b03f15fcb9973480204f15aeb40ff3429a110f1fe10a04d415d6cdb

PKG_MAINTAINER:=Daniel Golle <daniel@makrotopia.org>
PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=COPYING

PKG_INSTALL:=1
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/host-build.mk

define Package/scdoc
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=scdoc groff generator
  URL:=$(PKG_SOURCE_URL)
endef

HOST_MAKE_FLAGS += \
	PREFIX=$(STAGING_DIR_HOSTPKG) \
	SBINDIR=$(STAGING_DIR_HOSTPKG)/sbin \
	ETCDIR=$(STAGING_DIR_HOSTPKG)/etc

define Package/scdoc/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/scdoc $(1)/usr/bin/
endef

$(eval $(call BuildPackage,scdoc))
$(eval $(call HostBuild))
