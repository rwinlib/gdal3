#/bin/sh
set -e
PACKAGE=gdal

# Update
pacman -Syy --noconfirm
OUTPUT=$(mktemp -d)
LIBS=$(echo lib{gdal,sqlite3,spatialite,proj,geos_c,geos,json-c,netcdf,mariadbclient,pq,pgport,pgcommon,webp,curl,ssh2,ssl,crypto,hdf5_hl,hdf5,expat,freexl,cfitsio,mfhdf,hdf,xdr,pcre,openjp2,jasper,png,jpeg,tiff,geotiff,gif,xml2,lzma,z,zstd}.a)
ROOT=$(pwd)

# Download files (-dd skips dependencies)
pkgs=$(echo mingw-w64-{i686,x86_64,ucrt-x86_64}-gdal)
deps=$(pacman -Si $pkgs | grep 'Depends On' | grep -o 'mingw-w64-[_.a-z0-9-]*')
extras=$(echo mingw-w64-{i686,x86_64,ucrt-x86_64}-{bzip2,udunits,libssh2,openssl,libtiff,zlib})
URLS=$(pacman -Sp $pkgs $deps $extras --cache=$OUTPUT)
VERSION=$(pacman -Si mingw-w64-x86_64-${PACKAGE} | awk '/^Version/{print $3}')

# Set version for next step
echo "::set-output name=VERSION::${VERSION}"
echo "::set-output name=PACKAGE::${PACKAGE}"
echo "Bundling $PACKAGE-$VERSION"
echo "# $PACKAGE $VERSION" > README.md
echo "" >> README.md

for URL in $URLS; do
  curl -OLs $URL
  FILE=$(basename $URL)
  echo "Extracting: $FILE"
  echo " - $FILE" >> readme.md
  tar xf $FILE -C ${OUTPUT}
  rm -f $FILE
done

# Copy libs
rm -Rf lib lib-8.3.0
mkdir -p lib/x64 lib-8.3.0/{x64,i386}
(cd ${OUTPUT}/ucrt64/lib; cp -fv $LIBS $ROOT/lib/x64/)
(cd ${OUTPUT}/mingw64/lib; cp -fv $LIBS $ROOT/lib-8.3.0/x64/)
(cd ${OUTPUT}/mingw32/lib; cp -fv $LIBS $ROOT/lib-8.3.0/i386/)

# Copy share (keep old extra files for proj)
mkdir -p share/proj
rm -Rf share/gdal share/udunits
cp -fv ${OUTPUT}/mingw64/share/proj/* share/proj/
cp -Rfv ${OUTPUT}/mingw64/share/gdal share/
cp -Rfv ${OUTPUT}/mingw64/share/udunits share/

# Copy headers for some packages
rm -Rf include
mkdir -p include
cp -Rf ${OUTPUT}/mingw64/include .

# Cleanup temporary dir
rm -Rf ${OUTPUT}/*

# Setup backports repo
function finish {
  echo "Restoring pacman.conf"
  cp -f /etc/pacman.conf.bak /etc/pacman.conf
  rm -f /etc/pacman.conf.bak
  pacman -Scc --noconfirm
  pacman -Syy
}
trap finish EXIT
cp /etc/pacman.conf /etc/pacman.conf.bak
curl -Ol 'https://raw.githubusercontent.com/r-windows/rtools-backports/master/pacman.conf'
cp -f pacman.conf /etc/pacman.conf
pacman -Scc --noconfirm
pacman -Syy

# Download backports
backports=$(echo mingw-w64-{i686,x86_64}-{gdal,geos,proj,cfitsio,curl})
URLS=$(pacman -Sp $backports --cache=$OUTPUT)
for URL in $URLS; do
  curl -OLs $URL
  FILE=$(basename $URL)
  echo "Extracting: $FILE"
  tar xf $FILE -C ${OUTPUT}
  rm -f $FILE
done

# Copy libs
rm -Rf lib-4.9.3
cp -Rf lib-8.3.0 lib-4.9.3
cp -fv ${OUTPUT}/mingw32/lib/lib{cfitsio,curl,gdal,geos,geos_c,proj}.a lib-4.9.3/i386/
cp -fv ${OUTPUT}/mingw64/lib/lib{gdal,geos,geos_c,proj}.a lib-4.9.3/x64/

# Cleanup temporary dir
rm -Rf ${OUTPUT} pacman.conf
