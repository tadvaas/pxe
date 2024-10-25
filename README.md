# Software
- Boot firmware: iPXE
  - UEFI
  - Legacy
- HTTP server: nginx
- TFTP server: tftpd-hpa
- DHCP server: Kea on pfSense
- Network share: Samba
- WinPE files
  - Extract image using DISM
  - Download NIC drives
  - Add drivers to image
  - Create the image
  - Files go to ~/html/win11

- Auto start install files
  - install.bat
  - winpeshl.ini

- Windows 11 installation files
  - Download ISO and copy from Microsoft
  - autounattend.xml
