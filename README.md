# Software

## TFTP server: tftpd-hpa
Create server directory:
```
mkdir ~/tftp/
```

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

## Boot firmware: iPXE
### For legacy bios client boots
You will need to compile a custom undionly.kpxe:
```
git clone https://github.com/ipxe/ipxe.git
cd ipxe/src
```
Create ~/ipxe/src/embedded.ipxe file:
```
dhcp
chain [http-path]/boot.ipxe
```

Install required tools and compile new undionly.pxe boot firmware:
```
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

Install nginx:
```
sudo apt install nginx
```

Edit /etc/nginx/sites-enabled/default:
```
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /home/oxwet/html;
    index index.html;

    server_name _;

    location / {
        autoindex on;  # Enable directory listing for troubleshooting
        try_files $uri $uri/ =404;
    }
}

```

## WinPE iPXE boot firmware & files
```
cd ~/html/win11/ && wget https://github.com/ipxe/wimboot/releases/latest/download/wimboot
```


Create install.bat in ~/html/win11/:
```
@echo off
wpeinit
echo [INFO] Network initialized with wpeinit.
if errorlevel 1 (
    echo [ERROR] Failed to initialize the network with wpeinit.
    pause
    exit /b 1
)

:: Retry loop for network share
:check_share
echo [INFO] Attempting to map network share...
net use Z: \\192.168.0.26\shared\win11 /persistent:no > nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to map network share. Retrying in 30 seconds...
    ping -n 31 127.0.0.1 > nul
    goto check_share
)

echo [INFO] Network share mapped successfully.

Z:\setup.exe

echo [INFO] Windows setup has been started successfully.
```

Create winpeshl.ini in ~/html/win11/:
```
[LaunchApps]
"install.bat"
```

Create boot.ipxe in ~/html/win11/:
```

#!ipxe
:start
menu Boot Menu
item --gap -- ----------------------
item local   Boot from Hard Drive
item win11   Boot Windows Install
item --gap -- ----------------------
item reboot  Reboot
choose --default local --timeout 10000 target && goto ${target}

:local
exit 1

:win11
dhcp
set base-url http://192.168.0.26/win11

kernel wimboot
initrd install.bat                                      install.bat
initrd winpeshl.ini                                     winpeshl.ini
initrd ${base-url}/media/Boot/BCD                       BCD
initrd ${base-url}/media/Boot/boot.sdi                  boot.sdi
initrd ${base-url}/media/sources/boot.wim               boot.wim
boot

:reboot
reboot
```

## DHCP server: Kea on pfSense
Expand **Network Booting** && **Enable Network Booting**
- **Next Server:** [TFTP Server IP]
- **Default BIOS File Name:** undionly.kpxe
- **UEFI 32 bit File Name:** ipxe.efi
- **UEFI 64 bit File Name:** ipxe.efi

## Network share: Samba
Install:
```
sudo apt install samba
```

Edit config file /etc/samba/smb.conf:
```
[global]
map to guest = Bad User
guest account = oxwet

[shared]
path = /home/oxwet/samba
browseable = yes
read only = no
guest ok = yes

```

Create server directory:
```
mkdir ~/samba/
```

## WinPE files
  - Extract image using DISM
  - Download NIC drives
  - Add drivers to image
  - Create the image
  - Copy files to http server ~/html/win11/:
      - media/Boot/BCD
      - media/Boot/boot.sdi
      - media/sources/boot.wim

## Auto start install files
  - install.bat
  - winpeshl.ini

## Windows 11 installation files
  - Download ISO and copy from Microsoft
  - autounattend.xml
