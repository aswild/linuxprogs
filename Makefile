# Makefile for linuxprogs
#
# Allen Wild, 2016

ifeq ($(PREFIX),)
	PREFIX := $(HOME)
endif

# help target is first
help:
	@echo "TODO: HELP TEXT HERE"

#####################################
# LIBS SETUP
#####################################
LIBS :=

LIBS += ncurses
BUILD_CHECK-ncurses   = ncurses/lib/libncursesw.a
INSTALL_CHECK-ncurses = $(PREFIX)/lib/libncursesw.a
$(BUILD_CHECK-ncurses):
	cd ncurses && ./configure --prefix=$(PREFIX) --enable-widec --with-shared CFLAGS=-fPIC
	make -C ncurses

LIBS += libevent
BUILD_CHECK-libevent   = libevent/.libs/libevent.so
INSTALL_CHECK-libevent = $(PREFIX)/lib/libevent.so
$(BUILD_CHECK-libevent):
	cd libevent && ./autogen.sh && ./configure --prefix=$(PREFIX)
	make -C libevent

#####################################
# APPS SETUP
#####################################
APPS :=

APPS += htop
BUILD_CHECK-htop   = htop/htop
INSTALL_CHECK-htop = $(PREFIX)/bin/htop
$(BUILD_CHECK-htop): $(INSTALL_CHECK-ncurses)
	cd htop && \
		./autogen.sh && \
		./configure --prefix=$(PREFIX) CFLAGS="-I$(PREFIX)/include" LDFLAGS="-L$(PREFIX)/lib"
	make -C htop

APPS += tmux
BUILD_CHECK-tmux   = tmux/tmux
INSTALL_CHECK-tmux = $(PREFIX)/bin/tmux
$(BUILD_CHECK-tmux): $(INSTALL_CHECK-libevent) $(INSTALL_CHECK-ncurses)
	cd tmux && \
		./autogen.sh && \
		./configure --prefix=$(PREFIX) CFLAGS="-I$(PREFIX)/include -I$(PREFIX)/include/ncursesw" \
			LDFLAGS="-L$(PREFIX)/lib" LIBS="-lncursesw"
	make -C tmux

# Annoyingly, zsh depends on yodl and icmake, which we will build in a separate directory
ZSH_DEPS_DIR := $(CURDIR)/zsh-deps
export PATH  := $(PATH):$(ZSH_DEPS_DIR)/usr/bin
ICMAKE_DIR   := $(CURDIR)/icmake/icmake
BUILD_CHECK-icmake   := $(ICMAKE_DIR)/tmp/$(ZSH_DEPS_DIR)/usr/bin/icmake
INSTALL_CHECK-icmake := $(ZSH_DEPS_DIR)/usr/bin/icmake

$(BUILD_CHECK-icmake):
	cd $(ICMAKE_DIR) && ./icm_prepare $(ZSH_DEPS_DIR)
	cd $(ICMAKE_DIR) && ./icm_bootstrap x
$(INSTALL_CHECK-icmake): $(BUILD_CHECK-icmake)
	cd $(ICMAKE_DIR) && ./icm_install all /
icmake-build: $(BUILD_CHECK-icmake)
icmake-install: $(INSTALL_CHECK-icmake)
.PHONY: icmake-build icmake-install

BUILD_CHECK-yodl   := yodl/yodl/tmp/install/usr/bin/yodl
INSTALL_CHECK-yodl := $(ZSH_DEPS_DIR)/usr/bin/yodl
YODL_DIR := $(CURDIR)/yodl/yodl
ICMAKE := $(INSTALL_CHECK-icmake) -qt/tmp/yodl build

$(BUILD_CHECK-yodl): $(INSTALL_CHECK-icmake)
	cd $(YODL_DIR) && $(ICMAKE) programs
	cd $(YODL_DIR) && $(ICMAKE) macros
$(INSTALL_CHECK-yodl): $(BUILD_CHECK-yodl)
	cd $(YODL_DIR) && $(ICMAKE) install programs $(ZSH_DEPS_DIR)
	cd $(YODL_DIR) && $(ICMAKE) install macros $(ZSH_DEPS_DIR)
yodl-build: $(BUILD_CHECK-yodl)
yodl-install: $(INSTALL_CHECK-yodl)
.PHONY: yodl-build yodl-install

zshdeps-uninstall:
	rm -rf $(ZSH_DEPS_DIR)
zshdeps-clean:
	cd $(ICMAKE_DIR) && git reset --hard
	cd $(ICMAKE_DIR) && git clean -dxf
	cd $(YODL_DIR) && git reset --hard
	cd $(YODL_DIR) && git clean -dxf
.PHONY: zshdeps-uninstall zshdeps-clean
uninstall_targets_all += zshdeps-uninstall
clean_targets_all     += zshdeps-clean

# finally, define the actual zsh target
APPS += zsh
BUILD_CHECK-zsh   = zsh/Src/zsh
INSTALL_CHECK-zsh = $(PREFIX)/bin/zsh
$(BUILD_CHECK-zsh): $(INSTALL_CHECK-ncurses) $(INSTALL_CHECK-yodl)
	cd zsh && \
		Util/preconfig && \
		./configure --prefix=$(PREFIX) CFLAGS="-I$(PREFIX)/include" LDFLAGS="-L$(PREFIX)/lib"
	make -C zsh

#####################################
# AUTOMAGIC STUFF
#####################################
all: install
.PHONY: help all

define PROG_TARGET_TEMPLATE = 
$$(INSTALL_CHECK-$(1)): $$(BUILD_CHECK-$(1))
	make -C $(1) install
$(1)-uninstall:
	-make -C $(1) uninstall
$(1)-clean:
	cd $(1) && git reset --hard
	cd $(1) && git clean -dxf
.PHONY: $(1) $(1)-build $(1)-install $(1)-uninstall $(1)-clean
$(1): $(1)-build
$(1)-build: $$(BUILD_CHECK-$(1))
$(1)-install: $$(INSTALL_CHECK-$(1))
build_targets_$(2)   += $(1)-build
install_targets_$(2) += $(1)-install
uninstall_targets_$(2) += $(1)-uninstall
clean_targets_$(2) += $(1)-clean
endef

define PHONY_TARGETS_TEMPLATE_1 = 
$(2)-$(1): $($(1)_targets_$(2))
.PHONY: $(2)-$(1)
$(1)_targets_all += $(2)-$(1)
endef

define PHONY_TARGETS_TEMPLATE_2 =
all-$(1): $($(1)_targets_all)
endef

$(foreach prog,$(LIBS),$(eval $(call PROG_TARGET_TEMPLATE,$(prog),libs)))
$(foreach prog,$(APPS),$(eval $(call PROG_TARGET_TEMPLATE,$(prog),apps)))

$(foreach action,build install uninstall clean,$(eval $(call PHONY_TARGETS_TEMPLATE_1,$(action),libs)))
$(foreach action,build install uninstall clean,$(eval $(call PHONY_TARGETS_TEMPLATE_1,$(action),apps)))
$(foreach action,build install uninstall clean,$(eval $(call PHONY_TARGETS_TEMPLATE_2,$(action))))
