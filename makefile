# Makefile script to generate AppImage for LOVE

# Number of processor to use when compiling
NUMBER_OF_PROCESSORS := $(shell nproc)

# CPU architecture, defaults to host
ARCH := $(shell uname -m)

# CMake URL
CMAKE_VERSION := 3.27.7
CMAKE_URL := https://github.com/Kitware/CMake/releases/download/v$(CMAKE_VERSION)/cmake-$(CMAKE_VERSION)-linux-$(shell uname -m).sh

# Project branches (for git-based projects)
LOVE_BRANCH := 11.5-lua5.4
SDL2_BRANCH := release-2.28.5
LUAJIT_BRANCH := v2.1
OPENAL_BRANCH := 1.23.1
BROTLI_BRANCH := v1.0.9
ZLIB_BRANCH := v1.3

# Project versions (for downloadable tars)
LIBOGG_VERSION := 1.3.5
LIBVORBIS_VERSION := 1.3.7
LIBTHEORA_VERSION := 1.2.0alpha1
LIBPNG_VERSION := 1.6.39
FT_VERSION := 2.13.2
BZIP2_VERSION := 1.0.8
MPG123_VERSION := 1.31.3
LIBMODPLUG_VERSION := 0.8.8.5
LUA_VERSION := 5.4.7

# Output AppImage
APPIMAGE_OUTPUT := love-$(LOVE_BRANCH).AppImage

# Output tar
TAR_OUTPUT := love-$(LOVE_BRANCH).tar.gz

# No need to change anything beyond this line
override INSTALLPREFIX := $(CURDIR)/installdir

override CMAKE_PREFIX := $(CURDIR)/cmake
CMAKE := $(CMAKE_PREFIX)/bin/cmake
override CMAKE_OPTS := --install-prefix $(INSTALLPREFIX) -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_RPATH='$$ORIGIN/../lib'
override CONFIGURE := LDFLAGS="-Wl,-rpath,'\$$\$$ORIGIN/../lib' $$LDFLAGS" LD_LIBRARY_PATH=$(INSTALLPREFIX)/lib:${LD_LIBRARY_PATH} ../configure --prefix=$(INSTALLPREFIX)

# CMake setup
ifeq ($(SYSTEM_CMAKE),)
cmake_install.sh:
	curl $(CURL_DOH_URL) -Lfo cmake_install.sh $(CMAKE_URL)
	chmod u+x cmake_install.sh

$(CMAKE): cmake_install.sh
	mkdir cmake
	bash cmake_install.sh --prefix=$(CMAKE_PREFIX) --skip-license
	touch $(CMAKE)
else
CMAKE := $(CURDIR)/cmakewrapper.sh

$(CMAKE):
	which cmake
	echo $(shell which cmake) '$$@' > $(CMAKE)
	chmod u+x $(CMAKE)
endif

# cURL DoH URL
ifneq ($(DOH_URL),)
override CURL_DOH_URL := --doh-url $(DOH_URL)
endif

cmake: $(CMAKE)

# SDL2
override SDL2_PATH := SDL2-$(SDL2_BRANCH)

$(SDL2_PATH)/configure:
	git clone --depth 1 -b $(SDL2_BRANCH) https://github.com/libsdl-org/SDL $(SDL2_PATH)

$(SDL2_PATH)/build/Makefile: $(SDL2_PATH)/configure
	mkdir -p $(SDL2_PATH)/build
	cd $(SDL2_PATH)/build && $(CONFIGURE) --disable-video-wayland

installdir/lib/libSDL2.so: $(SDL2_PATH)/build/Makefile
	cd $(SDL2_PATH)/build && $(MAKE) install -j$(NUMBER_OF_PROCESSORS)

# libogg
override LIBOGG_FILE := libogg-$(LIBOGG_VERSION)

$(LIBOGG_FILE).tar.gz:
	curl $(CURL_DOH_URL) -Lfo $(LIBOGG_FILE).tar.gz http://downloads.xiph.org/releases/ogg/$(LIBOGG_FILE).tar.gz

$(LIBOGG_FILE)/configure: $(LIBOGG_FILE).tar.gz
	tar xzf $(LIBOGG_FILE).tar.gz
	touch $(LIBOGG_FILE)/configure

$(LIBOGG_FILE)/build/Makefile: $(LIBOGG_FILE)/configure
	mkdir -p $(LIBOGG_FILE)/build
	cd $(LIBOGG_FILE)/build && $(CONFIGURE)

installdir/lib/libogg.so: $(LIBOGG_FILE)/build/Makefile
	cd $(LIBOGG_FILE)/build && $(MAKE) install -j$(NUMBER_OF_PROCESSORS)

# libvorbis
override LIBVORBIS_FILE := libvorbis-$(LIBVORBIS_VERSION)

$(LIBVORBIS_FILE).tar.gz:
	curl $(CURL_DOH_URL) -Lfo $(LIBVORBIS_FILE).tar.gz http://downloads.xiph.org/releases/vorbis/$(LIBVORBIS_FILE).tar.gz

$(LIBVORBIS_FILE)/configure: $(LIBVORBIS_FILE).tar.gz
	tar xzf $(LIBVORBIS_FILE).tar.gz
	touch $(LIBVORBIS_FILE)/configure

$(LIBVORBIS_FILE)/build/Makefile: $(LIBVORBIS_FILE)/configure installdir/lib/libogg.so
	mkdir -p $(LIBVORBIS_FILE)/build
	cd $(LIBVORBIS_FILE)/build && $(CONFIGURE)

installdir/lib/libvorbis.so: $(LIBVORBIS_FILE)/build/Makefile
	cd $(LIBVORBIS_FILE)/build && $(MAKE) install -j$(NUMBER_OF_PROCESSORS)

# libtheora
override LIBTHEORA_FILE := libtheora-$(LIBTHEORA_VERSION)

$(LIBTHEORA_FILE).tar.gz:
	curl $(CURL_DOH_URL) -Lfo $(LIBTHEORA_FILE).tar.gz http://downloads.xiph.org/releases/theora/$(LIBTHEORA_FILE).tar.gz

$(LIBTHEORA_FILE)/configure: $(LIBTHEORA_FILE).tar.gz
	tar xzf $(LIBTHEORA_FILE).tar.gz
# Their config.guess and config.sub can't detect ARM64
ifeq ($(ARCH),aarch64)
	curl $(CURL_DOH_URL) -Lfo $(LIBTHEORA_FILE)/config.guess "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD"
	chmod u+x $(LIBTHEORA_FILE)/config.guess
	curl $(CURL_DOH_URL) -Lfo $(LIBTHEORA_FILE)/config.sub "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD"
	chmod u+x $(LIBTHEORA_FILE)/config.sub
endif
	touch $(LIBTHEORA_FILE)/configure

$(LIBTHEORA_FILE)/build/Makefile: $(LIBTHEORA_FILE)/configure installdir/lib/libogg.so
	mkdir -p $(LIBTHEORA_FILE)/build
	cd $(LIBTHEORA_FILE)/build && $(CONFIGURE) --with-ogg=$(INSTALLPREFIX) --with-vorbis=$(INSTALLPREFIX) --disable-examples --disable-encode

installdir/lib/libtheora.so: $(LIBTHEORA_FILE)/build/Makefile
	cd $(LIBTHEORA_FILE)/build && $(MAKE) install -j $(NUMBER_OF_PROCESSORS)

# zlib
override ZLIB_PATH := zlib-$(ZLIB_BRANCH)

$(ZLIB_PATH)/configure:
	git clone --depth 1 -b $(ZLIB_BRANCH) https://github.com/madler/zlib $(ZLIB_PATH)

$(ZLIB_PATH)/build/Makefile: $(ZLIB_PATH)/configure
	mkdir -p $(ZLIB_PATH)/build
	cd $(ZLIB_PATH)/build && $(CONFIGURE)

installdir/lib/libz.so: $(ZLIB_PATH)/build/Makefile
	cd $(ZLIB_PATH)/build && $(MAKE) install -j$(NUMBER_OF_PROCESSORS)

# libpng
override LIBPNG_FILE := libpng-$(LIBPNG_VERSION)

$(LIBPNG_FILE).tar.gz:
	curl -Lo $(LIBPNG_FILE).tar.gz http://prdownloads.sourceforge.net/libpng/$(LIBPNG_FILE).tar.gz?download

$(LIBPNG_FILE)/configure: $(LIBPNG_FILE).tar.gz
	tar xzf $(LIBPNG_FILE).tar.gz
	touch $(LIBPNG_FILE)/configure

$(LIBPNG_FILE)/build/Makefile: $(LIBPNG_FILE)/configure installdir/lib/libz.so
	mkdir -p $(LIBPNG_FILE)/build
	cd $(LIBPNG_FILE)/build && LDFLAGS="-L$(INSTALLPREFIX)/lib" CFLAGS="-I$(INSTALLPREFIX)/include" CPPFLAGS="-I$(INSTALLPREFIX)/include" $(CONFIGURE)

installdir/lib/libpng16.so: $(LIBPNG_FILE)/build/Makefile
	cd $(LIBPNG_FILE)/build && CFLAGS="-I$(INSTALLPREFIX)/include" $(MAKE) install -j$(NUMBER_OF_PROCESSORS)

# Brotli
override BROTLI_PATH := brotli-$(BROTLI_BRANCH)

$(BROTLI_PATH)/CMakeLists.txt:
	git clone --depth 1 -b $(BROTLI_BRANCH) https://github.com/google/brotli $(BROTLI_PATH)

$(BROTLI_PATH)/build/CMakeCache.txt: $(CMAKE) $(BROTLI_PATH)/CMakeLists.txt
	$(CMAKE) -B$(BROTLI_PATH)/build -S$(BROTLI_PATH) $(CMAKE_OPTS)

installdir/lib/libbrotlidec.so: $(BROTLI_PATH)/build/CMakeCache.txt
	$(CMAKE) --build $(BROTLI_PATH)/build --target install -j $(NUMBER_OF_PROCESSORS)

# OpenAL-soft
override OPENAL_PATH := openal-soft-$(OPENAL_BRANCH)

$(OPENAL_PATH)/CMakeLists.txt:
	git clone --depth 1 -b $(OPENAL_BRANCH) https://github.com/kcat/openal-soft $(OPENAL_PATH)

$(OPENAL_PATH)/build/CMakeCache.txt: $(CMAKE) $(OPENAL_PATH)/CMakeLists.txt
	$(CMAKE) -B$(OPENAL_PATH)/build -S$(OPENAL_PATH) $(CMAKE_OPTS) -DALSOFT_EXAMPLES=0 -DALSOFT_BACKEND_SNDIO=0

installdir/lib/libopenal.so: $(OPENAL_PATH)/build/CMakeCache.txt
	$(CMAKE) --build $(OPENAL_PATH)/build --target install -j $(NUMBER_OF_PROCESSORS)

# BZip2
override BZIP2_FILE := bzip2-$(BZIP2_VERSION)

$(BZIP2_FILE).tar.gz:
	curl $(CURL_DOH_URL) -Lfo $(BZIP2_FILE).tar.gz https://sourceware.org/pub/bzip2/$(BZIP2_FILE).tar.gz

$(BZIP2_FILE)/Makefile: $(BZIP2_FILE).tar.gz
	tar xzf $(BZIP2_FILE).tar.gz
	touch $(BZIP2_FILE)/Makefile

installdir/bzip2installed.txt: $(BZIP2_FILE)/Makefile
	cd $(BZIP2_FILE) && $(MAKE) install -j$(NUMBER_OF_PROCESSORS) CFLAGS="-fPIC -Wall -Winline -O2 -g -D_FILE_OFFSET_BITS=64" LDFLAGS="-Wl,-rpath,'\$ORIGIN/../lib'" PREFIX=$(INSTALLPREFIX)
	touch installdir/bzip2installed.txt

# FreeType
override FT_FILE := freetype-$(FT_VERSION)

$(FT_FILE).tar.gz:
	curl $(CURL_DOH_URL) -Lfo $(FT_FILE).tar.gz https://download.savannah.gnu.org/releases/freetype/$(FT_FILE).tar.gz

$(FT_FILE)/configure: $(FT_FILE).tar.gz
	tar xzf $(FT_FILE).tar.gz
	touch $(FT_FILE)/configure

$(FT_FILE)/build/Makefile: $(FT_FILE)/configure installdir/bzip2installed.txt installdir/lib/libpng16.so installdir/lib/libz.so installdir/lib/libbrotlidec.so
	mkdir -p $(FT_FILE)/build
	cd $(FT_FILE)/build && CFLAGS="-I$(INSTALLPREFIX)/include" LDFLAGS="-Wl,-rpath,'\$$\$$ORIGIN/../lib' -L$(INSTALLPREFIX)/lib -Wl,--no-undefined" PKG_CONFIG_PATH=$(INSTALLPREFIX)/lib/pkgconfig ../configure --prefix=$(INSTALLPREFIX)

installdir/lib/libfreetype.so: $(FT_FILE)/build/Makefile
	cd $(FT_FILE)/build && $(MAKE) install -j$(NUMBER_OF_PROCESSORS)

# Mpg123
override MPG123_FILE := mpg123-$(MPG123_VERSION)

$(MPG123_FILE).tar.bz2:
	curl $(CURL_DOH_URL) -Lfo $(MPG123_FILE).tar.bz2 https://www.mpg123.de/download/$(MPG123_FILE).tar.bz2

$(MPG123_FILE)/configure: $(MPG123_FILE).tar.bz2
	tar xf $(MPG123_FILE).tar.bz2
	touch $(MPG123_FILE)/configure

$(MPG123_FILE)/builddir/Makefile: $(MPG123_FILE)/configure
	mkdir -p $(MPG123_FILE)/builddir
	cd $(MPG123_FILE)/builddir && $(CONFIGURE)

installdir/lib/libmpg123.so: $(MPG123_FILE)/builddir/Makefile
	cd $(MPG123_FILE)/builddir && $(MAKE) install -j$(NUMBER_OF_PROCESSORS)

# libmodplug
override LIBMODPLUG_FILE := libmodplug-$(LIBMODPLUG_VERSION)

$(LIBMODPLUG_FILE).tar.gz:
	curl $(CURL_DOH_URL) -Lfo $(LIBMODPLUG_FILE).tar.gz http://sourceforge.net/projects/modplug-xmms/files/libmodplug/$(LIBMODPLUG_VERSION)/$(LIBMODPLUG_FILE).tar.gz/download

$(LIBMODPLUG_FILE)/configure: $(LIBMODPLUG_FILE).tar.gz
	tar xzf $(LIBMODPLUG_FILE).tar.gz
	touch $(LIBMODPLUG_FILE)/configure

$(LIBMODPLUG_FILE)/build/Makefile: $(LIBMODPLUG_FILE)/configure
	mkdir -p $(LIBMODPLUG_FILE)/build
	cd $(LIBMODPLUG_FILE)/build && $(CONFIGURE)

installdir/lib/libmodplug.so: $(LIBMODPLUG_FILE)/build/Makefile
	cd $(LIBMODPLUG_FILE)/build && $(MAKE) install -j$(NUMBER_OF_PROCESSORS)


# Lua
# override LUA_PATH := lua-$(LUA_VERSION)

# $(LUA_PATH).tar.gz:
# 	curl $(CURL_DOH_URL) -Lfo $(LUA_PATH).tar.gz https://www.lua.org/ftp/$(LUA_PATH).tar.gz

# $(LUA_PATH)/Makefile: $(LUA_PATH).tar.gz
# 	tar xzf $(LUA_PATH).tar.gz
# 	touch $(LUA_PATH)/Makefile

# installdir/lib/liblua.a:
# 	mkdir -p $(LUA_PATH)
# 	cd $(LUA_PATH) && $(MAKE) -j$(NUMBER_OF_PROCESSORS)
# 	cd $(LUA_PATH) && $(MAKE) install INSTALL_TOP=$(INSTALLPREFIX)


configure:  installdir/lib/libmodplug.so installdir/lib/libmpg123.so installdir/lib/libfreetype.so installdir/lib/libopenal.so installdir/lib/libz.so installdir/lib/libtheora.so installdir/lib/libvorbis.so installdir/lib/libogg.so installdir/lib/libSDL2.so

getdeps: $(CMAKE) $(SDL2_PATH)/configure $(LIBOGG_FILE).tar.gz $(LIBVORBIS_FILE).tar.gz $(LIBTHEORA_FILE).tar.gz $(ZLIB_PATH)/configure $(LIBPNG_FILE).tar.gz $(BROTLI_PATH)/CMakeLists.txt $(BZIP2_FILE).tar.gz $(FT_FILE).tar.gz $(MPG123_FILE).tar.bz2 $(LIBMODPLUG_FILE).tar.gz

default: getdeps configure

.DEFAULT_GOAL := default

