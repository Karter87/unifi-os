#!/usr/bin/env bash

UI_URL_FILE=./UI_URL
LIST_TYPE=required # full, required, test or ui
FOLDER_DPKG=../source/tmp/dpkg

root_only() {
if [ "$EUID" -ne 0 ]
	  then echo "Please run as root"
		    exit
fi
}

check_tools_installed() {
  app_name=$1
  
  echo -e "\nChecking prerequisites:"
  for app in $app_name; do
    app_check=$(which $app)
    if [ -f "$app_check" ]; then
      echo "- $app ($app_check)"
    else
      echo "ERROR: Not Found $app, exiting..."
      exit 1
    fi
  done
}

prerequisites() {
  #clear
  root_only
  check_tools_installed "dpkg binwalk dpkg-repack"
}

get_url_info() {
  echo -e "\nGetting URL information:"
  # Check if download link file exists
  if [ -f "$UI_URL_FILE" ]; then
    UI_URL=$(cat $UI_URL_FILE)
    
    # Check if the URL is in the URL File
    if [ -z "$UI_URL" ]; then
      echo "Please paste the link in $UI_URL_FILE"
      exit 1
    fi
  
  # If not exist, create file and exit
  else
    echo "ERROR: Not found $UI_URL_FILE: Creating file"
    echo "Please paste the link in $UI_URL_FILE"
    touch $UI_URL_FILE
    exit 1
  fi
 
  # Get Filename 
  UI_BINNAME=$(echo $UI_URL | rev | cut -d '/' -f 1 | rev)
  FW_PLATFORM=$(echo $UI_BINNAME | cut -d '-' -f 2)
  FW_VERSION=$(echo $UI_BINNAME | cut -d '-' -f 3)

  FW_FILE="fw-$FW_PLATFORM-$FW_VERSION.bin"
  
  echo -e "- Filename: $UI_BINNAME"
  echo -e "- Platform: $FW_PLATFORM-$FW_VERSION"
  export FW_FILE

}

get_firmware() {
  get_url_info
  
  echo -e "\nSearching for file: $FW_FILE"
  if [ -f "$FW_FILE" ]; then
    echo "- Found Locally ./$FW_FILE"
  else 
    echo "- Downloading from $UI_URL"
    wget -O $FW_FILE $UI_URL
  fi
}



fw_extract() {
  if [ -d "_$FW_FILE.extracted/" ]; then
    echo "- WARNING: $FW_FILE already extracted, skipping binwalk, please remove folder"
  else
    echo "- Extracting $FW_FILE"
    binwalk --extract --run-as=root $FW_FILE
  fi
}

fw_repack() {
  # Extract packages from Ubiquity to package list file
  
  ADMIN_DIR_DPKGS=_$FW_FILE.extracted/squashfs-root/var/lib/dpkg/
  if [ -d $ADMIN_DIR_DPKGS ]; then
    echo "- Get packages list maintened by Ubiquiti"
    dpkg-query --admindir=$ADMIN_DIR_DPKGS -W -f='${package} | ${Maintainer}\n' | grep -E "@ubnt.com|@ui.com" | cut -d "|" -f 1 > packages.ui.list

    echo "- repacking with packages.$LIST_TYPE.list"
    while read pkg; do
      dpkg-repack --root=_$FW_FILE.extracted/squashfs-root --arch=arm64 ${pkg}
    done < packages.$LIST_TYPE.list
  else
    echo "- ERROR: $ADMIN_DIR_DPKGS not found, exiting..."
    exit 1
  fi 
}


fw_clean() {
  echo -e "\nCleaning"
}

process_firmware() {
  echo -e "\nProcessing firmware:"
  fw_extract
  fw_repack
}

postprocess_firmware() {
  # Copy version file
  echo -e "\nCopy files:"
  if [ -d "$FOLDER_DPKG" ]; then 
    if [ -d "$FOLDER_DPKG.old" ]; then
      rm -fvR $FOLDER_DPKG.old
    fi
    mv -v $FOLDER_DPKG $FOLDER_DPKG.old
  fi
  
  mkdir -p $FOLDER_DPKG
  mv -v ./*.deb $FOLDER_DPKG 
  
#  mv -v _$FW_FILE.extracted/squashfs-root/usr/lib/version ../source/usr/lib
  fw_clean
}


main() {
  prerequisites 
  #get_url_info
  get_firmware
  process_firmware
  postprocess_firmware
}

main
