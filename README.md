# Software

## TFTP server: tftpd-hpa
We could use integrated pfSense TFTP server, however, it does not support map files, hence, we are using tftpd-hpa server:
Create server directory:
```
mkdir ~/tftp/
```

Edit /etc/default/tftp-hpa:
```
TFTP_USERNAME="user"
TFTP_DIRECTORY="/home/user/tftp/"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure --ipv4 -vvv --map-file /etc/default/tftpd-hpa.map"
```

In order to solve the bug on some intel cards adding extra non-ascii characters (0xff issue) to the end of file, we need to create a map file and instruct to remove these non-ascii characters by creating the file **/etc/default/tftpd-hpa.map** as follows:
```
echo 'rg (.*)[^a-zA-Z0-9]$ \1' | sudo tee /etc/default/tftpd-hpa.map
```

## Boot firmware: iPXE
### For legacy bios client boots
You will need to compile a custom **undionly.kpxe**, this will allow us to define custom chain loading file and allow iPXE firmware to load further files from http server instead of tftp, this allows for a way faster downloading of WinPE files:
```
git clone https://github.com/ipxe/ipxe.git && cd ipxe/src
```
Create ~/ipxe/src/embedded.ipxe file:
```
echo -e 'dhcp\nchain http://192.168.0.26/boot.ipxe' | tee ~/ipxe/src/embedded.ipxe
```

Install required tools and compile new **undionly.pxe** boot firmware:
```
sudo apt install gcc binutils make perl liblzma-dev xz-utils mtools genisoimage syslinux && make bin/undionly.kpxe EMBED=embedded.ipxe
```

### For UEFI bios client boots 

Files:
- **ipxe.efi**: original to be used is fine (it will automatically read **autoexec.ipxe** for instructions)
    - make the file: 
```
cd ~/ipxe/src && make bin-x86_64-efi/ipxe.efi
```
- **autoexec.ipxe**: this is auto-loaded file that **ipxe.efi** loads as firmware boots, we add instructions to load further files from the server:
```
cp ~/ipxe/src/embedded.ipxe ~/tftp/autoexec.ipxe
```
### Copy firmware TFTP server
```
cp bin-x86_64-efi/ipxe.efi ~/tftp/
cp bin/undionly.kpxe ~/tftp/
```

### Bugs
Some HP laptops and workstations expose multiple NICs in UEFI, including virtual adapters (e.g., wireless, USB LAN, WWAN, Intel AMT/ME, etc.). During PXE boot, these systems successfully download the initial iPXE firmware and chainloaded files using one NIC, but when iPXE transitions into its own driver stage, it may select a different NIC (e.g., eth1 instead of eth0). If the NIC chosen by iPXE is not active or does not have a link, iPXE displays an error such as:
No more network devices
or
No such device

This behaviour happens because ipxe.efi includes iPXE’s own native network drivers, and on some HP systems these native drivers do not correctly match the NIC exposed during firmware PXE.

The fix is to use snp.efi instead of ipxe.efi.
- snp.efi uses the UEFI firmware’s built-in Simple Network Protocol (SNP) driver instead of replacing it with iPXE’s own driver.
- This keeps the NIC consistent throughout the boot process and prevents interface switching and “no device found” errors.

#### How to Generate snp.efi
```
make bin-x86_64-efi/snp.efi EMBED=embedded.ipxe
cp bin-x86_64-efi/snp.efi ~/tftp/
```

UEFI 64-bit File Name: snp.efi in the DHCP server settings


## HTTP server: nginx

To server WinPE files we install nginx http server:
```
sudo apt install nginx
```

Create a directory where nginx will serve files from:
```
mkdir ~/html/
```

Edit /etc/nginx/sites-enabled/default:
```
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /home/user/html;
    index index.html;

    server_name _;

    location / {
        autoindex on;  # Enable directory listing for troubleshooting
        try_files $uri $uri/ =404;
    }
}

```

## vsftpd server conf file

```
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
secure_chroot_dir=/var/run/vsftpd/empty

# Recommended for ShredOS uploads
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000

utf8_filesystem=YES
```

## WinPE iPXE boot firmware & files
wimboot is a small boot loader that allows iPXE to load and boot .wim (Windows Imaging Format) files, which are commonly used for deploying Windows operating systems:
```
cd ~/html/win11/ && wget https://github.com/ipxe/wimboot/releases/latest/download/wimboot
```

This batch script automates initialisation in a WinPE environment by setting up network and storage drivers, attempting to map a network share drive (Z:) to a specified path (\\192.168.0.26\shared\win11), and starting an unattended Windows setup if successful. First, it verifies network initialisation with wpeinit, exiting on failure. Then, in a retry loop, it maps the network share, reattempting every 30 seconds if unsuccessful. Once mapped, it launches setup.exe from the network drive with an unattended setup file (unattend.xml), allowing Windows installation to proceed without user input:

[install.bat](/html/win11/install.bat)

Create winpeshl.ini in ~/html/win11/:
```
[LaunchApps]
"install.bat"
```

Create boot.ipxe in ~/html/win11/:

[boot.ipxe](/html/boot.ipxe)

## DHCP server: Kea on pfSense
Expand **Network Booting** && **Enable Network Booting**
- **Next Server:** 192.168.0.26
- **Default BIOS File Name:** undionly.kpxe or snp.efi
- **UEFI 32 bit File Name:** ipxe.efi or snp.efi
- **UEFI 64 bit File Name:** ipxe.efi or snp.efi

## Booting ShredOS with secure boot enabled

### Concept
UEFI Secure Boot -> shim.efi (MS-signed) -> grubx64.efi (your signed iPXE) -> embedded.ipxe → loads your boot.ipxe -> iPXE loads ShredOS/Ubuntu/etc via shim command

### Create a working directory
```
mkdir -p ~/ipxe-sb && cd ~/ipxe-sb
```

### Get the Microsoft-signed shim & MOK Manager
```
sudo apt install shim-signed
sudo cp /usr/lib/shim/shimx64.efi.signed ~/ipxe-sb/shim.efi
sudo cp /usr/lib/shim/mmx64.efi ~/ipxe-sb/mmx64.efi
```

### Create your iPXE signing key (MOK key)
```
openssl genrsa -out vendor.key 2048

openssl req -x509 -new -nodes \
  -key vendor.key \
  -subj "/CN=My iPXE Vendor Key/" \
  -days 3650 \
  -out vendor.crt
 
openssl x509 -in vendor.crt -outform DER -out ENROLL_THIS_KEY_IN_MOK_MANAGER.cer
```

### Sign iPXE and rename it to grubx64.efi
```
sbsign --key vendor.key --cert vendor.crt \
  --output grubx64.efi bin-x86_64-efi/ipxe.efi
```

### Sign shredos image
```
cp ~/html/shredos/boot/shredos shredos.unsigned
sbsign --key vendor.key --cert vendor.crt --output shredos.signed shredos.unsigned
cp shredos.signed ~/html/shredos/boot/shredos
```

### Ad files to TFTP server
```
cp shim.efi ~/tftp/
cp mmx64.efi ~/tftp/
cp grubx64.efi ~/tftp/
cp /usr/lib/shim/fbx64.efi ~/tftp/revocations.efi
```

### DHCP server config
UEFI 64 bit File Name = shim.efi

### Adjust iPXE boot menu file (boot.ipxe)
Load shim.efi before any signed Linux kernel:

Example for ShredOS:
```
:shredos
dhcp
shim tftp://192.168.0.26/shim.efi
kernel ${base-url}/shredos/boot/shredos ...
boot
```

### Prepare USB with key
- Format any USB as FAT32
- Copy ENROLL_THIS_KEY_IN_MOK_MANAGER.cer to root

### First secure boot key enrollment
- The machine will come up with error
- Insert USB with ENROLL_THIS_KEY_IN_MOK_MANAGER.cer
- Use MOK Manager to enroll KEY
- Reboot
- Smooth sailing from now on

## Update ShredOS, re-sign and re-deploy

### Directories
```mkdir -p ~/work-shredos/{img,downloads,tmp}```

### Download
https://github.com/PartialVolume/shredos.x86_64/releases/

### Copy
```LOOP=$(sudo losetup --find --show -Pf ~/work-shredos/downloads/shredos-*.img)```
```lsblk "$LOOP"```
```sudo mount -o ro ${LOOP}p1 ~/work-shredos/img```
```cp -a ~/work-shredos/img/. ~/work-shredos/tmp/```
```sudo umount ~/work-shredos/img```
```sudo losetup -d "$LOOP"```

### Sign
cd ~/work-shredos/tmp
mv bzImage bzImage.original
sbsign --key ~/ipxe-sb/vendor.key --cert ~/ipxe-sb/vendor.crt --outout bzImage.signed bzImage.original
sbverify --list bzImage.signed
mv bzImage.signed bzImage

### Deploy
mkdir ~/html/shredos_0.40/
cp -r ~/work-shredos/tmp/* ~/html/shredos_0.40/
boot.ipxe -> ${base-url}/shredos_0.40/boot/bzImage

## Network share: Samba
Install:
```
sudo apt install samba
```

Edit config file /etc/samba/smb.conf:
```
[global]
map to guest = Bad User
guest account = user

[shared]
path = /home/user/samba
browseable = yes
read only = no
guest ok = yes

```

Create server directory:
```
mkdir ~/samba/
```

## WinPE files
  - Download & install Windows Deployment and Imaging Tools Environment
  - Extract image using DISM ```copype amd64 C:\WinPE_amd64```
  - Mount the image ```Dism /Mount-Image /ImageFile:C:\WinPE_amd64\media\sources\boot.wim /Index:1 /MountDir:C:\WinPE_amd64\mount```
  - Add optional features Scripting/WinPE-WMI and Startup/WinPE-SecureStartup into the WinPE image for the Windows 11 installer to start successfully
      - ```Dism /Image:C:\WinPE_amd64\mount /Add-Package /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-WMI.cab"```
      - ```Dism /Image:C:\WinPE_amd64\mount /Add-Package /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-Scripting.cab"```
      - ```Dism /Image:C:\WinPE_amd64\mount /Add-Package /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-SecureStartup.cab"```
      - ```Dism /Image:C:\WinPE_amd64\mount /Add-Package /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-NetFX.cab"```
  - Download NIC drivers and extract them
  - Add extracted drivers to image
      - ```Dism /Image:C:\WinPE_amd64\mount /Add-Driver /Driver:C:\Drivers /Recurse```
  - Create the image
      - ```Dism /Unmount-Image /MountDir:C:\WinPE_amd64/mount /Commit```
  - Copy files to http server ~/html/win11/:
      - media/Boot/BCD
      - media/Boot/boot.sdi
      - media/sources/boot.wim

## Windows 11 installation files
  - Download ISO and copy from Microsoft
  - Host extracted ISO files on samba share ~/samba/win11/
  - Create answer files for unattended installations and copy to samba share ~/samba/win11/
    - Create using [schneegans unattended generator](https://schneegans.de/windows/unattend-generator/)
        - Partitioning and formatting:
            - Manual: Partition the disk interactively during Windows Setup
            - Auto for UEFI: Let Windows Setup wipe, partition and format your hard drive (more specifically, disk 0) using these settings: GPT
            - Auto for Legacy (PCBIOS): MBR
    - For auto installations you need to add ```<WillShowUI>OnError</WillShowUI>``` to the following section, so that it looks like this:
```
</InstallTo>
<WillShowUI>OnError</WillShowUI>
```


## Download Windows and create via UUPD

[Download UUPD](https://uupdump.net/fetchupd.php?arch=amd64&ring=retail)
- Browse for latest version (x64, skip the *Cumulative*)
- Language English (United Kingdom) [**This is important!**]
- Edition Windows Pro (Only)
- Download method: *Download and convert to ISO*
- Conversion options: All except *Use solid (ESD) compression*

```
mkdir C:\UUPD
notepad C:\UUPD\ConvertConfig.ini
```

1. Edit the following in `ConvertConfig.ini`:
```
[convert-UUP]
AutoStart    =3
SkipISO      =1

[Store_Apps]
SkipApps     =1
CustomList   =1
```

2. Edit ```CustomAppsList.txt``` to exclude all non-wanted apps

3. Download and compile install.wim:

4. Run as administrator: ```uup_download_windows.cmd```

5. Place install.wim to /samba/win11/sources/ (overwrite)


# Appendix 

## For DELL R8153 v1
- Create USB iPXE boot file ```cd src/ && make bin-x86_64-efi/ecm.usb```
- Write ecm.usb to USB dongle using Rufus
- Make sure **Secure Boot** is disabled
- Make sure **UEFI Ethernet Stack** is enabled
- Disconnect all USB ethernet adapters
- Boot the PC using UEFI into the USB dongle (F12)
- Get into iPXE command line using Ctrl + B
- Connect the USB ethernet adapter
- Issue a command ```ifopen```
- Issue a command ```dhcp```
- Issue a command ```chain http://192.168.0.26/win11/boot.pxe```
- Proceed as normal thereafter

## For DELL R8153 v2
- Enter setup whilst booting (F2) 
    - Disable **Secure Boot**
    - Disable **UEFI Ethernet Stack**
- Connect USB dongle with ecm.usb
- Connect USB ethernet adapter
- Boot the PC using UEFI into the USB dongle (F12)
- Proceed as normal thereafter