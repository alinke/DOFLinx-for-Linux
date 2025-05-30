#!/bin/bash
# Run this script with this command
# wget https://raw.githubusercontent.com/DOFLinx/DOFLinx-for-Linux/refs/heads/main/setup-doflinx.sh && chmod +x setup-doflinx.sh && ./setup-doflinx.sh  TODO delete these lines later
# wget https://raw.githubusercontent.com/alinke/DOFLinx-for-Linux/refs/heads/main/setup-doflinx.sh && chmod +x setup-doflinx.sh && ./setup-doflinx.sh
# /usr/bin/emulatorlauncher -system mame -rom /userdata/roms/mame/1942.zip #for testing game launches in Batocera from command line

version=8
install_successful=true
batocera=false
batocera_version=""
batocera_40_plus_version=40
RETROPIE_AUTOSTART_FILE="/opt/retropie/configs/all/autostart.sh"
BATOCERA_MAME_GENERATOR_V41="/usr/lib/python3.11/site-packages/configgen/generators/mame/mameGenerator.py" #this is the same for V40 which uses mame 265
BATOCERA_MAME_GENERATOR_V42="/usr/lib/python3.12/site-packages/configgen/generators/mame/mameGenerator.py"
BATOCERA_CONFIG_FIlE="/userdata/system/batocera.conf"
BATOCERA_CONFIG_LINE1="mame.core=mame"
BATOCERA_CONFIG_LINE2="mame.emulator=mame"
BATOCERA_PLUGIN_PATH="/userdata/saves/mame/plugins" #Note Batocera will not look here so work around is we create a symlink from this folder to /usr/bin/mame/plugins/doflinx
DOFLINX_INI_FILE="${HOME}/doflinx/config/DOFLinx.ini"
RETROPIE_LINE_TO_ADD="cd ~/doflinx && ./DOFLinx -PATH_INI=~/doflinx/config/DOFLinx.ini"

NEWLINE=$'\n'
# Color definitions
cyan='\033[0;36m'
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
magenta='\033[0;35m'
orange='\033[0;33m' 

# Additional useful colors
blue='\033[0;34m'
purple='\033[0;35m'  # Same as magenta in basic ANSI
white='\033[1;37m'
black='\033[0;30m'
gray='\033[1;30m'
light_blue='\033[1;34m'
light_green='\033[1;32m'
light_cyan='\033[1;36m'

# Bold versions
bold='\033[1m'
bold_red='\033[1;31m'
bold_green='\033[1;32m'
bold_yellow='\033[1;33m'

# Background colors
bg_black='\033[40m'
bg_red='\033[41m'
bg_green='\033[42m'
bg_yellow='\033[43m'
bg_blue='\033[44m'
bg_magenta='\033[45m'
bg_cyan='\033[46m'
bg_white='\033[47m'

# Reset color after use
nc='\033[0m' # No Color

BACKUP_DIR="${HOME}/doflinx/backup"
if batocera-info | grep -q 'System'; then
   batocera=true
fi

get_joystick_number() {
    local device_pattern="$1"
    local js_number=""
    
    # Use case-insensitive search and match device pattern anywhere in the name
    js_number=$(grep -i -A 5 "Name=.*$device_pattern" /proc/bus/input/devices | grep "Handlers" | grep -o "js[0-9]*" | head -1)
    
    if [ -n "$js_number" ]; then
        # Extract just the number from 'js0', 'js1', etc. and add 1 (so js0 becomes 1)
        local num="${js_number#js}"
        echo "$((num + 1))"
    else
        echo "none"
    fi
}

download_github_file() {
    local github_url="$1"
    local filename="$2"
    local download_dir="$3"
    local output_path="${download_dir}/${filename}"
    
    # Convert GitHub blob URL to raw URL for downloading
    local raw_url=$(echo "$github_url" | sed 's|github.com|raw.githubusercontent.com|' | sed 's|/blob/|/|')
    
    echo "Downloading: $filename to ${download_dir}"
    wget -q -O "$output_path" "$raw_url" || {
        echo "Error downloading $filename"
        return 1
    }
    
    echo "Downloaded: $filename"
    return 0
}

# Backup a file before modifying it
backup_file() {
    local file_path="$1"
    local backup_name="$2"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Only backup the file if it exists and hasn't been backed up yet
    if [ -f "$file_path" ] && [ ! -f "$BACKUP_DIR/$backup_name" ]; then
        echo "Backing up: $file_path to $BACKUP_DIR/$backup_name"
        cp "$file_path" "$BACKUP_DIR/$backup_name"
    fi
}

restore_files() {
    echo -e "${magenta}Uninstall mode detected. Restoring original files...${nc}"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${red}No backups found to restore.${nc}"
        exit 0
    fi
    
    if [ -f "$BACKUP_DIR/mameGenerator.py.original" ]; then
        # Try to determine which version to restore to
        if [ -f "$BATOCERA_MAME_GENERATOR_V41" ]; then
            echo -e "${cyan}[INFO] Restoring: $BATOCERA_MAME_GENERATOR_V41${nc}"
            cp "$BACKUP_DIR/mameGenerator.py.original" "$BATOCERA_MAME_GENERATOR_V41"
        elif [ -f "$BATOCERA_MAME_GENERATOR_V42" ]; then
            echo -e "${cyan}[INFO] Restoring: $BATOCERA_MAME_GENERATOR_V42${nc}"
            cp "$BACKUP_DIR/mameGenerator.py.original" "$BATOCERA_MAME_GENERATOR_V42"
        else
            echo -e "${red}Could not determine Batocera MAME generator path for restoration${nc}"
        fi
    fi
    
    # Restore Batocera config file
    if [ -f "$BACKUP_DIR/batocera.conf.original" ] && [ -f "$BATOCERA_CONFIG_FIlE" ]; then
        echo -e "${cyan}[INFO] Restoring: $BATOCERA_CONFIG_FIlE${nc}"
        cp "$BACKUP_DIR/batocera.conf.original" "$BATOCERA_CONFIG_FIlE"
    fi
    
    # Restore RetroPie autostart file if it was modified
    if [ -f "$BACKUP_DIR/autostart.sh.original" ] && [ -f "$RETROPIE_AUTOSTART_FILE" ]; then
        echo -e "${cyan}[INFO] Restoring: $RETROPIE_AUTOSTART_FILE${nc}"
        cp "$BACKUP_DIR/autostart.sh.original" "$RETROPIE_AUTOSTART_FILE"
    fi
    
    # Remove DOFLinx plugin from MAME plugins directory
    if [ "$batocera" = "true" ]; then
        PLUGIN_PATH="${BATOCERA_PLUGIN_PATH}"
    else
        PLUGIN_PATH=$(find / -name init.lua 2>/dev/null | grep hiscore| xargs dirname | xargs dirname | head -n 1)
        if [ -z "$PLUGIN_PATH" ]; then
            PLUGIN_PATH="/usr/local/share/mame/plugins"
        fi
    fi
    
    if [ -d "${PLUGIN_PATH}/doflinx" ]; then
        echo -e "${cyan}[INFO] Removing DOFLinx plugin from MAME plugins directory: ${PLUGIN_PATH}/doflinx${nc}"
        rm -rf "${PLUGIN_PATH}/doflinx" || sudo rm -rf "${PLUGIN_PATH}/doflinx"
    fi
    
    # Remove DOFLinx from Batocera services if applicable
    if [ "$batocera" = "true" ]; then
        if [ -f "${HOME}/services/doflinx" ]; then
            echo -e "${cyan}[INFO] Disabling and removing DOFLinx service${nc}"
            batocera-services disable doflinx 2>/dev/null
            rm -f "${HOME}/services/doflinx"
            rm -r /usr/bin/mame/plugins/doflinx
        fi
        
        # Try to make the changes permanent
        if batocera-save-overlay 2>/dev/null; then
            echo "Changes saved to Batocera overlay"
        else
            echo "Warning: Could not save to overlay. Changes will be restored at next boot."
        fi
    fi
    
    # Remove DOFLinx installation directory
    if [ -d "${HOME}/doflinx" ]; then
        echo -e "${cyan}[INFO] Removing DOFLinx installation directory${nc}"
        rm -rf "${HOME}/doflinx"
    fi
    
    echo -e "${magenta}DOFLinx Uninstallation complete. All modified files have been restored${nc}"
    exit 0
}

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

commandLineArg=$1

if [ "$commandLineArg" = "undo" ]; then
    restore_files
fi

echo -e ""
echo -e "       ${magenta}DOFLinx for Linux : Installer Version $version${nc}    "
echo -e ""
echo -e "This script will install the DOFLinx software in $HOME/doflinx"
echo -e "You'll need at least 300 MB of free disk space in $HOME"
echo -e ""

# If this is an existing installation then DOFLinx could already be running so let's stop it
if test -f ${HOME}/doflinx/DOFLinx; then
   echo -e "${cyan}[INFO] Existing DOFLinx installation found${nc}"
   if pgrep -x "DOFLinx" > /dev/null; then
     echo -e "${cyan}[INFO] Stopping DOFLinx${nc}"
     ${HOME}/doflinx/DOFLinxMsg QUIT
  fi
fi

if ! test -f ${HOME}/pixelcade/pixelweb; then
   echo -e "${red}[INFO] No Pixelcade installation can be seen at ${HOME}/pixelcade${nc}"
   echo -e "${red}[INFO] It's recommended to quit now and install the Pixelcade software first from http://pixelcade.org${nc}"
   pause
fi

# The possible platforms are:
# linux_arm64
# linux_386
# linux_amd64
# linux_arm_v6
# linux_arm_v7

if uname -m | grep -q 'armv6'; then
   echo -e "${cyan}arm_v6 Detected...${nc}"
   machine_arch=arm_v6
fi

if uname -m | grep -q 'armv7'; then
   echo -e "${cyan}arm_v7 Detected...${nc}"
   machine_arch=arm_v7
fi

if uname -m | grep -q 'aarch32'; then
   echo -e "${cyan}aarch32 Detected...${nc}"
   aarch32=arm_v7
fi

if uname -m | grep -q 'aarch64'; then
   echo -e "${cyan}[INFO] aarch64 Detected...${nc}"
   machine_arch=arm64
fi

if uname -m | grep -q 'x86'; then
   if uname -m | grep -q 'x86_64'; then
      echo -e "${cyan}[INFO] x86 64-bit Detected...${nc}"
      machine_arch=x64
   else
      echo -e "${red}[ERROR] x86 32-bit Detected...not supported${nc}"
      machine_arch=386
   fi
fi

if uname -m | grep -q 'amd64'; then
   echo -e "${cyan}[INFO]x86 64-bit Detected...${nc}"
   machine_arch=x64
fi

if test -f /proc/device-tree/model; then
   if cat /proc/device-tree/model | grep -q 'Raspberry Pi 3'; then
      echo -e "${cyan}[INFO] Raspberry Pi 3 detected...${nc}"
      pi3=true
   fi
   if cat /proc/device-tree/model | grep -q 'Pi 4'; then
      echo -e "${cyan}[INFO] Raspberry Pi 4 detected...${nc}"
      pi4=true
   fi
   if cat /proc/device-tree/model | grep -q 'Pi 5'; then
      echo -e "${cyan}[INFO] Raspberry Pi 5 detected...${nc}"
      pi5=true
   fi
   if cat /proc/device-tree/model | grep -q 'Pi Zero W'; then
      echo -e "${cyan}[INFO] Raspberry Pi Zero detected...${nc}"
      pizero=true
   fi
   if cat /proc/device-tree/model | grep -q 'ODROID-N2'; then
      echo -e "${cyan}[INFO] ODroid N2 or N2+ detected...${nc}"
      odroidn2=true
   fi
fi

if [ "$batocera" = "true" ]; then
    batocera_version="$(batocera-es-swissknife --version | cut -c1-2)" 
    if [ "$batocera_version" -lt "39" ]; then
        echo -e "${red}[ERROR] Sorry, Batocera version 39 or higher is required. Please update and try again: exiting...${nc}"
        exit 1
    fi
fi

if [[ $machine_arch == "default" ]]; then
  echo -e "${red}[ERROR] Your device platform WAS NOT Detected"
  echo -e "${yellow}[WARNING] Guessing that you are on x64 but be aware DOFLinx may not work${nc}"
  machine_arch=x64
fi

if [[ ! -d "${HOME}/doflinx" ]]; then #create the doflinx folder if it's not there
   mkdir ${HOME}/doflinx
fi
if [[ ! -d "${HOME}/doflinx/temp" ]]; then #create the doflinx/temp folder if it's not there
   mkdir ${HOME}/doflinx/temp
fi

echo -e "${cyan}[INFO] Installing DOFLinx Software...${nc}"

cd ${HOME}/doflinx/temp

doflinx_url=https://github.com/DOFLinx/DOFLinx-for-Linux/releases/download/doflinx/doflinx.zip
wget -O "${HOME}/doflinx/temp/doflinx.zip" "$doflinx_url"
if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR]${nc} Failed to download DOFLinx"
   install_successful=false
else
   unzip -o doflinx.zip -d ${HOME}/doflinx
   if [ $? -ne 0 ]; then
      echo -e "${red}[ERROR]${nc} Failed to unzip DOFlinx"
      install_successful=false
   else
        cp -f ${HOME}/doflinx/${machine_arch}/* ${HOME}/doflinx/
        if [ $? -ne 0 ]; then
            echo -e "${red}[ERROR]${nc} Failed to copy DOFLinx files"
            install_successful=false
        fi

        # Check if we are on Batocera and if so, change the plugin path
        if [ "$batocera" = "true" ]; then
            PLUGIN_PATH="${BATOCERA_PLUGIN_PATH}"
        else
            echo "Not on Batocera, finding plugin path"
            PLUGIN_PATH=$(find / -name init.lua 2>/dev/null | grep hiscore| xargs dirname | xargs dirname | head -n 1)
            if [ -z "$PLUGIN_PATH" ]; then
                echo "Warning: Could not find plugin path. Using default path."
                PLUGIN_PATH="/usr/local/share/mame/plugins"
            fi
        fi

       #for a vanilla Batocera system, this plugins folder won't be there so we need to create it first
       DOFLINX_DIR="${PLUGIN_PATH}/doflinx"
        if [ ! -d "$DOFLINX_DIR" ]; then
            echo -e "${cyan}[INFO] Creating directory: $DOFLINX_DIR${nc}"
            mkdir -p "$DOFLINX_DIR"
        fi
      
        cp -f -r "${HOME}/doflinx/DOFLinx Mame Integration/doflinx" ${PLUGIN_PATH}/
        if [ $? -ne 0 ]; then
            echo -e "${yellow}[WARNING]${nc} Failed to copy DOFLinx plugin, will attempt via sudo"
            sudo cp -f -r "${HOME}/doflinx/DOFLinx Mame Integration/doflinx" ${PLUGIN_PATH}/
            if [ $? -ne 0 ]; then
                echo -e "${red}[ERROR]${nc} Failed to copy DOFLinx plugin"
                install_successful=false
            fi
        fi
        cp -f ${HOME}/doflinx/DLSocket/${machine_arch}/DLSocket ${PLUGIN_PATH}/doflinx/
        if [ $? -ne 0 ]; then
            echo -e "${yellow}[WARNING]${nc} Failed to copy DLSocket to DOFLinx plugin directory, will attempt via sudo"
            sudo cp -f ${HOME}/doflinx/DLSocket/${machine_arch}/DLSocket ${PLUGIN_PATH}/doflinx/
            if [ $? -ne 0 ]; then
                echo -e "${red}[ERROR]${nc} Failed to copy DLSocket to DOFLinx plugin directory"
                install_successful=false
            fi
        fi
   fi
fi

chmod a+x ${HOME}/doflinx/DOFLinx
chmod a+x ${HOME}/doflinx/DOFLinxMsg
chmod +x "${PLUGIN_PATH}/doflinx/DLSocket"

sed -i -e "s|/home/arcade/|${HOME}/|g" ${HOME}//doflinx/config/DOFLinx.ini
if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR] Failed to edit DOFLinx.ini"
   install_successful=false
fi

# Checking for Batocera installation
if [ "$batocera" = "true" ]; then
   batocera_version="$(batocera-es-swissknife --version | cut -c1-2)" #get the version of Batocera as only Batocera V40 and above support services
   echo -e "${cyan}[INFO] Batocera Version ${batocera_version} Detected${nc}"
   
   if [[ $batocera_version -ge $batocera_40_plus_version ]]; then #we need to add the service file and enable in services
      if [[ ! -d ${HOME}/services ]]; then #does the ES scripts folder exist, make it if not
         mkdir ${HOME}/services
      fi
      #TODO change this back to DOFLinx repo later
      wget -O ${HOME}/services/doflinx https://raw.githubusercontent.com/alinke/DOFLinx-for-Linux/main/batocera/doflinx
      chmod +x ${HOME}/services/doflinx
      sleep 1
      batocera-services enable doflinx 
      echo -e "${cyan}[INFO] DOFLinx added as a Batocera service for auto-start${nc}"
elif [[ $batocera_version -lt $batocera_40_plus_version ]]; then #handle older Batocera versions
      # Modify custom.sh for auto-start in older Batocera versions
      if [[ -f ${HOME}/custom.sh ]]; then
          # Check if DOFLinx entries already exist in custom.sh
          if ! grep -q "DOFLinx PATH_INI=" ${HOME}/custom.sh; then
              # Backup the original file first
              cp ${HOME}/custom.sh ${HOME}/custom.sh.backup
              
              # Update the custom.sh file - modified to add AFTER the pixelcade line
              if grep -q "pixelcade" ${HOME}/custom.sh; then
                  sed -i '/#        cd \/userdata\/system\/pixelcade && .\/pixelweb -image "system\/batocera.png" -startup &/a \ \ \ \ \ \ \ \ echo "export PATH=\/userdata\/system\/pixelcade\/jdk\/bin:\$PATH" > \/etc\/profile.d\/pixelcade_path.sh\n\ \ \ \ \ \ \ \ chmod +x \/etc\/profile.d\/pixelcade_path.sh\n\ \ \ \ \ \ \ \ # set the java path, DOFLinx needs it\n\ \ \ \ \ \ \ \ export PATH=\/userdata\/system\/pixelcade\/jdk\/bin:$PATH\n\ \ \ \ \ \ \ \ # Re-create the plugin symblink in case it got blown away\n\ \ \ \ \ \ \ \ if [ ! -L "\/usr\/bin\/mame\/plugins\/doflinx" ]; then\n\ \ \ \ \ \ \ \ \ \ \ \ ln -sf \/userdata\/saves\/mame\/plugins\/doflinx \/usr\/bin\/mame\/plugins\/doflinx\n\ \ \ \ \ \ \ \ fi\n\ \ \ \ \ \ \ \ sleep 5\n\ \ \ \ \ \ \ \ # Note if sleep 1 is not there, then sometimes DOFLinx will crash on boot\n\ \ \ \ \ \ \ \ cd \/userdata\/system\/doflinx && .\/DOFLinx PATH_INI=\/userdata\/system\/doflinx\/config\/DOFLinx.ini \&' ${HOME}/custom.sh
              else
                  # If pixelcade line doesn't exist, add after the start) line
                  sed -i '/start)/a \ \ \ \ \ \ \ \ echo "export PATH=\/userdata\/system\/pixelcade\/jdk\/bin:\$PATH" > \/etc\/profile.d\/pixelcade_path.sh\n\ \ \ \ \ \ \ \ chmod +x \/etc\/profile.d\/pixelcade_path.sh\n\ \ \ \ \ \ \ \ # set the java path, DOFLinx needs it\n\ \ \ \ \ \ \ \ export PATH=\/userdata\/system\/pixelcade\/jdk\/bin:$PATH\n\ \ \ \ \ \ \ \ # Re-create the plugin symblink in case it got blown away\n\ \ \ \ \ \ \ \ if [ ! -L "\/usr\/bin\/mame\/plugins\/doflinx" ]; then\n\ \ \ \ \ \ \ \ \ \ \ \ ln -sf \/userdata\/saves\/mame\/plugins\/doflinx \/usr\/bin\/mame\/plugins\/doflinx\n\ \ \ \ \ \ \ \ fi\n\ \ \ \ \ \ \ \ sleep 5\n\ \ \ \ \ \ \ \ # Note if sleep 1 is not there, then sometimes DOFLinx will crash on boot\n\ \ \ \ \ \ \ \ cd \/userdata\/system\/doflinx && .\/DOFLinx PATH_INI=\/userdata\/system\/doflinx\/config\/DOFLinx.ini \&' ${HOME}/custom.sh
              fi
              
              echo -e "${cyan}[INFO] Modified custom.sh for auto-starting DOFLinx on boot${nc}"
          else
              echo -e "${cyan}[INFO] DOFLinx startup already configured in custom.sh${nc}"
          fi
      else
          # Create custom.sh if it doesn't exist
          cat > ${HOME}/custom.sh << 'EOF'
#!/bin/bash
# Code here will be executed on every boot and shutdown.

# Check if security is enabled and store that setting to a variable.
#securityenabled="$(/usr/bin/batocera-settings-get system.security.enabled)"

case "$1" in
    start)
        # Code in here will only be executed on boot.
#        cd /userdata/system/pixelcade && ./pixelweb -image "system/batocera.png" -startup &
        echo "export PATH=/userdata/system/pixelcade/jdk/bin:\$PATH" > /etc/profile.d/pixelcade_path.sh
        chmod +x /etc/profile.d/pixelcade_path.sh
        # set the java path, DOFLinx needs it
        export PATH=/userdata/system/pixelcade/jdk/bin:$PATH
        # Re-create the plugin symblink in case it got blown away
        if [ ! -L "/usr/bin/mame/plugins/doflinx" ]; then
            ln -sf /userdata/saves/mame/plugins/doflinx /usr/bin/mame/plugins/doflinx
        fi
        sleep 5
        # Note if sleep 1 is not there, then sometimes DOFLinx will crash on boot
        cd /userdata/system/doflinx && ./DOFLinx PATH_INI=/userdata/system/doflinx/config/DOFLinx.ini &
        ;;
    stop)
        # Code in here will only be executed on shutdown.
        # TO DO add Pixelcade LCD shutdown command here later

        ;;
    restart|reload)
        # Code in here will executed (when?).

        ;;
    *)
        # Code in here will be executed in all other conditions.
        #echo "Usage: $0 {start|stop|restart}"
        ;;
esac

exit $?
EOF
          chmod +x ${HOME}/custom.sh
          echo -e "${cyan}[INFO] Created custom.sh for auto-starting DOFLinx on boot${nc}"
   fi
fi
  
   #****************************************************************
   #DOFLINX_DIR="${BATOCERA_PLUGIN_PATH}/doflinx"
   #if [ ! -d "$DOFLINX_DIR" ]; then
   #     echo "Creating directory: $DOFLINX_DIR"
   #     mkdir -p "$DOFLINX_DIR"
   #fi
   #echo "Downloading doflinx plugin files..."
   #if [ "$machine_arch" = "arm64" ]; then
      #download_github_file "https://github.com/alinke/pixelcade-linux-builds/blob/main/batocera/doflinx/DLSocket" "DLSocket" "$DOFLINX_DIR"
      #download_github_file "https://github.com/alinke/pixelcade-linux-builds/blob/main/batocera/doflinx/DOFLinx" "DOFLinx" "${HOME}/doflinx"
      #download_github_file "https://github.com/alinke/pixelcade-linux-builds/blob/main/batocera/doflinx/DOFLinx.pdb" "DOFLinx.pdb" "${HOME}/doflinx"
      #chmod a+x ${HOME}/doflinx/DOFLinx
      #chmod a+x ${HOME}/doflinx/DOFLinxMsg
      #chmod a+x ${DOFLINX_DIR}/DLSocket
   #fi   
   #download_github_file "https://github.com/alinke/pixelcade-linux-builds/blob/main/batocera/doflinx/init.lua" "init.lua" "$DOFLINX_DIR"
   #download_github_file "https://github.com/alinke/pixelcade-linux-builds/blob/main/batocera/doflinx/plugin.json" "plugin.json" "$DOFLINX_DIR"
   #*****************************************************************

   #DOFLINX_DIR="${BATOCERA_PLUGIN_PATH}/doflinx"
   #if [ "$machine_arch" = "arm64" ]; then
   #   download_github_file "https://github.com/alinke/pixelcade-linux-builds/blob/main/batocera/doflinx/DLSocket" "DLSocket" "$DOFLINX_DIR"
   #fi

   #if uname -m | grep -q 'x86'; then
   #   download_github_file "https://github.com/alinke/pixelcade-linux-builds/blob/main/batocera/doflinx/x86/DLSocket" "DLSocket" "$DOFLINX_DIR"
   #fi

   chmod a+x ${HOME}/doflinx/DOFLinx
   chmod a+x ${HOME}/doflinx/DOFLinxMsg
   chmod a+x ${DOFLINX_DIR}/DLSocket

      # Check if directory exists and create it if needed
   if [ ! -d "/usr/bin/mame/plugins" ]; then
      mkdir -p /usr/bin/mame/plugins
   fi

   # Create the symlink (will overwrite if already exists)
   if [ ! -L "/usr/bin/mame/plugins/doflinx" ]; then
      ln -sf /userdata/saves/mame/plugins/doflinx /usr/bin/mame/plugins/doflinx
      echo -e "${cyan}[INFO] DOFLinx plugin symlink created successfully${nc}"
   else
      echo -e "${cyan}[INFO] DOFLinx plugin symlink already exists, skipping...${nc}"
   fi
   #ln -sf /userdata/saves/mame/plugins/doflinx /usr/bin/mame/plugins/doflinx
   echo -e "${cyan}[INFO] MAME DOFLinx plugin installed${nc}"
    
   # Determine the correct path based on the Batocera version
   if [ "$batocera_version" = "40" ]; then
        MAME_GENERATOR="$BATOCERA_MAME_GENERATOR_V41"
        echo -e "${cyan}[INFO] Detected Batocera V40${nc}"
   elif [ "$batocera_version" = "41" ]; then
        MAME_GENERATOR="$BATOCERA_MAME_GENERATOR_V41"
        echo -e "${cyan}[INFO] Detected Batocera V41${nc}"
   elif [ "$batocera_version" = "42" ]; then
        MAME_GENERATOR="$BATOCERA_MAME_GENERATOR_V42"
        echo -e "${cyan}[INFO] Detected Batocera V42${nc}"
   else
        # Check which path exists
        if [ -f "$BATOCERA_MAME_GENERATOR_V41" ]; then
            MAME_GENERATOR="$BATOCERA_MAME_GENERATOR_V41"
            echo "Assuming Batocera V41 based on file path"
        elif [ -f "$BATOCERA_MAME_GENERATOR_V42" ]; then
            MAME_GENERATOR="$BATOCERA_MAME_GENERATOR_V42"
            echo "Assuming Batocera V42 based on file path"
        else
            echo "Error: Could not find mameGenerator.py. Please check your Batocera version."
        fi
   fi

   backup_file "$MAME_GENERATOR" "mameGenerator.py.original"
   echo "Modifying $MAME_GENERATOR"
   # Modify the Python mame generator file to add output network and to load the doflinx plugin

   if grep -q "pluginsToLoad += \[ \"doflinx\" \]" "$MAME_GENERATOR"; then
      echo -e "${cyan}[INFO] Skipped: The doflinx plugin is already added${nc}"
   else
      sed -i '/pluginsToLoad = \[\]/a \ \ \ \ \ \ \ \ pluginsToLoad += [ "doflinx" ]' "$MAME_GENERATOR"
      echo -e "${cyan}[INFO] Successfully added doflinx plugin${nc}"
   fi

   if grep -q "commandArray += \[ \"-output\", \"network\" \]" "$MAME_GENERATOR"; then
      echo -e "${cyan}[INFO] Skipped: The network output line is already added${nc}"
   else
      # note that not adding enough spaces will BREAK the python
      sed -i '/if messSysName\[messMode\] == "" or messMode == -1:/i \ \ \ \ \ \ \ \ commandArray += [ "-output", "network" ]' "$MAME_GENERATOR"
      echo -e "${cyan}[INFO] Successfully added -output network command line option${nc}"
   fi

   if [[ -f "$BATOCERA_CONFIG_FIlE" ]]; then
      backup_file "$BATOCERA_CONFIG_FIlE" "batocera.conf.original"
   fi
   #Now let's switch the mame core to stand alone mame from libretro
   if [ ! -f "$BATOCERA_CONFIG_FIlE" ]; then
        echo "Error: $CONFIG_FILE does not exist. Skipping the config to switch to stand alone MAME which you'll need to do manually."
   else 
        if ! grep -q "^$BATOCERA_CONFIG_LINE1$" "$BATOCERA_CONFIG_FIlE"; then
            # Append LINE1 to the file
            echo "$BATOCERA_CONFIG_LINE1" >> "$BATOCERA_CONFIG_FIlE"
            echo -e "${cyan}[INFO] Added: $BATOCERA_CONFIG_LINE1${nc}"
        else
            echo -e "${cyan}[INFO] Skipped: $BATOCERA_CONFIG_LINE1 already exists${nc}"
        fi
        if ! grep -q "^$BATOCERA_CONFIG_LINE2$" "$BATOCERA_CONFIG_FIlE"; then
            # Append LINE2 to the file
            echo "$BATOCERA_CONFIG_LINE2" >> "$BATOCERA_CONFIG_FIlE"
            echo -e "${cyan}[INFO] Added: $BATOCERA_CONFIG_LINE2${nc}"
        else
            echo -e "${cyan}[INFO] Skipped: $BATOCERA_CONFIG_LINE2 already exists${nc}"
        fi
        echo "Batocera Configuration Updated"
   fi

   # Try to make the changes permanent
   if batocera-save-overlay; then
        echo "Changes saved to Batocera overlay"
   else
        echo "Warning: Could not save to overlay. Changes will be restored by custom.sh at next boot."
   fi

else
  echo -e "${cyan}[INFO] Not on Batocera, skipping Batocera setup${nc}"
fi

# Checking for Retropie installation
if [[ -f "$RETROPIE_AUTOSTART_FILE" ]]; then
  echo "${cyan}[INFO]RetroPie Detected${nc}"
  backup_file "$RETROPIE_AUTOSTART_FILE" "autostart.sh.original"
  if grep -q "DOFLinx" "$RETROPIE_AUTOSTART_FILE"; then
      echo-e  "${green}[INFO]${nc}DOFLinx entry already exists in $RETROPIE_AUTOSTART_FILE. Skipping."
  else
      echo -e "${green}[INFO]${nc}Adding DOFLinx to $RETROPIE_AUTOSTART_FILE"
      if grep -q "pixelweb" "$RETROPIE_AUTOSTART_FILE"; then
          sudo sed -i '/pixelweb/a '"$RETROPIE_LINE_TO_ADD" "$RETROPIE_AUTOSTART_FILE"  # insert DOFLinx after the pixelweb line
      else
          echo "$RETROPIE_LINE_TO_ADD" | sudo tee -a "$RETROPIE_AUTOSTART_FILE" > /dev/null
      fi
      echo -e "${green}[INFO]${nc}DOFLinx added to RetroPie autostart"
  fi
  sudo chmod +x "$RETROPIE_AUTOSTART_FILE"
else
  echo -e "${green}[INFO]${nc}Not on RetroPie, skipping RetroPie setup..."
fi

# Initialize arrays to track detected joysticks
DETECTED_JS=()

# Check for controllers and get their joystick numbers
# Xbox controller
if grep -i -q "X-Box" /proc/bus/input/devices; then
    XBOX_JS=$(get_joystick_number "X-Box")
    XBOX_CONNECTED=1
    DETECTED_JS+=($((XBOX_JS - 1)))
else
    XBOX_CONNECTED=0
    XBOX_JS="none"
fi

# USB 2-axis 8-button gamepad
if grep -q "USB,2-axis 8-button gamepad" /proc/bus/input/devices; then
    GAMEPAD_JS=$(get_joystick_number "USB,2-axis 8-button gamepad")
    GAMEPAD_CONNECTED=1
    DETECTED_JS+=($((GAMEPAD_JS - 1)))
else
    GAMEPAD_CONNECTED=0
    GAMEPAD_JS="none"
fi

# Nintendo Switch controller
if grep -i -q "Nintendo Switch" /proc/bus/input/devices; then
    SWITCH_JS=$(get_joystick_number "Nintendo Switch")
    SWITCH_CONNECTED=1
    DETECTED_JS+=($((SWITCH_JS - 1)))
else
    SWITCH_CONNECTED=0
    SWITCH_JS="none"
fi

# Fallback: Check for any joystick devices that weren't specifically detected
# Get a list of all joystick devices
FALLBACK_JS=()
for js_device in /dev/input/js*; do
    if [ -c "$js_device" ]; then
        js_num=${js_device##*/js}
        # Check if this joystick is already detected
        if ! [[ " ${DETECTED_JS[@]} " =~ " ${js_num} " ]]; then
            FALLBACK_JS+=($js_num)
        fi
    fi
done

# If this is a Pixelcade installation, then we'll pre-configure DOFLinx.ini
if [ -d "$HOME/pixelcade" ]; then
  echo "Pixelcade folder found at $HOME/pixelcade"
  
  DOFLINX_INI_FILE="${HOME}/doflinx/config/DOFLinx.ini"

  if [ ! -f "$DOFLINX_INI_FILE" ]; then
    echo "Warning: Config file not found at $DOFLINX_INI_FILE"
    echo "Will attempt to continue with the rest of the script..."
  else
    backup_file "$DOFLINX_INI_FILE" "DOFLinx.ini.original"

    # Add DEBUG=0 if DEBUG isn't already there
    if ! grep -q "^DEBUG=" "$DOFLINX_INI_FILE"; then
      temp_file=$(mktemp)
      echo "#DEBUG=1 will enable debug logging which will show up in DOFLinx.log" > "$temp_file"
      echo "DEBUG=0" >> "$temp_file"
      cat "$DOFLINX_INI_FILE" >> "$temp_file"
      mv "$temp_file" "$DOFLINX_INI_FILE"
    fi
    ESCAPED_HOME=$(echo "$HOME" | sed 's/\//\\\//g')

    # Update PATH_MAME with actual home path, sed can't handle normal variable substitution 
    sed -i "s/^PATH_MAME=.*$/PATH_MAME=${ESCAPED_HOME}\/pixelcade\/DOFLinx\/DOFLinx_MAME\//" "$DOFLINX_INI_FILE"  
    sed -i "s/^PATH_PIXELCADE=.*$/PATH_PIXELCADE=${ESCAPED_HOME}\/pixelcade\//" "$DOFLINX_INI_FILE"
    sed -i "s/^PATH_HI2TXT=.*$/PATH_HI2TXT=${ESCAPED_HOME}\/pixelcade\/hi2txt\//" "$DOFLINX_INI_FILE"

    # Make sure PIXELCADE_GAME_START_HIGHSCORE line is commented out because the Pixelcade Batocera script handles high scores
    sed -i 's|^PIXELCADE_GAME_START_HIGHSCORE=1|#PIXELCADE_GAME_START_HIGHSCORE=1|' "$DOFLINX_INI_FILE"
    grep -q "#PIXELCADE_GAME_START_HIGHSCORE=1" "$DOFLINX_INI_FILE" || echo "#PIXELCADE_GAME_START_HIGHSCORE=1" >> "$DOFLINX_INI_FILE"

   if [ "$batocera" = "true" ]; then
      echo "Batocera detected, updating MAME_FOLDER to /usr/bin/mame/"
      sed -i 's|^MAME_FOLDER=.*$|MAME_FOLDER=/usr/bin/mame/|' "$DOFLINX_INI_FILE"
      sed -i 's|^MAME_HISCORE_FOLDER=.*$|MAME_HISCORE_FOLDER=/userdata/saves/mame/plugins/hiscore/|' "$DOFLINX_INI_FILE"
   else
      echo "Not on Batocera, updating MAME_FOLDER to /usr/games/"
      sed -i 's|^MAME_FOLDER=.*$|MAME_FOLDER=/usr/games/|' "$DOFLINX_INI_FILE"
   fi

   # Now let's set MAME_PLUGIN_LOOPS which effects performance on Linux, the bigger the number the slower the polling and hence better performance
   if [ "$pi5" = "true" ] || uname -m | grep -q 'x86'; then
      if grep -q "^MAME_PLUGIN_LOOPS=" "$DOFLINX_INI_FILE"; then
        # If it exists, set it to 1
        sed -i "s/^MAME_PLUGIN_LOOPS=.*$/MAME_PLUGIN_LOOPS=1/" "$DOFLINX_INI_FILE"
        echo -e "${cyan}[INFO] Updated MAME_PLUGIN_LOOPS to 1 for Pi5 or x86${nc}"
        
        if ! grep -q "^#Set MAME_PLUGIN_LOOPS" "$DOFLINX_INI_FILE"; then
          sed -i "/^MAME_PLUGIN_LOOPS=.*$/i #Set MAME_PLUGIN_LOOPS to a higher number for better performance for low powered devices, lower number down to 1 equals faster DOFLinx polling" "$DOFLINX_INI_FILE"
        fi
      else
        sed -i "/^PATH_HI2TXT=.*$/a #Set MAME_PLUGIN_LOOPS to a higher number for better performance for low powered devices, lower number down to 1 equals faster DOFLinx polling\nMAME_PLUGIN_LOOPS=1" "$DOFLINX_INI_FILE"
        echo -e "${cyan}[INFO] Added MAME_PLUGIN_LOOPS=1 for Pi5 or x86${nc}"
      fi
    else
      if ! grep -q "^MAME_PLUGIN_LOOPS=" "$DOFLINX_INI_FILE"; then
        sed -i "/^PATH_HI2TXT=.*$/a #Set MAME_PLUGIN_LOOPS to a higher number for better performance for low powered devices, lower number down to 1 equals faster DOFLinx polling\nMAME_PLUGIN_LOOPS=2" "$DOFLINX_INI_FILE"
        echo -e "${cyan}[INFO] Added MAME_PLUGIN_LOOPS=2 to DOFLinx.ini${nc}"
      else
        echo -e "${cyan}[INFO] MAME_PLUGIN_LOOPS already exists in DOFLinx.ini, not modifying${nc}"
        if ! grep -q "^#Set MAME_PLUGIN_LOOPS" "$DOFLINX_INI_FILE"; then
          sed -i "/^MAME_PLUGIN_LOOPS=.*$/i #Set MAME_PLUGIN_LOOPS to a higher number for better performance for low powered devices, lower number down to 1 equals faster DOFLinx polling" "$DOFLINX_INI_FILE"
        fi
      fi
   fi

   # If we've got a game pad controller, let's set the coin and player start button numbers
   LINK_BUT_CN=$(grep -E "^LINK_BUT_CN=" "$DOFLINX_INI_FILE" | tr -d '\r' | tr -d '\n')
   LINK_BUT_P1=$(grep -E "^LINK_BUT_P1=" "$DOFLINX_INI_FILE" | tr -d '\r' | tr -d '\n')
   
   # Initialize with default values if lines don't exist
   if [ -z "$LINK_BUT_CN" ]; then
      LINK_BUT_CN="LINK_BUT_CN=0000,Orange,6"
   fi
   if [ -z "$LINK_BUT_P1" ]; then
      LINK_BUT_P1="LINK_BUT_P1=0000,Cyan,2"
   fi

   # Clear any existing joystick entries (anything with J0)
   LINK_BUT_CN=$(echo "$LINK_BUT_CN" | sed -E 's/,0000,Orange,J0[0-9][0-9][0-9]//g')
   LINK_BUT_P1=$(echo "$LINK_BUT_P1" | sed -E 's/,0000,Cyan,J0[0-9][0-9][0-9]//g')
   
   # For USB 2-axis 8-button gamepad
   if [ "$GAMEPAD_JS" != "none" ]; then
      LINK_BUT_CN="${LINK_BUT_CN},0000,Orange,J0${GAMEPAD_JS}06"
      LINK_BUT_P1="${LINK_BUT_P1},0000,Cyan,J0${GAMEPAD_JS}07"
   fi
   
   # For Nintendo Switch controller
   if [ "$SWITCH_JS" != "none" ]; then
      LINK_BUT_CN="${LINK_BUT_CN},0000,Orange,J0${SWITCH_JS}09"
      LINK_BUT_P1="${LINK_BUT_P1},0000,Cyan,J0${SWITCH_JS}08"
   fi
   
   # For Xbox controller
   if [ "$XBOX_JS" != "none" ]; then
      LINK_BUT_CN="${LINK_BUT_CN},0000,Orange,J0${XBOX_JS}06"
      LINK_BUT_P1="${LINK_BUT_P1},0000,Cyan,J0${XBOX_JS}07"
   fi
   
   # For fallback joysticks (with default button mappings)
   for js_num in "${FALLBACK_JS[@]}"; do
      # Add 1 to convert from js0->1, js1->2, etc.
      js_logical=$((js_num + 1))
      # Default mappings: button 6 for coin, button 7 for play
      LINK_BUT_CN="${LINK_BUT_CN},0000,Orange,J0${js_logical}06"
      LINK_BUT_P1="${LINK_BUT_P1},0000,Cyan,J0${js_logical}07"
      echo -e "${cyan}[INFO] Added fallback button configurations for unknown joystick at js${js_num} (configured as joystick ${js_logical})${nc}"
   done
   
   sed -i "s/^LINK_BUT_CN=.*$/${LINK_BUT_CN//\//\\/}/" "$DOFLINX_INI_FILE" 2>/dev/null || true
   if ! grep -q "^LINK_BUT_CN=" "$DOFLINX_INI_FILE"; then
      echo "$LINK_BUT_CN" >> "$DOFLINX_INI_FILE"
   fi
   
   sed -i "s/^LINK_BUT_P1=.*$/${LINK_BUT_P1//\//\\/}/" "$DOFLINX_INI_FILE" 2>/dev/null || true
   if ! grep -q "^LINK_BUT_P1=" "$DOFLINX_INI_FILE"; then
      echo "$LINK_BUT_P1" >> "$DOFLINX_INI_FILE"
   fi

    echo -e "${cyan}[INFO] DOFLinx.ini has been updated${nc}"
  fi
else
  echo "${red}WARNING: Pixelcade not found at $HOME/pixelcade, please install Pixelcade first${nc}"
fi

echo -e "${cyan}[INFO] Cleaning up${nc} "
cd ${HOME}/
rm -r ${HOME}/doflinx/temp

if [[ $install_successful == "true" ]]; then
   echo -e "${cyan}[INFO] DOFLinx in game MAME effects installed${nc}"
    if [ "$batocera" = "true" ]; then
         # Get the MAME version - handling different possible output formats
         MAME_OUTPUT=$(/usr/bin/mame/mame -version)
         # First try to extract just the version number
         if echo "$MAME_OUTPUT" | grep -q -E '^[0-9]+\.[0-9]+'; then
            # Format like "0.268 (unknown)" - version is the first word
            MAME_VERSION=$(echo "$MAME_OUTPUT" | awk '{print $1}')
         elif echo "$MAME_OUTPUT" | grep -q -E 'MAME [0-9]+\.[0-9]+'; then
            # Format like "MAME 0.268 (Jun 12 2024)" - version is the second word
            MAME_VERSION=$(echo "$MAME_OUTPUT" | awk '{print $2}')
         else
            # Fallback - get the first number that looks like a version
            MAME_VERSION=$(echo "$MAME_OUTPUT" | grep -o -E '[0-9]+\.[0-9]+' | head -1)
         fi
         echo -e "${bg_magenta}${white}Please note your MAME core in Batocera has been switched to stand alone MAME version ${bold}${MAME_VERSION}${normal}${white}, ensure your MAME romset is compatible with this version${nc}"
    fi
   echo -e "${cyan}[INFO] DOFLinx guide can be found at https://doflinx.github.io/docs/${nc}"
   echo -e "${cyan}[INFO] Support can be found at http://www.vpforums.org/index.php?showforum=104${nc}"
   echo -e "${cyan}[INFO] Gamepad controller(s) detected and configured for coin input and player start in "$DOFLINX_INI_FILE":${nc}"
   [ "$XBOX_CONNECTED" = "1" ] && echo -e "${cyan}[INFO]   * Xbox controller (Joystick ${XBOX_JS})${nc}"
   [ "$GAMEPAD_CONNECTED" = "1" ] && echo -e "${cyan}[INFO]   * USB 2-axis 8-button gamepad (Joystick ${GAMEPAD_JS})${nc}"
   [ "$SWITCH_CONNECTED" = "1" ] && echo -e "${cyan}[INFO]   * Nintendo Switch controller (Joystick ${SWITCH_JS})${nc}"

   # Show fallback joysticks in the summary
   for js_num in "${FALLBACK_JS[@]}"; do
      echo -e "${cyan}[INFO]   * Unknown joystick at js${js_num} (Joystick $((js_num + 1)))${nc}"
   done

   if [ "$XBOX_CONNECTED" != "1" ] && [ "$GAMEPAD_CONNECTED" != "1" ] && [ "$SWITCH_CONNECTED" != "1" ] && [ ${#FALLBACK_JS[@]} -eq 0 ]; then
      echo -e "${cyan}[INFO]   * No gamepads detected${nc}"
   fi
   echo -e "${cyan}--------------------------------${nc}"
   echo -e "${cyan}[INFO] If you want to uninstall DOFLinx, re-run this script and append: undo${nc}"
else
  echo -e "${bold_red}[ERROR] DOFLinx installation failed${nc}"
fi

echo -e "${cyan}[INFO] Getting the latest DOFLinx MAME game specific defintiions (.MAME files)...${nc}"
cd ${HOME}/pixelcade && ./pixelweb -update-doflinx

echo -e "\n${magenta}Please now reboot and DOFLinx effects will be loaded automatically on startup${nc}"
echo -e "${magenta}Would you like to reboot now? (y/n)${nc}"

read -r answer

case ${answer:0:1} in
    y|Y )
        echo -e "${magenta}System will reboot now...${nc}"
        sleep 2
        reboot || sudo reboot
        ;;
    * )
        echo -e "${red}Reboot skipped. Please remember to reboot your system later.${nc}"
        pause
        echo -e "${cyan}[INFO] Now Starting DOFLinx...${nc}"
        cd ${HOME}/doflinx && ./DOFLinx PATH_INI=${HOME}/doflinx/config/DOFLinx.ini &
        ;;
esac

echo ""