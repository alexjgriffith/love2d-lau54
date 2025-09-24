mkdir -p release

sudo apt-get update

sudo apt-get install --assume-yes build-essential git make cmake autoconf automake \
     libtool pkg-config libasound2-dev libpulse-dev libaudio-dev \
     libjack-dev libx11-dev libxext-dev libxrandr-dev libxcursor-dev \
     libxfixes-dev libxi-dev libxinerama-dev libxxf86vm-dev libxss-dev \
     libgl1-mesa-dev libdbus-1-dev libudev-dev libgles2-mesa-dev \
     libegl1-mesa-dev libibus-1.0-dev fcitx-libs-dev libsamplerate0-dev \
     libsndio-dev libwayland-dev libxkbcommon-dev libdrm-dev libgbm-dev \
     liblua5.4-dev libmodplug-dev libfreetype-dev libopengl-dev libopenal-dev \
     libmpg123-dev libvorbis-dev libtheora-dev #libsdl2-dev

## Build Dependencies
mkdir -p tmp
cd tmp
ln -s ../makefile
make
cd ../


## Build Love2d
git clone https://github.com/love2d/love.git
cd love
git switch 11.x
## Patch CMake FIle to use Lua5.4 instead of Lua5.1
sed -i 's/Lua51/Lua/g' CMakeLists.txt
mkdir -p build
mv ../../tmp/installdir .
cd build

cmake .. -DCMAKE_LIBRARY_PATH=installdir/lib/ \
      -DCMAKE_INCLUDE_PATH=installdir/include/ \
   -DLOVE_JIT=0 -DCMAKE_INSTALL_PREFIX=/usr

CFLAGS="-Iinstalldir/include" \
      PKG_CONFIG_PATH=installdir/lib/pkgconfig \
      LDFLAGS="-Wl,-rpath,'\$$\$$ORIGIN/../lib' -Linstalldir/lib" \
      lua_CFLAGS="-Iinstalldir/include" \
      lua_LIBS="-Linstalldir/lib/lua/" \
      make -j$(nproc)


## Make AppImage
wget https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20250213-2/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy-x86_64.AppImage

cat ../platform/unix/love.desktop.in | sed "s/@bindir@\/love %f/love \./g"> love.desktop

cp ../platform/unix/love.svg .
./linuxdeploy-x86_64.AppImage --appdir AppDir -e love -i love.svg -d love.desktop  --output appimage
mv LÖVE-x86_64.AppImage ../../release/love-11.5-lua5.4.AppImage
