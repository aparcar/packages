# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=attendedsysupgrade
PKG_VERSION:=0.2
PKG_RELEASE:=2
PKG_LICENSE:=GPL-2.0
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/attendedsysupgrade
  SECTION:=utils
  CATEGORY:=Base system
  TITLE:=Attended Sysupgrade via command line
  MAINTAINER:=Paul Spooren <paul@spooren.de>
  DEPENDS:=+attendedsysupgrade-common
endef

define Package/attendedsysupgrade/description
	Attended firmware upgrade via command line.
	After a successfull installation the device will perform a restart.

	Usage:

	attendedsysupgrade

	UCI options:

	attendedsysupgrade.erver.url
	URL of compatible upgrade server [1]

	[1]: https://github.com/aparcar/gsoc17-attended-sysupgrade
endef

define Build/Compile
endef

define Build/Configure
endef

define Package/attendedsysupgrade/install

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/attendedsysupgrade.sh $(1)/usr/bin/attendedsysupgrade
endef

$(eval $(call BuildPackage,attendedsysupgrade))

