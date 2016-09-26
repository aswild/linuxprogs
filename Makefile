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
	cd ncurses && ./configure --prefix=$(PREFIX) --enable-widec CFLAGS="-fPIC"
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

APPS += zsh
BUILD_CHECK-zsh   = zsh/Src/zsh
INSTALL_CHECK-zsh = $(PREFIX)/bin/zsh
$(BUILD_CHECK-zsh): $(INSTALL_CHECK-ncurses)
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
all-$(1): libs-$(1) apps-$(1)
endef

$(foreach prog,$(LIBS),$(eval $(call PROG_TARGET_TEMPLATE,$(prog),libs)))
$(foreach prog,$(APPS),$(eval $(call PROG_TARGET_TEMPLATE,$(prog),apps)))

$(foreach action,build install uninstall clean,$(eval $(call PHONY_TARGETS_TEMPLATE_1,$(action),libs)))
$(foreach action,build install uninstall clean,$(eval $(call PHONY_TARGETS_TEMPLATE_1,$(action),apps)))
$(foreach action,build install uninstall clean,$(eval $(call PHONY_TARGETS_TEMPLATE_2,$(action))))
