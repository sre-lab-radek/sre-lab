#!/usr/bin/env bash
set -euo pipefail

IMG_DIR=/var/lib/libvirt/images
BASE=$IMG_DIR/noble-base.img
PUBKEY=$(cat ~/.ssh/lab_vm.pub)

for NAME in web1 web2 db1; do
  echo "==> $NAME"
  sudo qemu-img create -f qcow2 -F qcow2 -b "$BASE" "$IMG_DIR/$NAME.qcow2" 15G

  cat > /tmp/user-data <<USERDATA
#cloud-config
hostname: $NAME
users:
  - name: sre
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $PUBKEY
USERDATA

  printf "instance-id: %s\nlocal-hostname: %s\n" "$NAME" "$NAME" > /tmp/meta-data
  cloud-localds /tmp/$NAME-seed.iso /tmp/user-data /tmp/meta-data
  sudo mv /tmp/$NAME-seed.iso "$IMG_DIR/$NAME-seed.iso"

  sudo virt-install --name "$NAME" --memory 2048 --vcpus 2 \
    --disk path="$IMG_DIR/$NAME.qcow2",format=qcow2 \
    --disk path="$IMG_DIR/$NAME-seed.iso",device=cdrom \
    --os-variant ubuntu24.04 --network network=default \
    --import --noautoconsole
done