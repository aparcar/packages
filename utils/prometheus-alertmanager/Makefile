#
# Copyright (C) 2018 Jeffery To
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=prometheus-alertmanager
PKG_VERSION:=0.14.0
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/prometheus/alertmanager.git
PKG_SOURCE_VERSION:=30af4d051b37ce817ea7e35b56c57a0e2ec9dbb0

PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Paul Spooren <spooren@informatik.uni-leipzig.de>

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

GO_PKG:=github.com/prometheus/alertmanager/
GO_PKG_BUILD_PKG:=github.com/prometheus/alertmanager/cmd/alertmanager

include $(INCLUDE_DIR)/package.mk
include ../../lang/golang/golang-package.mk

define Package/prometheus-alertmanager/Default
  TITLE:=Alertmanager for Prometheus Montoring
  URL:=http://prometheus.io
  DEPENDS:=$(GO_ARCH_DEPENDS)
endef

define Package/prometheus-alertmanager
$(call Package/prometheus-alertmanager/Default)
  TITLE+= (source files)
  PKGARCH:=all
  SECTION:=utils
  CATEGORY:=Utilities
endef

define Package/prometheus-alertmanager/description
The Alertmanager handles alerts sent by client applications such as the
Prometheus server. It takes care of deduplicating, grouping, and routing them
to the correct receiver integrations such as email, PagerDuty, or OpsGenie. It
also takes care of silencing and inhibition of alerts.

https://github.com/prometheus/alertmanager
endef

define Package/prometheus-alertmanager/install
	$(call GoPackage/Package/Install/Bin,$(1))

	$(CP) ./files/* $(1)/
endef

$(eval $(call GoBinPackage,prometheus-alertmanager))
$(eval $(call BuildPackage,prometheus-alertmanager))
