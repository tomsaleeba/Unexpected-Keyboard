define check_defined
$(if $($(1)),,$(error Variable $(1) not defined))
endef

$(call check_defined,NDK_HOME)
$(call check_defined,NDK_PLATFORM)
$(call check_defined,ANDROID_HOME)
$(call check_defined,ANDROID_BUILD_TOOLS)
$(call check_defined,ANDROID_PLATFORM)

NAME = unexpected-keyboard

export JAVACFLAGS = -source 1.7 -target 1.7 -encoding utf8

export JAVA_HOME = $(NDK_PLATFORM)/usr

BUILD_DIR ?= $(shell pwd)/bin

EXTRA_JARS := \
	_build/default.android/libs/ocaml-java/srcs/java_stubs/ocaml-java.jar

ARCHS = armeabi-v7a

armeabi-v7a: SWITCH = 4.04.0+32bit

all: TARGET = all
debug: TARGET = debug

all debug: $(ARCHS) $(EXTRA_JARS)
	make -f android.Makefile \
		NAME=$(NAME) ARCHS=$(ARCHS) EXTRA_JARS=$(EXTRA_JARS) \
		BIN_DIR=$(BUILD_DIR) $(TARGET)

$(ARCHS):
	mkdir -p $(BUILD_DIR)/lib/$@
	TARGET=_build/default.android/srcs/main/main.so; \
	opam exec --switch="$(SWITCH)" -- dune build -x android "$$TARGET" && \
	cp "$$TARGET" "$(BUILD_DIR)/lib/$@/lib$(NAME).so"

$(EXTRA_JARS):
	dune build -x android $@

install:
	adb install -r $(BUILD_DIR)/$(NAME).apk

installd:
	adb install -r $(BUILD_DIR)/$(NAME).debug.apk

.PHONY: all debug apk $(ARCHS) install installd
