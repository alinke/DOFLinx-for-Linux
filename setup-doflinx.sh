#!/bin/bash
# Run this script with this command
# wget https://raw.githubusercontent.com/DOFLinx/DOFLinx-for-Linux/refs/heads/main/setup-doflinx.sh && chmod +x setup-doflinx.sh && ./setup-doflinx.sh
version=1
install_successful=true
mame=true
batocera_40_plus_version=40

NEWLINE=$'\n'
cyan='\033[0;36m'
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
nc='\033[0m'

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

echo -e ""
echo -e "       ${cyan}DOFLinx for Linux : Installer Version $version${nc}    "
echo -e ""
echo -e "This script will install the DOFLinx software in $HOME/doflinx"
echo -e "Plese ensure you have at least 1 GB of free disk space in $HOME"
echo -e "Use "nomame" on the command line for this script if you do not want the DOFLinx version of Mame installed.  If you do this you will need to install it manually later."
echo -e ""
pause

# TODO
# set DOFLinx to run?

INSTALLPATH="${HOME}/"

commandLineArg=$1

if [[ "$commandLineArg" == "nomame" ]]; then
   echo -e "${yellow}[WARNING]${nc} Excluding setting up the DOFLinx version of Mame (due to "nomame" parameter).  Please do this manually later."
   mame=false
fi

# If this is an existing installation then DOFLinx could already be running
if test -f ${INSTALLPATH}doflinx/DOFLinx; then
   echo "[INFO] Existing DOFLinx installation found"
   if pgrep -x "DOFLinx" > /dev/null; then
     echo -e "${green}[INFO]${nc} Stopping DOFLinx"
     ${INSTALLPATH}doflinx/DOFLinxMsg QUIT
  fi
fi

if ! test -f ${INSTALLPATH}pixelcade/pixelweb; then
   echo -e "${green}[INFO]${nc} No Pixelcade installation can be seen at ${INSTALLPATH}pixelcade"
fi

if ! test -f /usr/games/mame; then
   echo -e "${yellow}[WARNING]${nc} No Mame instllation can be seen at /usr/games"
fi

# The possible platforms are:
# linux_arm64
# linux_386
# linux_amd64
# linux_arm_v6
# linux_arm_v7

if uname -m | grep -q 'armv6'; then
   echo -e "${yellow}arm_v6 Detected...${nc}"
   machine_arch=arm_v6
fi

if uname -m | grep -q 'armv7'; then
   echo -e "${yellow}arm_v7 Detected...${nc}"
   machine_arch=arm_v7
fi

if uname -m | grep -q 'aarch32'; then
   echo -e "${yellow}aarch32 Detected...${nc}"
   aarch32=arm_v7
fi

if uname -m | grep -q 'aarch64'; then
   echo -e "${green}[INFO]${nc} aarch64 Detected..."
   machine_arch=arm64
fi

if uname -m | grep -q 'x86'; then
   if uname -m | grep -q 'x86_64'; then
      echo -e "${green}[INFO]${nc}x86 64-bit Detected..."
      machine_arch=x64
   else
      echo -e "${red}[ERROR]${nc}x86 32-bit Detected...not supported"
      machine_arch=386
   fi
fi

if uname -m | grep -q 'amd64'; then
   echo -e "${green}[INFO]${nc}x86 64-bit Detected..."
   machine_arch=x64
fi

if test -f /proc/device-tree/model; then
   if cat /proc/device-tree/model | grep -q 'Raspberry Pi 3'; then
      echo -e "${yellow}Raspberry Pi 3 detected...${nc}"
      pi3=true
   fi
   if cat /proc/device-tree/model | grep -q 'Pi 4'; then
      echo -e "${yellow}Raspberry Pi 4 detected...${nc}"
      pi4=true
   fi
   if cat /proc/device-tree/model | grep -q 'Pi Zero W'; then
      echo -e "${yellow}Raspberry Pi Zero detected...${nc}"
      pizero=true
   fi
   if cat /proc/device-tree/model | grep -q 'ODROID-N2'; then
      echo -e "${yellow}ODroid N2 or N2+ detected...${nc}"
      odroidn2=true
   fi
fi

if [[ $machine_arch == "default" ]]; then
  echo -e "${red}[ERROR] Your device platform WAS NOT Detected"
  echo -e "${yellow}[WARNING] Guessing that you are on x64 but be aware DOFLinx may not work${nc}"
  machine_arch=x64
fi

if [[ ! -d "${INSTALLPATH}doflinx" ]]; then #create the doflinx folder if it's not there
   mkdir ${INSTALLPATH}doflinx
fi
if [[ ! -d "${INSTALLPATH}doflinx/temp" ]]; then #create the doflinx/temp folder if it's not there
   mkdir ${INSTALLPATH}doflinx/temp
fi

echo -e "${cyan}[INFO]Installing DOFLinx Software...${nc}"

cd ${INSTALLPATH}doflinx/temp

if [[ $mame == "true" ]]; then
   mame_url=https://github.com/DOFLinx/DOFLinx-for-Linux/releases/download/mame-${machine_arch}/mame-${machine_arch}.zip
   wget -O "${INSTALLPATH}doflinx/temp/mame-${machine_arch}.zip" "$mame_url"
   if [ $? -ne 0 ]; then
      echo -e "${red}[ERROR]${nc} Failed to download Mame"
      install_successful=false
   else
      unzip mame-${machine_arch}
      if [ $? -ne 0 ]; then
         echo -e "${red}[ERROR]${nc} Failed to unzip Mame"
         install_successful=false
      else
         sudo cp -f /usr/games/mame /usr/games/mame_old
         sudo cp -f ./mame /usr/games/mame
         if [ $? -ne 0 ]; then
            echo -e "${red}[ERROR]${nc} Failed to copy Mame executable"
            install_successful=false
         fi
      fi
   fi
fi
doflinx_url=https://github.com/DOFLinx/DOFLinx-for-Linux/releases/download/doflinx/doflinx.zip
wget -O "${INSTALLPATH}doflinx/temp/doflinx.zip" "$doflinx_url"
if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR]${nc} Failed to download DOFLinx"
   install_successful=false
else
   unzip -o doflinx.zip -d ${INSTALLPATH}doflinx
   if [ $? -ne 0 ]; then
      echo -e "${red}[ERROR]${nc} Failed to unzip DOFlinx"
      install_successful=false
   else
      cp -f ${INSTALLPATH}doflinx/${machine_arch}/* ${INSTALLPATH}doflinx/
      if [ $? -ne 0 ]; then
         echo -e "${red}[ERROR]${nc} Failed to copy DOFLinx files"
         install_successful=false
      fi
   fi
fi

chmod a+x ${INSTALLPATH}doflinx/DOFLinx
chmod a+x ${INSTALLPATH}doflinx/DOFLinxMsg

sed -i -e "s|/home/arcade/|${INSTALLPATH}|g" ${INSTALLPATH}/doflinx/config/DOFLinx.ini
if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR] Failed to edit DOFLinx.ini"
   install_successful=false
fi

# checking if we have a Batocera installation and if so, we'll add doflinx to Batocera services
if batocera-info | grep -q 'System'; then
   echo "Batocera Detected"
   batocera_version="$(batocera-es-swissknife --version | cut -c1-2)" #get the version of Batocera as only Batocera V40 and above support services
   if [[ $batocera_version -ge $batocera_40_plus_version ]]; then #we need to add the service file and enable in services
      if [[ ! -d ${INSTALLPATH}services ]]; then #does the ES scripts folder exist, make it if not
         mkdir ${INSTALLPATH}services
      fi
      wget -O ${INSTALLPATH}services/doflinx https://raw.githubusercontent.com/DOFLinx/DOFLinx-for-Linux/main/batocera/doflinx
      chmod +x ${INSTALLPATH}services/doflinx
      sleep 1
      batocera-services enable doflinx 
      echo "[INFO] DOFLinx added to Batocera services for Batocera V40 and up"
   fi #TODO add support for Batocera V39 and below and modify custom.sh
else
  echo -e "${yellow}[ERROR]${nc} Not on Batocera, skipping Batocera service setup..."
fi

echo -e "${green}[INFO]${nc} Cleaning up"
cd ${INSTALLPATH}
rm -r ${INSTALLPATH}doflinx/temp

if [[ $install_successful == "true" ]]; then
   echo -e "${green}[INFO]${nc} DOFLinx Installed"
   echo -e "${green}[INFO]${nc} The guide can be found at https://doflinx.github.io/docs/"
   echo -e "${green}[INFO]${nc} Support can be found at http://www.vpforums.org/index.php?showforum=104"
   echo -e "${green}[INFO]${nc} Now setup DOFLinx to start at boot running via sudo"
   echo -e "${green}[INFO]${nc} A default DOFLinx.ini has been installed in ./DOFLinx/config and updated as best possible"
   echo -e "${green}[INFO]${nc} You may need to customise parameters for your system in ./config/DOFLinx.ini for paths and button input codes"
else
  echo -e "${red}[ERROR]${nc} DOFLinx installation failed"
fi
echo ""
