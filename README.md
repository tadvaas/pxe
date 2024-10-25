# Software

## Boot firmware: iPXE
### UEFI 
- uefi.pxe
- autoexec.ipxe
```
dhcp
chain [http-path]/boot.ipxe
```
### Legacy

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
