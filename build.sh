#!/bin/sh
set -o nounset
set -o errexit
#set -o xtrace

# Configurations
BOX="debian-squeeze-64"
BASE_NAME="debian-6.0.5-amd64-netinst.iso"
ISO_URL="http://cdimage.debian.org/debian-cd/current/amd64/bt-cd/$BASE_NAME.torrent"
ISO_SHA512="d8c2e1f6b70892bb8b934344dc5728610307c0658629d24ac95be7c944064561897b2a1e929ad33148432abf2aeaedfcd58da5a0d027d3b96ff9a9af727711fc"

# location, location, location
FOLDER_BASE=$(pwd)
FOLDER_ISO="${FOLDER_BASE}/iso"
FOLDER_BUILD="${FOLDER_BASE}/build"
FOLDER_VBOX="${FOLDER_BUILD}/vbox"
FOLDER_ISO_CUSTOM="${FOLDER_BUILD}/iso/custom"
FOLDER_ISO_INITRD="${FOLDER_BUILD}/iso/initrd"

ISO_FILENAME="${FOLDER_ISO}/${BASE_NAME}"
INITRD_FILENAME="${FOLDER_ISO}/initrd.gz"
ISO_GUESTADDITIONS="/usr/share/virtualbox/VBoxGuestAdditions.iso"

# make sure we have dependencies 
hash mkisofs 2>/dev/null || {
	echo >&2 "ERROR: mkisofs not found. Install it by typing 'sudo aptitude install mkisofs'. Aborting."
	exit 1
}
hash transmission-cli 2>/dev/null || {
	echo >&2 "ERROR: transmission-cli not found. Install it by typing 'sudo aptitude install transmission-cli'. Aborting."
	exit 1
}
hash file-roller 2>/dev/null || {
	echo >&2 "ERROR: file-roller not found. Install it by typing 'sudo aptitude install file-roller'. Aborting."
	exit 1
}
if [ ! -f $ISO_GUESTADDITIONS ]; then
  echo "ERROR: VirtualBoxGuestAdditions.iso not found. Install it by typing 'sudo aptitude install virtualbox-guest-additions-iso'. Aborting."
  exit 1
fi

# start with a clean slate
if [ -d "${FOLDER_BUILD}" ]; then
  echo "Cleaning build directory ..."
  chmod -R u+w "${FOLDER_BUILD}"
  rm -rf "${FOLDER_BUILD}"
  mkdir -p "${FOLDER_BUILD}"
fi

# Setting things back up again
mkdir -p "${FOLDER_ISO}"
mkdir -p "${FOLDER_BUILD}"
mkdir -p "${FOLDER_VBOX}"
mkdir -p "${FOLDER_ISO_CUSTOM}"
mkdir -p "${FOLDER_ISO_INITRD}"

# download the installation disk if you haven't already or it is corrupted somehow
if [ ! -e "${ISO_FILENAME}" ]; then
  echo "Downloading $(basename ${ISO_URL}) ..."
  transmission-cli --download-dir "${FOLDER_ISO}" "${ISO_URL}"

  # make sure download is right...
  ISO_HASH=$(sha512sum "${ISO_FILENAME}" | cut -d" " -f 1)
  if [ "${ISO_SHA512}" != "${ISO_HASH}" ]; then
    echo "ERROR: SHA512 does not match. Got ${ISO_HASH} instead of ${ISO_SHA512}. Aborting."
    exit 1
  fi
fi

# customize it
echo "Creating Custom ISO"
if [ ! -e "${FOLDER_ISO}/custom.iso" ]; then
  ID_USER=$(id -u)
  ID_GROUP=$(id -g)

  echo "Unpacking downloaded ISO ..."
  sudo su <<EOC
  file-roller -e "${FOLDER_ISO_CUSTOM}" "${ISO_FILENAME}"

  # backup initrd.gz
  echo "Backing up current init.rd ..."
  chmod u+w "${FOLDER_ISO_CUSTOM}/install.amd" "${FOLDER_ISO_CUSTOM}/install.amd/initrd.gz"
  mv "${FOLDER_ISO_CUSTOM}/install.amd/initrd.gz" "${FOLDER_ISO_CUSTOM}/install.amd/initrd.gz.org"

  # stick in our new initrd.gz
  echo "Installing new initrd.gz ..."
  cd "${FOLDER_ISO_INITRD}"
  gunzip -c "${FOLDER_ISO_CUSTOM}/install.amd/initrd.gz.org" | cpio -id
  cd "${FOLDER_BASE}"
  cp preseed.cfg "${FOLDER_ISO_INITRD}/preseed.cfg"
  cd "${FOLDER_ISO_INITRD}"
  find . | cpio --create --format='newc' | gzip > "${FOLDER_ISO_CUSTOM}/install.amd/initrd.gz"
  cd "${FOLDER_BASE}"
  rm -r "${FOLDER_ISO_INITRD}"

  # clean up permissions
  echo "Cleaning up Permissions ..."
  chmod u-w "${FOLDER_ISO_CUSTOM}/install.amd" "${FOLDER_ISO_CUSTOM}/install.amd/initrd.gz" "${FOLDER_ISO_CUSTOM}/install.amd/initrd.gz.org"

  # replace isolinux configuration
  echo "Replacing isolinux config ..."
  chmod u+w "${FOLDER_ISO_CUSTOM}/isolinux" "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"
  cp isolinux.cfg "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"  
  chmod u+w "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.bin"

  # add late_command script
  echo "Add late_command script ..."
  chmod u+w "${FOLDER_ISO_CUSTOM}"
  cp "${FOLDER_BASE}/late_command.sh" "${FOLDER_ISO_CUSTOM}"
  
  echo "Running mkisofs ..."
  mkisofs -r -V "Custom Debian Install CD" \
    -cache-inodes -quiet \
    -J -l -b isolinux/isolinux.bin \
    -c isolinux/boot.cat -no-emul-boot \
    -boot-load-size 4 -boot-info-table \
    -o "${FOLDER_ISO}/custom.iso" "${FOLDER_ISO_CUSTOM}"

  # cleanup
  rm -r "${FOLDER_ISO_CUSTOM}"
  chown ${ID_USER}:${ID_GROUP} "${FOLDER_ISO}/custom.iso"
EOC

fi

echo "Creating VM Box..."
# create virtual machine
if ! VBoxManage showvminfo "${BOX}" >/dev/null 2>&1; then
  VBoxManage createvm \
    --name "${BOX}" \
    --ostype Debian_64 \
    --register \
    --basefolder "${FOLDER_VBOX}"

  VBoxManage modifyvm "${BOX}" \
    --memory 256 \
    --boot1 dvd \
    --boot2 disk \
    --boot3 none \
    --boot4 none \
    --vram 12 \
    --pae off \
    --rtcuseutc on

  VBoxManage storagectl "${BOX}" \
    --name "IDE Controller" \
    --add ide \
    --controller PIIX4 \
    --hostiocache on

  VBoxManage storageattach "${BOX}" \
    --storagectl "IDE Controller" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium "${FOLDER_ISO}/custom.iso"

  VBoxManage storagectl "${BOX}" \
    --name "SATA Controller" \
    --add sata \
    --controller IntelAhci \
    --sataportcount 1 \
    --hostiocache off

  VBoxManage createhd \
    --filename "${FOLDER_VBOX}/${BOX}/${BOX}.vdi" \
    --size 10240

  VBoxManage storageattach "${BOX}" \
    --storagectl "SATA Controller" \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium "${FOLDER_VBOX}/${BOX}/${BOX}.vdi"

  VBoxManage startvm "${BOX}"

  echo -n "Waiting for installer to finish "
  while VBoxManage list runningvms | grep "${BOX}" >/dev/null; do
    sleep 20
    echo -n "."
  done
  echo ""

  # Forward SSH
  VBoxManage modifyvm "${BOX}" \
    --natpf1 "guestssh,tcp,,2222,,22"

  # Attach guest additions iso
  VBoxManage storageattach "${BOX}" \
    --storagectl "IDE Controller" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium "${ISO_GUESTADDITIONS}"

  VBoxManage startvm "${BOX}"

  # get private key
  wget -O "${FOLDER_BUILD}/id_rsa" "https://raw.github.com/mitchellh/vagrant/master/keys/vagrant"
  chmod 600 "${FOLDER_BUILD}/id_rsa"

  # install virtualbox guest additions
  echo -n "Waiting for machine to boot up "
  sleep 20
  echo -n "."
  echo "Installing VirtualBox guest additions ..."
  ssh -i "${FOLDER_BUILD}/id_rsa" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 2222 vagrant@127.0.0.1 "sudo mount /dev/cdrom /media/cdrom; sudo sh /media/cdrom/VBoxLinuxAdditions.run; sudo umount /media/cdrom; sudo shutdown -h now"
  echo -n "Waiting for machine to shut off "
  while VBoxManage list runningvms | grep "${BOX}" >/dev/null; do
    sleep 20
    echo -n "."
  done
  echo ""

  VBoxManage modifyvm "${BOX}" --natpf1 delete "guestssh"

  # Detach guest additions iso
  echo "Detach guest additions ..."
  VBoxManage storageattach "${BOX}" \
    --storagectl "IDE Controller" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium emptydrive
fi

echo "Building Vagrant Box ..."
vagrant package --base "${BOX}" && mv "package.box" "${BOX}.box"

# clean up build vm
VBoxManage unregistervm "${BOX}" --delete

# references:
# http://blog.ericwhite.ca/articles/2009/11/unattended-debian-lenny-install/
# http://cdimage.ubuntu.com/releases/precise/beta-2/
# http://www.imdb.com/name/nm1483369/
# http://vagrantup.com/docs/base_boxes.html
