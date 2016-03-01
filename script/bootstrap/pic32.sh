set -e
BOOTSTRAP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $BOOTSTRAP_DIR/common.sh

echo "Installing dependencies for building for chipKIT Max32 platform"

source $BOOTSTRAP_DIR/flashing_chipkit.sh

## chipKIT libraries for USB, CAN and Network

CHIPKIT_LIBRARY_AGREEMENT_URL="https://reference.digilentinc.com/agreement"

# Disabling SSL cert checking (-k), which while strong discouraged, is
# used here because some dependency hosts CA bundle files are messed up,
# and this software doesn't store any secure data. If Digilent fixes
# their SSL certificate bundle we can remove it.
NOT_SECURE="true"
CHIPKIT_LIBRARY_DOWNLOAD_URL="https://reference.digilentinc.com/_media/chipkit_network_and_usb_libs-20150115.zip"
CHIPKIT_ZIP_FILE="chipkit_network_and_usb_libs-20150115.zip"

_pushd $DEPENDENCIES_FOLDER
if ! test -e $CHIPKIT_ZIP_FILE
then
    echo
    if [ -z $CI ] && [ -z $VAGRANT ]; then
        echo "By running this command, you agree to Microchip's licensing agreement at $CHIPKIT_LIBRARY_AGREEMENT_URL"
        echo "Press Enter to verify you have read the license agreement."
        read
    fi
    download $CHIPKIT_LIBRARY_DOWNLOAD_URL $CHIPKIT_ZIP_FILE $NOT_SECURE
    echo "Extracting CHIPKit"
    unzip -q $CHIPKIT_ZIP_FILE
fi
_popd

_pushd src/libs
for LIBRARY in chipKITUSBDevice chipKITCAN chipKITEthernet; do
    echo "Installing chipKIT library $LIBRARY..."
    cp -R ../../dependencies/libraries/$LIBRARY .
done
_popd


## Microchip Libraries for MSD (SD card for C5)

if !  command -v p7zip >/dev/null 2>&1; then
	echo "Installing 7zip..."
	_install "p7zip-full"
fi


MLA_LIBRARY_AGREEMENT_URL="http://ww1.microchip.com/downloads/en/DeviceDoc/Microchip%20Application%20Solutions%20Users%20Agreement.pdf"
MLA_LIBRARY_URL="http://ww1.microchip.com/downloads/en/DeviceDoc/MCHP_App_Lib_v2010_10_19_Installer.zip"
MLA_ZIP_FILE="MCHP_App_Lib_v2010_10_19_Installer.zip"
MLA_FOLDER_OUTPUT="MLA"

_pushd $DEPENDENCIES_FOLDER
if ! test -e $MLA_ZIP_FILE 
then
    echo
    if [ -z $CI ] && [ -z $VAGRANT ]; then
        echo "By running this command, you agree to Microchip's licensing agreement at $MLA_LIBRARY_AGREEMENT_URL"
        echo "Press Enter to verify you have read the license agreement."
        read
    fi
    download $MLA_LIBRARY_URL $MLA_ZIP_FILE
    echo "Extracting MLA zip"
    unzip -q $MLA_ZIP_FILE
    echo "Extracting MLA exe"
    #7z doesn't have a quiet mode??? Redirect o/p for now. Find better way later
    7z x 'Microchip Application Libraries v2010-10-19 Installer.exe' -o$MLA_FOLDER_OUTPUT > 7z.log
fi
_popd

_pushd src/libs
if ! test -e $MLA_FOLDER_OUTPUT
then
    echo "Installing MLA MSD"
    mkdir $MLA_FOLDER_OUTPUT
    cp -R '../../dependencies/MLA/Microchip/USB/MSD Device Driver/'. ./MLA/MSD_Device_Driver
    cp -R '../../dependencies/MLA/Microchip/MDD File System/'. ./MLA/MDD_File_System
    cp -R '../../dependencies/MLA/Microchip/Include/'. ./MLA/Include
fi
_popd

### Patch libraries to avoid problems in case sensitive operating systems
### See https://github.com/chipKIT32/chipKIT32-MAX/issues/146
### and https://github.com/chipKIT32/chipKIT32-MAX/issues/199

echo "Patching case-sensitivity bugs in chipKIT libraries..."

if [ $OS == "cygwin" ] && ! [ -e /usr/bin/patch ]; then
    _cygwin_error "patchutils"
fi

# If the patch is already applied, patch will error out, so disable quit on
# error temporarily
set +e
_pushd src/libs
_pushd chipKITUSBDevice
patch -p1 -sNi ../../../script/chipKITUSBDevice-case.patch > /dev/null
_popd

_pushd chipKITCAN
patch -p1 -sNi ../../../script/chipKITCAN-case.patch > /dev/null
_popd

_popd
set -e

echo "Patching MLA files MDD Files"
set +e
_pushd src/libs/MLA/MDD_File_System
patch --binary FSIO.c < ../../../../script/FSIO-flush.patch
patch --binary SD-SPI.c < ../../../../script/SD-SPI-platform.patch
_popd
set -e



## Python pyserial module for the reset script in Arduino-Makefile

$PIP_SUDO_CMD pip install --upgrade pyserial

echo
echo "${bldgreen}PIC32 / chipKIT compilation dependencies installed.$txtrst"
