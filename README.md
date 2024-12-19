# Software

## TFTP server: tftpd-hpa
We could use integrated pfSense TFTP server, however, it does not support map files, hence, we are using tftpd-hpa server:
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
echo -e 'dhcp\nchain [your-http-path]/boot.ipxe' | tee ~/ipxe/src/embedded.ipxe
```

Install required tools and compile new **undionly.pxe** boot firmware:
```
sudo apt install gcc binutils make perl liblzma-dev xz-utils mtools genisoimage syslinux && make bin/undionly.kpxe EMBED=embedded.ipxe
```

### For UEFI bios client boots 

Files:
- **uefi.pxe**: original to be used is fine
- **autoexec.ipxe**: this is auto-loaded file that **eufi.pxe** loads as firmware boots, we add instructions to load further files from http server:
```
echo -e 'dhcp\nchain [your-http-path]/boot.ipxe' | tee ~/tftp/autoexec.ipxe
```
### Copy firmware TFTP server
```
cp bin-x86_64-efi/ipxe.efi ~/tftp/ipxe.efi
cp bin/undionly.kpxe ~/tftp/undionly.kpxe
```

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

[boot.ipxe](/html/win11/boot.ipxe)

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

[UUPD 24H2](https://uupdump.net/known.php?q=category:w11-24h2)

```bash
mkdir C:\UUPD
notepad C:\UUPD\ConvertConfig.ini
```

Edit the following in `ConvertConfig.ini`:
```ini
[convert-UUP]
AutoStart    =3
SkipISO      =1

[Store_Apps]
SkipApps     =1
CustomList   =1
```

Edit ```CustomAppsList.txt``` to exclude all non-wanted apps

Download and compile install.wim:

Run as administrator: ```uup_download_windows.cmd```

When downloaded Run Powershell as admin:

```
mkdir C:\UUPD\Mount
```
```
dism /mount-wim /wimfile:C:\UUPD\install.wim /index:1 /mountdir:C:\UUPD\Mount
```
```
Set-ExecutionPolicy Bypass -Scope Process
```
```
Get-AppxProvisionedPackage -Path C:\UUPD\Mount | Select-Object DisplayName | Out-File C:\UUPD\InstalledPackages.txt
```

Review `InstalledPackages.txt` and add app removal commands in `removeappx.ps1`. Then:
```powershell
powershell -File .\removeappx.ps1
```

```bash
dism /unmount-wim /mountdir:C:\UUPD\Mount /commit
```


## For DELL R8153
- Create USB iPXE boot file ```cd src/ && make bin-x86_64-efi/ecm.usb```
- Write ecm.usb to USB dongle using Rufus
- Disconnect all USB ethernet adapters
- Boot the PC using UEFI into the USB dongle
- Get into iPXE command line using Ctrl + B
- Connect the USB ethernet adapter
- Issue a command ```ifopen```
- Issue a command ```dhcp```
- Issue a command ```chain http://192.168.0.26/win11/boot.pxe```
- Proceed as normal thereafter