#!/usr/bin/env bash

UI_URL_FILE=./UI_URL
LIST_TYPE=required # required or full

root_only() {
if [ "$EUID" -ne 0 ]
	  then echo "Please run as root"
		    exit
fi
}

check_tools_installed() {
  app_name=$1
  
  echo "Checking prerequisites:"
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

download_firmware() {
  get_url_info

  echo -e "\nProduct: $FW_PLATFORM-$FW_VERSION"
  if [ -f "$FW_FILE" ]; then
    echo "Found $FW_FILE"
  else 
    wget -O $FW_FILE $UI_URL
  fi
}

process_firmware() {
  FW_FILE="fw-UCKG2-3.0.17.bin"
  # Extract content
#  binwalk --extract --run-as=root $FW_FILE

  # Copy version file
  cp -vb _$FW_FILE.extracted/squashfs-root/usr/lib/version .

  # Extract packages from Ubiquity to package list file
  dpkg-query --admindir=_$FW_FILE.extracted/squashfs-root/var/lib/dpkg/ -W -f='${package} | ${Maintainer}\n' | grep -E "@ubnt.com|@ui.com" | cut -d "|" -f 1 > packages.full.list

  while read pkg; do
    dpkg-repack --root=_$FW_FILE.extracted/squashfs-root --arch=arm64 ${pkg}
  done < packages.$LIST_TYPE.list

  # Move all the deb packages to packages
  mkdir dpkg
  mv -v *_arm64.deb dpkg/


  # Cleanup
  #rm -Rf _$FW_FILE.extracted 

}

main() {
  prerequisites 
  get_url_info
  #download_firmware
  #process_firmware 

}

main
