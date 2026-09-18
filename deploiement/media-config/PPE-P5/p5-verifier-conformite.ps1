<#
===============================================================================
 Projet 5 - Deploiement standardise d'un poste
 p5-verifier-conformite.ps1 - Controle automatique de conformite
-------------------------------------------------------------------------------
 Auteur : Paul Giocanti (PG) - 17.09.2026

 A quoi sert ce script :
 Le cahier des charges decrit ce que DOIT etre un poste standard. Ce script va
 lire l'etat reel de la machine et le comparer, point par point, a ce qui est
 ecrit dans le cahier des charges. Il produit un score de conformite, un tableau
 a l'ecran, un fichier CSV et un rapport HTML.

 C'est la PREUVE du deploiement : au lieu d'affirmer "le poste 2 est identique
 au poste 1", on le demontre avec 40 controles automatises, executes de la meme
 maniere sur les deux machines. Critere d'acceptation : score >= 95 % et aucun
 ecart sur un point de categorie "Securite".

 Utilisation :
   powershell -ExecutionPolicy Bypass -File p5-verifier-conformite.ps1
===============================================================================
#>

[CmdletBinding()]
param(
    [string] $DossierSortie = 'C:\Deploiement\logs',
    [switch] $PasDHtml
)

$ErrorActionPreference = 'SilentlyContinue'
$script:Controles = @()

# --------------------------------------------------------------------------- #
# Moteur de controle
# --------------------------------------------------------------------------- #
function Test-Exigence {
    param(
        [Parameter(Mandatory)][string] $Categorie,
        [Parameter(Mandatory)][string] $Exigence,
        [Parameter(Mandatory)][string] $Attendu,
        [Parameter(Mandatory)][scriptblock] $Mesure,
        [ValidateSet('Egal','Contient','Motif','VraiFaux','SuperieurOuEgal')]
        [string] $Comparaison = 'Egal'
    )

    $obtenu = try { & $Mesure } catch { "erreur: $($_.Exception.Message)" }
    if ($null -eq $obtenu) { $obtenu = '(absent)' }
    $obtenuTexte = "$obtenu"

    $conforme = switch ($Comparaison) {
        'Egal'            { $obtenuTexte.Trim() -eq $Attendu.Trim() }
        'Contient'        { $obtenuTexte -like "*$Attendu*" }
        'Motif'           { $obtenuTexte -match $Attendu }
        'VraiFaux'        { [string]$obtenu -eq $Attendu }
        'SuperieurOuEgal' { try { [double]$obtenu -ge [double]$Attendu } catch { $false } }
    }

    $script:Controles += [pscustomobject]@{
        Categorie = $Categorie
        Exigence  = $Exigence
        Attendu   = $Attendu
        Obtenu    = $obtenuTexte
        Resultat  = if ($conforme) { 'CONFORME' } else { 'ECART' }
    }

    $couleur = if ($conforme) { 'Green' } else { 'Red' }
    $symbole = if ($conforme) { '  OK  ' } else { ' ECART' }
    Write-Host ('[{0}] {1,-14} {2,-44} {3}' -f $symbole, $Categorie, $Exigence, $obtenuTexte) -ForegroundColor $couleur
}

function Get-ValeurRegistre {
    param([string]$Chemin, [string]$Nom)
    (Get-ItemProperty -Path $Chemin -Name $Nom -ErrorAction SilentlyContinue).$Nom
}

function Test-LogicielInstalle {
    param([string]$Motif)
    $cles = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $trouve = Get-ItemProperty $cles -ErrorAction SilentlyContinue |
              Where-Object { $_.DisplayName -like "*$Motif*" } |
              Select-Object -First 1
    if ($trouve) { return 'Present' } else { return 'Absent' }
}

# --------------------------------------------------------------------------- #
# En-tete
# --------------------------------------------------------------------------- #
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem

Write-Host ''
Write-Host '###############################################################' -ForegroundColor White
Write-Host '#   CONTROLE DE CONFORMITE - Poste standard Arve Services SA  #' -ForegroundColor White
Write-Host '###############################################################' -ForegroundColor White
Write-Host "   Poste analyse : $env:COMPUTERNAME"
Write-Host "   Date          : $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
Write-Host ''

# --------------------------------------------------------------------------- #
# 1. Identite du poste
# --------------------------------------------------------------------------- #
Write-Host '--- 1. Identite -----------------------------------------------' -ForegroundColor DarkCyan
Test-Exigence 'Identite' 'Nom du poste au format STD-PG-NN' '^STD-PG-\w{2,4}$' { $env:COMPUTERNAME } -Comparaison Motif
Test-Exigence 'Identite' 'Groupe de travail'                'ARVE'             { $cs.Workgroup }

# --------------------------------------------------------------------------- #
# 2. Systeme d'exploitation
# --------------------------------------------------------------------------- #
Write-Host '--- 2. Systeme ------------------------------------------------' -ForegroundColor DarkCyan
Test-Exigence 'Systeme' 'Edition Windows 11 Professionnel' 'Pro'      { $os.Caption } -Comparaison Contient
Test-Exigence 'Systeme' 'Architecture 64 bits'             '64'       { $os.OSArchitecture } -Comparaison Contient
Test-Exigence 'Systeme' 'Build >= 26100 (version 24H2)'    '26100'    { $os.BuildNumber } -Comparaison SuperieurOuEgal
Test-Exigence 'Systeme' 'Fuseau horaire'                   'W. Europe Standard Time' { (Get-TimeZone).Id }
Test-Exigence 'Systeme' 'Format regional'                  'fr-CH'    { (Get-Culture).Name }
Test-Exigence 'Systeme' 'Clavier suisse romand'            '0000100C' { (Get-WinUserLanguageList)[0].InputMethodTips -join ',' } -Comparaison Contient
Test-Exigence 'Systeme' 'Pays / region (Suisse)'           '223'      { (Get-WinHomeLocation).GeoId }
Test-Exigence 'Systeme' 'Memoire vive >= 8 Go'             '8'        { [math]::Round($cs.TotalPhysicalMemory / 1GB, 0) } -Comparaison SuperieurOuEgal

# --------------------------------------------------------------------------- #
# 3. Disque et partitionnement
# --------------------------------------------------------------------------- #
Write-Host '--- 3. Disque -------------------------------------------------' -ForegroundColor DarkCyan
Test-Exigence 'Disque' 'Table de partition GPT'         'GPT'  { (Get-Disk -Number 0).PartitionStyle }
Test-Exigence 'Disque' 'Partition systeme EFI presente' 'True' { [bool](Get-Partition -DiskNumber 0 | Where-Object { $_.Type -eq 'System' }) } -Comparaison VraiFaux
Test-Exigence 'Disque' 'Volume C: en NTFS'              'NTFS' { (Get-Volume -DriveLetter C).FileSystemType }
Test-Exigence 'Disque' 'Demarrage en mode UEFI'         'UEFI' { $env:firmware_type }

# --------------------------------------------------------------------------- #
# 4. Comptes et mots de passe
# --------------------------------------------------------------------------- #
Write-Host '--- 4. Comptes ------------------------------------------------' -ForegroundColor DarkCyan
$grpAdmins = (Get-LocalGroup -SID 'S-1-5-32-544').Name
$membresAdmins = (Get-LocalGroupMember -Group $grpAdmins -ErrorAction SilentlyContinue).Name

Test-Exigence 'Comptes' 'Compte adm.local present'          'True' { [bool](Get-LocalUser -Name 'adm.local') } -Comparaison VraiFaux
Test-Exigence 'Comptes' 'adm.local est administrateur'      'True' { [bool]($membresAdmins -match '\\adm\.local$') } -Comparaison VraiFaux
Test-Exigence 'Comptes' 'Compte utilisateur present'        'True' { [bool](Get-LocalUser -Name 'utilisateur') } -Comparaison VraiFaux
Test-Exigence 'Comptes' 'utilisateur N EST PAS administrateur' 'False' { [bool]($membresAdmins -match '\\utilisateur$') } -Comparaison VraiFaux
Test-Exigence 'Comptes' 'Compte invite desactive'           'False' { (Get-LocalUser | Where-Object { $_.SID.Value -like '*-501' } | Select-Object -First 1).Enabled } -Comparaison VraiFaux

$netAccounts = (& net.exe accounts) -join "`n"
Test-Exigence 'Securite' 'Longueur minimale du mot de passe >= 12' '12' {
    $ligne = ($netAccounts -split "`n" | Where-Object { $_ -match 'Longueur minimale du mot de passe|Minimum password length' } | Select-Object -First 1)
    ([regex]::Match("$ligne", '(\d+)')).Value
} -Comparaison SuperieurOuEgal
Test-Exigence 'Securite' 'Seuil de verrouillage du compte = 5' '5' {
    $ligne = ($netAccounts -split "`n" | Where-Object { $_ -match 'Seuil de verrouillage|Lockout threshold' } | Select-Object -First 1)
    ([regex]::Match("$ligne", '(\d+)')).Value
}

# --------------------------------------------------------------------------- #
# 5. Reseau
# --------------------------------------------------------------------------- #
Write-Host '--- 5. Reseau -------------------------------------------------' -ForegroundColor DarkCyan
Test-Exigence 'Reseau' 'Adressage IP automatique (DHCP)' 'True' {
    [bool](Get-NetIPInterface -AddressFamily IPv4 | Where-Object { $_.Dhcp -eq 'Enabled' -and $_.InterfaceAlias -notmatch 'Loopback' })
} -Comparaison VraiFaux
Test-Exigence 'Reseau' 'Profil reseau prive'  'Private' { (Get-NetConnectionProfile | Select-Object -First 1).NetworkCategory }
Test-Exigence 'Securite' 'Pare-feu actif sur les 3 profils' '3' {
    (Get-NetFirewallProfile | Where-Object { $_.Enabled -eq 'True' }).Count
}
Test-Exigence 'Securite' 'Bureau a distance (RDP) desactive' '1' {
    Get-ValeurRegistre 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'
}

# --------------------------------------------------------------------------- #
# 6. Securite du poste
# --------------------------------------------------------------------------- #
Write-Host '--- 6. Securite -----------------------------------------------' -ForegroundColor DarkCyan
$polSystem = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
Test-Exigence 'Securite' 'UAC active (EnableLUA)'                 '1'   { Get-ValeurRegistre $polSystem 'EnableLUA' }
Test-Exigence 'Securite' 'UAC : confirmation administrateur'      '2'   { Get-ValeurRegistre $polSystem 'ConsentPromptBehaviorAdmin' }
Test-Exigence 'Securite' 'UAC : bureau securise'                  '1'   { Get-ValeurRegistre $polSystem 'PromptOnSecureDesktop' }
Test-Exigence 'Securite' 'Verrouillage auto apres 900 s'          '900' { Get-ValeurRegistre $polSystem 'InactivityTimeoutSecs' }
Test-Exigence 'Securite' 'SmartScreen active'                     '1'   { Get-ValeurRegistre 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' }
Test-Exigence 'Securite' 'Execution auto des supports desactivee' '255' {
    $v = Get-ValeurRegistre 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
    if ($null -eq $v) { $v = Get-ValeurRegistre 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'NoDriveTypeAutoRun' }
    $v
}
Test-Exigence 'Securite' 'Mises a jour automatiques'              '4'   { Get-ValeurRegistre 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' 'AUOptions' }
Test-Exigence 'Securite' 'Defender : protection temps reel'       'True' { (Get-MpComputerStatus).RealTimeProtectionEnabled } -Comparaison VraiFaux
Test-Exigence 'Securite' 'Defender : antivirus actif'             'True' { (Get-MpComputerStatus).AntivirusEnabled } -Comparaison VraiFaux
Test-Exigence 'Securite' 'Blocage des applications indesirables (PUA)' 'Enabled' { (Get-MpPreference).PUAProtection -replace '^1$','Enabled' -replace '^0$','Disabled' -replace '^2$','AuditMode' }
Test-Exigence 'Securite' 'TPM present'                          'True' { (Get-Tpm).TpmPresent } -Comparaison VraiFaux
Test-Exigence 'Securite' 'TPM en version 2.0'                   '2.0'  { ((Get-CimInstance -Namespace 'root\CIMV2\Security\MicrosoftTpm' -ClassName Win32_Tpm).SpecVersion -split ',')[0].Trim() }

# --------------------------------------------------------------------------- #
# 7. Logiciels metier
# --------------------------------------------------------------------------- #
Write-Host '--- 7. Logiciels ----------------------------------------------' -ForegroundColor DarkCyan
$attendus = [ordered]@{
    'Mozilla Firefox'      = 'Firefox'
    'Mozilla Thunderbird'  = 'Thunderbird'
    'Adobe Acrobat Reader' = 'Acrobat'
    '7-Zip'                = '7-Zip'
    'VLC'                  = 'VLC'
    'Notepad++'            = 'Notepad++'
}
foreach ($nom in $attendus.Keys) {
    $motif = $attendus[$nom]
    Test-Exigence 'Logiciels' "$nom installe" 'Present' ([scriptblock]::Create("Test-LogicielInstalle -Motif '$motif'"))
}

# --------------------------------------------------------------------------- #
# 8. Nettoyage des applications grand public
# --------------------------------------------------------------------------- #
Write-Host '--- 8. Nettoyage ----------------------------------------------' -ForegroundColor DarkCyan
foreach ($app in @('MSTeams','Microsoft.BingSearch','Microsoft.MicrosoftOfficeHub','Microsoft.OutlookForWindows','Clipchamp.Clipchamp','Microsoft.MicrosoftSolitaireCollection')) {
    Test-Exigence 'Nettoyage' "$app retire" 'False' ([scriptblock]::Create("[bool](Get-AppxPackage -Name '$app' -AllUsers)")) -Comparaison VraiFaux
}
Test-Exigence 'Nettoyage' 'OneDrive desinstalle' 'False' {
    Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
} -Comparaison VraiFaux

# --------------------------------------------------------------------------- #
# 9. Arborescence d'entreprise
# --------------------------------------------------------------------------- #
Write-Host '--- 9. Arborescence -------------------------------------------' -ForegroundColor DarkCyan
foreach ($d in @('C:\Entreprise','C:\Entreprise\Documents-Communs','C:\Entreprise\Modeles','C:\Entreprise\Logiciels','C:\Entreprise\Sauvegardes','C:\Deploiement\logs')) {
    Test-Exigence 'Arborescence' "Dossier $d" 'True' ([scriptblock]::Create("Test-Path '$d'")) -Comparaison VraiFaux
}
# Droits NTFS : aucun groupe d'utilisateurs ne doit pouvoir ecrire dans Modeles.
# On interroge la liste de controle d'acces (ACL) du dossier et on cherche une
# autorisation d'ecriture accordee a Utilisateurs ou Utilisateurs authentifies.
Test-Exigence 'Securite' 'Modeles : aucun droit d ecriture pour les utilisateurs' 'False' {
    [bool]((Get-Acl 'C:\Entreprise\Modeles').Access | Where-Object {
        $_.IdentityReference -match 'Utilisateurs|Users' -and
        $_.AccessControlType -eq 'Allow' -and
        $_.FileSystemRights -match 'Write|Modify|FullControl'
    })
} -Comparaison VraiFaux
Test-Exigence 'Securite' 'Logiciels : reserve aux administrateurs' 'False' {
    [bool]((Get-Acl 'C:\Entreprise\Logiciels').Access | Where-Object {
        $_.IdentityReference -match 'Utilisateurs|Users' -and
        $_.IdentityReference -notmatch 'Administrateurs|Administrators' -and
        $_.AccessControlType -eq 'Allow'
    })
} -Comparaison VraiFaux

Test-Exigence 'Arborescence' 'Raccourci sur le bureau public' 'True' {
    Test-Path (Join-Path $env:PUBLIC 'Desktop\Dossiers Arve Services.lnk')
} -Comparaison VraiFaux

# --------------------------------------------------------------------------- #
# Synthese
# --------------------------------------------------------------------------- #
$total     = $script:Controles.Count
$conformes = ($script:Controles | Where-Object { $_.Resultat -eq 'CONFORME' }).Count
$ecarts    = $total - $conformes
$score     = if ($total) { [math]::Round(($conformes / $total) * 100, 1) } else { 0 }
$ecartsSecu = ($script:Controles | Where-Object { $_.Resultat -eq 'ECART' -and $_.Categorie -eq 'Securite' }).Count
$verdict   = if ($score -ge 95 -and $ecartsSecu -eq 0) { 'POSTE ACCEPTE' } else { 'POSTE REFUSE' }

Write-Host ''
Write-Host '===============================================================' -ForegroundColor White
Write-Host ("  POSTE            : $env:COMPUTERNAME")
Write-Host ("  CONTROLES        : $total")
Write-Host ("  CONFORMES        : $conformes")
Write-Host ("  ECARTS           : $ecarts  (dont $ecartsSecu en securite)")
Write-Host ("  SCORE            : $score %")
Write-Host ("  VERDICT          : $verdict") -ForegroundColor $(if ($verdict -eq 'POSTE ACCEPTE') { 'Green' } else { 'Red' })
Write-Host '===============================================================' -ForegroundColor White

if ($ecarts -gt 0) {
    Write-Host ''
    Write-Host 'Detail des ecarts :' -ForegroundColor Yellow
    $script:Controles | Where-Object { $_.Resultat -eq 'ECART' } | Format-Table Categorie, Exigence, Attendu, Obtenu -AutoSize
}

# --------------------------------------------------------------------------- #
# Fichiers de sortie
# --------------------------------------------------------------------------- #
New-Item -Path $DossierSortie -ItemType Directory -Force | Out-Null
$base = Join-Path $DossierSortie "conformite-$env:COMPUTERNAME"

$script:Controles | Export-Csv -Path "$base.csv" -NoTypeInformation -Encoding UTF8 -Delimiter ';'
Write-Host ''
Write-Host "Rapport CSV  : $base.csv" -ForegroundColor Cyan

if (-not $PasDHtml) {
    $couleurScore = if ($score -ge 95) { '#1a7f37' } elseif ($score -ge 80) { '#bf8700' } else { '#c0392b' }
    $lignes = ($script:Controles | ForEach-Object {
        $cls = if ($_.Resultat -eq 'CONFORME') { 'ok' } else { 'ko' }
        "<tr class='$cls'><td>$($_.Categorie)</td><td>$($_.Exigence)</td><td>$($_.Attendu)</td><td>$($_.Obtenu)</td><td class='r'>$($_.Resultat)</td></tr>"
    }) -join "`n"

    $html = @"
<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8">
<title>Conformite $env:COMPUTERNAME</title>
<style>
 body{font-family:Segoe UI,Arial,sans-serif;margin:32px;color:#1c2024;background:#fbfbfc}
 h1{font-size:22px;margin:0 0 4px} .sub{color:#666;font-size:13px;margin-bottom:24px}
 .score{display:inline-block;padding:14px 26px;border-radius:10px;color:#fff;background:$couleurScore;
        font-size:30px;font-weight:700;margin-right:16px;vertical-align:middle}
 .kpi{display:inline-block;vertical-align:middle;font-size:14px;line-height:1.7}
 table{border-collapse:collapse;width:100%;margin-top:26px;font-size:13px;background:#fff}
 th{background:#20304a;color:#fff;text-align:left;padding:9px 10px;font-weight:600}
 td{padding:7px 10px;border-bottom:1px solid #e6e8eb}
 tr.ok td.r{color:#1a7f37;font-weight:700} tr.ko td{background:#fdecea} tr.ko td.r{color:#c0392b;font-weight:700}
 footer{margin-top:28px;color:#888;font-size:12px}
</style></head><body>
<h1>Controle de conformite du poste standard</h1>
<div class="sub">Arve Services SA &middot; Projet 5 &middot; Reference : cahier des charges v1.0</div>
<div class="score">$score&nbsp;%</div>
<div class="kpi">
  <b>Poste :</b> $env:COMPUTERNAME<br>
  <b>Date :</b> $(Get-Date -Format 'dd.MM.yyyy HH:mm')<br>
  <b>Controles :</b> $conformes conformes / $total &mdash; $ecarts ecart(s), dont $ecartsSecu en securite<br>
  <b>Verdict :</b> $verdict
</div>
<table>
<tr><th>Categorie</th><th>Exigence</th><th>Attendu</th><th>Mesure</th><th>Resultat</th></tr>
$lignes
</table>
<footer>Genere automatiquement par p5-verifier-conformite.ps1 &middot; Paul Giocanti</footer>
</body></html>
"@
    $html | Set-Content -Path "$base.html" -Encoding UTF8
    Write-Host "Rapport HTML : $base.html" -ForegroundColor Cyan
}
