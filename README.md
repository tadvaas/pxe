# Software

## Boot firmware: iPXE
### For legacy bios client boots
You will need to compile a custom undionly.kpxe:
```
git clone https://github.com/ipxe/ipxe.git
cd ipxe/src
echo -e 'dhcp\nchain [http-path]/boot.ipxe' > embedded.ipxe
sudo apt install gcc binutils make perl liblzma-dev xz-utils mtools genisoimage syslinux
make bin/undionly.kpxe EMBED=embedded.ipxe
```
### For UEFI bios client boots 

Files:
- uefi.pxe: original to be used is fine
- autoexec.ipxe: edit as follows:
```
dhcp
chain [http-path]/boot.ipxe
```
### Copy firmware TFTP server
```
cp bin-x86_64-efi/ipxe.efi ~/tftp/ipxe.efi
cp bin/undionly.kpxe ~/tftp/undionly.kpxe
```

## HTTP server: nginx

## TFTP server: tftpd-hpa
Edit /etc/default/tftp-hpa:
```
TFTP_USERNAME="oxwet"
TFTP_DIRECTORY="/home/oxwet/tftp/"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure --ipv4 -vvv --map-file /etc/default/tftpd-hpa.map"
```
Edit /etc/default/tftpd-hpa.map
```
rg (.*)[^a-zA-Z0-9]$ \1 # remove all non-ascii characters from the filename
```

## DHCP server: Kea on pfSense

## Network share: Samba
## WinPE files
  - Extract image using DISM
  - Download NIC drives
  - Add drivers to image
  - Create the image
  - Files go to ~/html/win11

## Auto start install files
  - install.bat
  - winpeshl.ini

## Windows 11 installation files
  - Download ISO and copy from Microsoft
  - autounattend.xml
