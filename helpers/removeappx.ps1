$mountPath = "C:\Mount"

# Get all provisioned packages
$packages = Get-AppxProvisionedPackage -Path $mountPath

# List of DisplayNames to remove
$displayNamesToRemove = @(
    "Clipchamp.Clipchamp",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.WindowsAlarms",
    "Microsoft.Xbox",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.Paint3D",
    "Microsoft.Office.OneNote",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.BingNews",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.Messaging",
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.SkypeApp",
    "Microsoft.BingWeather",
    "Microsoft.YourPhone",
    "Microsoft.XboxGameCallableUI",
    "MSTeams",
    "Microsoft.GamingApp",
    "Microsoft.BingSearch",
    "Microsoft.GetHelp",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.OutlookForWindows",
    "Microsoft.Paint",
    "Microsoft.ScreenSketch",
    "Microsoft.StorePurchaseApp",
    "Microsoft.Todos",
    "Microsoft.Windows.Photos",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.WindowsStore",
    "Microsoft.ZuneMusic",
    "MicrosoftCorporationII.MicrosoftFamily",
    "MicrosoftCorporationII.QuickAssist",
    "Microsoft.Windows.DevHome"
)

foreach ($displayName in $displayNamesToRemove) {
    # Find matching packages by display name
    $packagesToRemove = $packages | Where-Object { $_.DisplayName -like "$displayName*" }

    foreach ($package in $packagesToRemove) {
        Remove-AppxProvisionedPackage -Path $mountPath -PackageName $package.PackageName
        if ($?) {
            Write-Output "Successfully removed package: $($package.PackageName)"
        } else {
            Write-Output "Failed to remove package: $($package.PackageName)"
        }
    }
}