<#
===============================================================================
 Projet 5 - Deploiement standardise d'un poste
 p5-post-install.ps1 - Configuration automatique du poste standard STD-PG-NN
-------------------------------------------------------------------------------
 Auteur  : Paul Giocanti (PG)
 Date    : 17.09.2026
 Cible   : Windows 11 Pro 24H2 - Arve Services SA
 Contexte: lance automatiquement a la premiere ouverture de session par le
           fichier de reponses autounattend.xml (section FirstLogonCommands).
           Peut aussi etre relance manuellement pour remettre un poste en
           conformite : le script est IDEMPOTENT (le relancer ne casse rien).

 Ce que fait ce script, dans l'ordre :
   1. Identite du poste      - nom STD-PG-NN et groupe de travail ARVE
   2. Comptes locaux         - verification/reparation, politique de mot de passe
   3. Regionalisation        - clavier suisse romand, fuseau, formats
   4. Reseau                 - profil prive, pare-feu, bureau a distance
   5. Securite               - UAC, verrouillage auto, SmartScreen, Defender
   6. Nettoyage              - retrait des applications grand public
   7. Logiciels metier       - installation silencieuse via winget
   8. Arborescence           - dossiers d'entreprise et droits
   9. Rapport                - duree de chaque etape, journal, JSON

 Chaque etape est chronometree : c'est ce qui alimente le comparatif de temps
 "installation manuelle vs installation automatisee" du rapport de projet.
===============================================================================
#>

[CmdletBinding()]
param(
    # Numero du poste sur 2 chiffres (01 a 10). S'il est absent, le script le lit
    # dans poste.txt, et a defaut le deduit du numero de serie de la machine.
    [string] $Numero,

    # Passe l'etape 7 (utile pour un test rapide ou un poste sans Internet)
    [switch] $SansLogiciels,

    # N'effectue pas le redemarrage final
    [switch] $PasDeRedemarrage,

    [string] $DossierDeploiement = 'C:\Deploiement'
)

$ErrorActionPreference = 'Continue'
$script:Etapes  = @()
$script:Journal = @()

# --------------------------------------------------------------------------- #
# Fonctions utilitaires
# --------------------------------------------------------------------------- #

function Write-Titre {
    param([string]$Texte)
    Write-Host ''
    Write-Host ('=' * 70) -ForegroundColor DarkCyan
    Write-Host "  $Texte" -ForegroundColor Cyan
    Write-Host ('=' * 70) -ForegroundColor DarkCyan
}

function Write-Info   { param([string]$m) Write-Host "   [i] $m" -ForegroundColor Gray }
function Write-Ok     { param([string]$m) Write-Host "   [OK] $m" -ForegroundColor Green }
function Write-Alerte { param([string]$m) Write-Host "   [!] $m" -ForegroundColor Yellow }

# Execute une etape en la chronometrant et en capturant son statut.
function Invoke-Etape {
    param(
        [Parameter(Mandatory)][string]      $Nom,
        [Parameter(Mandatory)][scriptblock] $Action
    )
    Write-Titre $Nom
    $chrono = [System.Diagnostics.Stopwatch]::StartNew()
    $statut = 'OK'
    $erreur = ''
    try {
        & $Action
    } catch {
        $statut = 'ECHEC'
        $erreur = $_.Exception.Message
        Write-Alerte "Erreur : $erreur"
    }
    $chrono.Stop()
    $script:Etapes += [pscustomobject]@{
        Etape    = $Nom
        Statut   = $statut
        Secondes = [math]::Round($chrono.Elapsed.TotalSeconds, 1)
        Erreur   = $erreur
    }
    Write-Host ("   -> $statut en {0:N1} s" -f $chrono.Elapsed.TotalSeconds) -ForegroundColor DarkGray
}

# Ecrit une valeur de registre en creant la cle si elle n'existe pas.
function Set-CleRegistre {
    param(
        [Parameter(Mandatory)][string] $Chemin,
        [Parameter(Mandatory)][string] $Nom,
        [Parameter(Mandatory)]         $Valeur,
        [string] $Type = 'DWord'
    )
    if (-not (Test-Path $Chemin)) { New-Item -Path $Chemin -Force | Out-Null }
    New-ItemProperty -Path $Chemin -Name $Nom -Value $Valeur -PropertyType $Type -Force | Out-Null
}

# Localise winget.exe meme quand il n'est pas encore dans le PATH du profil.
function Get-CheminWinget {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidat = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Filter 'winget.exe' `
                    -Recurse -ErrorAction SilentlyContinue |
                Sort-Object FullName -Descending | Select-Object -First 1
    if ($candidat) { return $candidat.FullName }
    return $null
}

# Determine le nom du poste : parametre -Numero, sinon poste.txt, sinon numero de serie.
function Resolve-NomPoste {
    param([string]$NumeroDemande, [string]$Dossier)

    if ($NumeroDemande) {
        $n = $NumeroDemande.PadLeft(2, '0')
        Write-Info "Numero fourni en parametre : $n"
        return @{ Nom = "STD-PG-$n"; Source = 'parametre -Numero' }
    }

    $fichier = Join-Path $Dossier 'poste.txt'
    if (Test-Path $fichier) {
        $contenu = (Get-Content $fichier -Raw).Trim()
        if ($contenu -match '^\d{1,2}$') {
            $n = $contenu.PadLeft(2, '0')
            Write-Info "Numero lu dans poste.txt : $n"
            return @{ Nom = "STD-PG-$n"; Source = 'fichier poste.txt du media' }
        }
    }

    $serie = ((Get-CimInstance Win32_BIOS).SerialNumber) -replace '[^A-Za-z0-9]', ''
    if ([string]::IsNullOrWhiteSpace($serie)) { $serie = (Get-Random -Minimum 1000 -Maximum 9999).ToString() }
    $suffixe = $serie.Substring([math]::Max(0, $serie.Length - 4)).ToUpper()
    Write-Alerte "Aucun numero fourni : nom deduit du numero de serie ($suffixe)"
    return @{ Nom = "STD-PG-$suffixe"; Source = 'numero de serie du materiel' }
}

# --------------------------------------------------------------------------- #
# Preparation
# --------------------------------------------------------------------------- #

$estAdmin = ([Security.Principal.WindowsPrincipal] `
             [Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $estAdmin) {
    Write-Host 'Ce script doit etre lance avec les droits administrateur.' -ForegroundColor Red
    exit 1
}

$dossierLogs = Join-Path $DossierDeploiement 'logs'
New-Item -Path $dossierLogs -ItemType Directory -Force | Out-Null

$horodatage = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$fichierLog = Join-Path $dossierLogs "post-install_$horodatage.log"
Start-Transcript -Path $fichierLog -Force | Out-Null

$chronoGlobal = [System.Diagnostics.Stopwatch]::StartNew()
$debut        = Get-Date

$poste     = Resolve-NomPoste -NumeroDemande $Numero -Dossier $DossierDeploiement
$nomPoste  = $poste.Nom

Write-Host ''
Write-Host '###############################################################' -ForegroundColor White
Write-Host '#   DEPLOIEMENT DU POSTE STANDARD - Arve Services SA          #' -ForegroundColor White
Write-Host '###############################################################' -ForegroundColor White
Write-Host "   Poste cible        : $nomPoste"
Write-Host "   Source du nom      : $($poste.Source)"
Write-Host "   Demarrage          : $debut"
Write-Host "   Journal            : $fichierLog"
Write-Host ''

# --------------------------------------------------------------------------- #
# ETAPE 1 - Identite du poste
# --------------------------------------------------------------------------- #
Invoke-Etape '1/9  Identite du poste (nom et groupe de travail)' {

    $actuel = $env:COMPUTERNAME
    if ($actuel -ne $nomPoste) {
        Rename-Computer -NewName $nomPoste -Force -ErrorAction Stop
        Write-Ok "Nom du poste : $actuel  ->  $nomPoste (effectif au redemarrage)"
    } else {
        Write-Info "Le poste s'appelle deja $nomPoste"
    }

    $groupe = (Get-CimInstance Win32_ComputerSystem).Workgroup
    if ($groupe -ne 'ARVE') {
        Add-Computer -WorkgroupName 'ARVE' -Force -ErrorAction Stop
        Write-Ok "Groupe de travail : $groupe  ->  ARVE"
    } else {
        Write-Info 'Groupe de travail deja positionne sur ARVE'
    }
}

# --------------------------------------------------------------------------- #
# ETAPE 2 - Comptes locaux et politique de mot de passe
# --------------------------------------------------------------------------- #
Invoke-Etape '2/9  Comptes locaux et politique de mot de passe' {

    # Les groupes locaux sont traduits selon la langue de Windows : on les
    # designe par leur SID, identifiant unique et invariant.
    #   S-1-5-32-544 = Administrateurs / Administrators
    #   S-1-5-32-545 = Utilisateurs    / Users
    $grpAdmins = (Get-LocalGroup -SID 'S-1-5-32-544').Name
    $grpUsers  = (Get-LocalGroup -SID 'S-1-5-32-545').Name
    Write-Info "Groupe administrateurs local : $grpAdmins"

    $comptes = @(
        @{ Nom = 'adm.local';   Description = 'Compte technique du service informatique'; Groupe = $grpAdmins; MotDePasse = 'Adm.Local-2026!' },
        @{ Nom = 'utilisateur'; Description = 'Session de travail du collaborateur';      Groupe = $grpUsers;  MotDePasse = 'Utilisateur-2026!' }
    )

    foreach ($c in $comptes) {
        $existe = Get-LocalUser -Name $c.Nom -ErrorAction SilentlyContinue
        if (-not $existe) {
            $mdp = ConvertTo-SecureString $c.MotDePasse -AsPlainText -Force
            New-LocalUser -Name $c.Nom -Password $mdp -Description $c.Description `
                          -PasswordNeverExpires:$false -AccountNeverExpires | Out-Null
            Write-Ok "Compte cree : $($c.Nom)"
        } else {
            Write-Info "Compte deja present : $($c.Nom)"
        }

        $membres = (Get-LocalGroupMember -Group $c.Groupe -ErrorAction SilentlyContinue).Name
        if ($membres -notcontains "$env:COMPUTERNAME\$($c.Nom)") {
            Add-LocalGroupMember -Group $c.Groupe -Member $c.Nom -ErrorAction SilentlyContinue
            Write-Ok "$($c.Nom) ajoute au groupe $($c.Groupe)"
        } else {
            Write-Info "$($c.Nom) est deja membre de $($c.Groupe)"
        }
    }

    # Le compte Invite est une porte d'entree sans mot de passe : on le desactive.
    # Le compte invite se reconnait a son SID, qui se termine toujours par -501
    $invite = Get-LocalUser | Where-Object { $_.SID.Value -like '*-501' } | Select-Object -First 1
    if ($invite -and $invite.Enabled) {
        Disable-LocalUser -Name $invite.Name
        Write-Ok "Compte invite desactive ($($invite.Name))"
    }

    # Politique de mot de passe - cahier des charges section 4
    $regles = @(
        '/minpwlen:12', '/maxpwage:180', '/minpwage:1', '/uniquepw:5',
        '/lockoutthreshold:5', '/lockoutduration:15', '/lockoutwindow:15'
    )
    foreach ($r in $regles) { & net.exe accounts $r | Out-Null }
    Write-Ok 'Politique de mot de passe appliquee (12 caracteres min., verrouillage a 5 echecs)'
}

# --------------------------------------------------------------------------- #
# ETAPE 3 - Regionalisation suisse romande
# --------------------------------------------------------------------------- #
Invoke-Etape '3/9  Regionalisation (clavier suisse romand, fuseau, formats)' {

    Set-TimeZone -Id 'W. Europe Standard Time' -ErrorAction SilentlyContinue
    Write-Ok 'Fuseau horaire : W. Europe Standard Time (Geneve)'

    Set-Culture -CultureInfo 'fr-CH' -ErrorAction SilentlyContinue
    Set-WinSystemLocale -SystemLocale 'fr-CH' -ErrorAction SilentlyContinue
    Set-WinHomeLocation -GeoId 223 -ErrorAction SilentlyContinue   # 223 = Suisse
    Write-Ok 'Formats regionaux : francais (Suisse), pays = Suisse'

    # La disposition clavier suisse romande porte l'identifiant 0000100C.
    $liste = New-WinUserLanguageList -Language 'fr-CH'
    $liste[0].InputMethodTips.Clear()
    $liste[0].InputMethodTips.Add('100C:0000100C')
    Set-WinUserLanguageList -LanguageList $liste -Force
    Write-Ok 'Clavier : suisse romand (fr-CH, 100C:0000100C)'

    # Recopie ces reglages vers l'ecran de connexion et le modele des nouveaux
    # profils : sans cela, seul le compte courant en beneficie.
    try {
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true -ErrorAction Stop
        Write-Ok 'Reglages recopies vers l ecran de connexion et les nouveaux profils'
    } catch {
        Write-Alerte 'Copy-UserInternationalSettingsToSystem indisponible sur cette version'
    }
}

# --------------------------------------------------------------------------- #
# ETAPE 4 - Reseau
# --------------------------------------------------------------------------- #
Invoke-Etape '4/9  Reseau (profil, pare-feu, bureau a distance)' {

    Get-NetConnectionProfile | ForEach-Object {
        Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue
    }
    Write-Ok 'Profil reseau force sur Prive (reseau d entreprise)'

    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True
    Write-Ok 'Pare-feu actif sur les 3 profils (Domaine, Prive, Public)'

    # Decouverte reseau et partage de fichiers, necessaires au groupe de travail
    # Les noms des groupes de regles sont traduits selon la langue de Windows.
    # On les designe donc par leur identifiant de ressource, qui ne change jamais :
    #   @FirewallAPI.dll,-32752 = Decouverte de reseau
    #   @FirewallAPI.dll,-28502 = Partage de fichiers et d imprimantes
    Enable-NetFirewallRule -Group '@FirewallAPI.dll,-32752' -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28502' -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -Name  'FPS-ICMP4-ERQ-In'        -ErrorAction SilentlyContinue
    Write-Ok 'Decouverte reseau, partage de fichiers et reponse au ping autorises'

    # Bureau a distance : desactive (cahier des charges section 5)
    Set-CleRegistre 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' 1
    # @FirewallAPI.dll,-28752 = Bureau a distance
    Disable-NetFirewallRule -Group '@FirewallAPI.dll,-28752' -ErrorAction SilentlyContinue
    Write-Ok 'Bureau a distance (RDP) desactive'

    $ip = Get-NetIPAddress -AddressFamily IPv4 |
          Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } |
          Select-Object -First 1
    if ($ip) { Write-Info "Adresse obtenue par DHCP : $($ip.IPAddress)/$($ip.PrefixLength)" }
}

# --------------------------------------------------------------------------- #
# ETAPE 5 - Securite
# --------------------------------------------------------------------------- #
Invoke-Etape '5/9  Securite (UAC, verrouillage, SmartScreen, Defender)' {

    $polSystem = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

    Set-CleRegistre $polSystem 'EnableLUA'                  1
    Set-CleRegistre $polSystem 'ConsentPromptBehaviorAdmin' 2
    Set-CleRegistre $polSystem 'ConsentPromptBehaviorUser'  3
    Set-CleRegistre $polSystem 'PromptOnSecureDesktop'      1
    Write-Ok 'UAC : demande de confirmation sur le bureau securise'

    Set-CleRegistre $polSystem 'InactivityTimeoutSecs' 900
    Write-Ok 'Verrouillage automatique de la session apres 15 minutes d inactivite'

    Set-CleRegistre 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' 1
    Set-CleRegistre 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'ShellSmartScreenLevel' 'Block' 'String'
    Write-Ok 'SmartScreen actif, blocage des applications inconnues'

    Set-CleRegistre 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun' 255
    Write-Ok 'Execution automatique des supports amovibles desactivee'

    Set-CleRegistre 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' 'AUOptions' 4
    Write-Ok 'Mises a jour Windows : telechargement et installation automatiques'

    try {
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
        # PUA = Potentially Unwanted Application : logiciels au comportement
        # douteux (barres d'outils, mineurs, adwares) qui ne sont pas des virus
        # au sens strict. Non bloques par defaut sur Windows 11.
        Set-MpPreference -PUAProtection Enabled -ErrorAction SilentlyContinue
        Write-Ok 'Blocage des applications potentiellement indesirables (PUA) active'
        $def = Get-MpComputerStatus
        Write-Ok ("Defender : temps reel = {0}, antivirus = {1}" -f $def.RealTimeProtectionEnabled, $def.AntivirusEnabled)
        Update-MpSignature -ErrorAction SilentlyContinue
        Write-Info 'Signatures antivirus mises a jour'
    } catch {
        Write-Alerte 'Etat de Microsoft Defender non lisible sur cette machine'
    }
}

# --------------------------------------------------------------------------- #
# ETAPE 6 - Nettoyage des applications grand public
# --------------------------------------------------------------------------- #
Invoke-Etape '6/9  Nettoyage des applications preinstallees' {

    # Liste etablie a partir de ce qui est REELLEMENT present sur la build
    # utilisee (Windows 11 Pro 24H2 francaise, media CCCOMA_X64FRE_FR-FR_DV9),
    # puis completee des applications grand public des autres builds, pour que
    # le script reste valable sur un media different.
    $aSupprimer = @(
        # Reellement presentes sur la build de reference
        'MSTeams', 'MicrosoftTeams',              # Teams : pas de tenant Microsoft 365
        'Microsoft.BingSearch',                   # recherche grand public
        'Microsoft.MicrosoftOfficeHub',           # raccourci publicitaire vers l abonnement Office
        'Microsoft.OutlookForWindows',            # messagerie retenue : Thunderbird
        # Presentes sur d autres builds (retrait sans effet si absentes)
        'Clipchamp.Clipchamp', 'Microsoft.BingNews', 'Microsoft.BingWeather',
        'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay',
        'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.XboxIdentityProvider',
        'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.Todos',
        'Microsoft.PowerAutomateDesktop', 'Microsoft.WindowsFeedbackHub',
        'Microsoft.People', 'Microsoft.GetHelp', 'Microsoft.Getstarted',
        'Microsoft.MixedReality.Portal', 'Microsoft.549981C3F5F10'
    )

    $retirees = 0
    foreach ($app in $aSupprimer) {
        # 1) retrait pour les utilisateurs existants
        Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue |
            ForEach-Object {
                Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                $retirees++
            }
        # 2) retrait du modele, pour que l'application ne revienne pas sur les
        #    profils crees plus tard
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $app } |
            ForEach-Object {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
                $retirees++
            }
    }
    Write-Ok "$retirees paquets retires du poste et du modele de profil"

    # OneDrive n'est pas une application du Store : il s'installe en Win32 et
    # possede son propre desinstalleur. Retire ici car le cahier des charges
    # exclut tout compte Microsoft, donc toute synchronisation cloud personnelle.
    foreach ($od in @("$env:SystemRoot\SysWOW64\OneDriveSetup.exe", "$env:SystemRoot\System32\OneDriveSetup.exe")) {
        if (Test-Path $od) {
            Start-Process -FilePath $od -ArgumentList '/uninstall' -Wait -ErrorAction SilentlyContinue
            Write-Ok 'Microsoft OneDrive desinstalle'
            break
        }
    }

    # Widgets et contenus suggeres du menu Demarrer
    Set-CleRegistre 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
    Set-CleRegistre 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
    Write-Ok 'Widgets et applications suggerees desactives'
}

# --------------------------------------------------------------------------- #
# ETAPE 7 - Logiciels metier
# --------------------------------------------------------------------------- #
Invoke-Etape '7/9  Installation du socle logiciel commun (winget)' {

    if ($SansLogiciels) { Write-Alerte 'Etape ignoree (-SansLogiciels)'; return }

    $winget = Get-CheminWinget
    if (-not $winget) {
        Write-Alerte 'winget introuvable : installer "Programme d installation d application" depuis le Microsoft Store'
        throw 'winget indisponible'
    }
    Write-Info "winget : $winget"

    $logiciels = [ordered]@{
        'Mozilla.Firefox'                   = 'Mozilla Firefox'
        'Mozilla.Thunderbird'               = 'Mozilla Thunderbird'
        'Adobe.Acrobat.Reader.64-bit'       = 'Adobe Acrobat Reader'
        '7zip.7zip'                         = '7-Zip'
        'VideoLAN.VLC'                      = 'VLC'
        'Notepad++.Notepad++'               = 'Notepad++'
    }

    $script:ResultatsLogiciels = @()
    foreach ($id in $logiciels.Keys) {
        $nom = $logiciels[$id]
        Write-Info "Installation de $nom ..."
        $t = [System.Diagnostics.Stopwatch]::StartNew()
        $sortie = & $winget install --id $id --exact --silent --accept-package-agreements `
                        --accept-source-agreements --disable-interactivity --source winget 2>&1
        $t.Stop()
        $code = $LASTEXITCODE
        # 0 = installe ; -1978335135 (0x8A15002B) = deja installe
        # Codes de retour winget : 0 = installe,
        # -1978335135 (0x8A15002B) = le paquet est deja present sur le poste
        $statut = switch ($code) {
            0            { 'Installe' }
            -1978335135  { 'Deja present' }
            default      { "Echec (code $code)" }
        }
        $script:ResultatsLogiciels += [pscustomobject]@{
            Logiciel = $nom; Identifiant = $id; Statut = $statut
            Secondes = [math]::Round($t.Elapsed.TotalSeconds, 1)
        }
        if ($statut -like 'Echec*') { Write-Alerte "$nom : $statut" } else { Write-Ok "$nom : $statut ($([math]::Round($t.Elapsed.TotalSeconds))s)" }
    }

    Write-Host ''
    $script:ResultatsLogiciels | Format-Table -AutoSize | Out-String | Write-Host
}

# --------------------------------------------------------------------------- #
# ETAPE 8 - Arborescence d'entreprise
# --------------------------------------------------------------------------- #
Invoke-Etape '8/9  Arborescence d entreprise et raccourcis' {

    $racine  = 'C:\Entreprise'
    $dossiers = @('Documents-Communs', 'Modeles', 'Logiciels', 'Sauvegardes')
    New-Item -Path $racine -ItemType Directory -Force | Out-Null
    foreach ($d in $dossiers) { New-Item -Path (Join-Path $racine $d) -ItemType Directory -Force | Out-Null }
    Write-Ok "Arborescence creee : $racine ($($dossiers -join ', '))"

    # Droits NTFS - designation des groupes par SID pour rester independant de la langue
    $sidUtilisateurs = 'S-1-5-32-545'
    $nomUtilisateurs = (Get-LocalGroup -SID $sidUtilisateurs).Name

    # Sans /inheritance:r, tout dossier cree a la racine de C: herite d'une
    # autorisation Modification pour "Utilisateurs authentifies", c'est-a-dire
    # pour n'importe quel compte connecte : le dossier resterait inscriptible.
    & icacls.exe "$racine\Modeles" /inheritance:r `
        /grant:r '*S-1-5-32-544:(OI)(CI)F' `
        /grant:r '*S-1-5-18:(OI)(CI)F' `
        /grant:r "*${sidUtilisateurs}:(OI)(CI)RX" | Out-Null
    Write-Ok "Modeles : lecture seule pour le groupe $nomUtilisateurs"

    & icacls.exe "$racine\Logiciels" /inheritance:r `
        /grant:r '*S-1-5-32-544:(OI)(CI)F' `
        /grant:r '*S-1-5-18:(OI)(CI)F' | Out-Null
    Write-Ok 'Logiciels : reserve aux administrateurs'

    & icacls.exe "$DossierDeploiement" /inheritance:r `
        /grant:r '*S-1-5-32-544:(OI)(CI)F' `
        /grant:r '*S-1-5-18:(OI)(CI)F' | Out-Null
    Write-Ok "$DossierDeploiement : reserve aux administrateurs"

    # Raccourci sur le bureau public : visible par tous les comptes du poste
    $lien  = Join-Path $env:PUBLIC 'Desktop\Dossiers Arve Services.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $rac   = $shell.CreateShortcut($lien)
    $rac.TargetPath  = $racine
    $rac.Description = 'Dossiers partages du poste'
    $rac.Save()
    Write-Ok 'Raccourci depose sur le bureau public'
}

# --------------------------------------------------------------------------- #
# ETAPE 9 - Rapport de deploiement
# --------------------------------------------------------------------------- #
Invoke-Etape '9/9  Rapport de deploiement' {

    $os  = Get-CimInstance Win32_OperatingSystem
    $cs  = Get-CimInstance Win32_ComputerSystem

    $rapport = [ordered]@{
        Poste              = $nomPoste
        SourceDuNom        = $poste.Source
        GroupeDeTravail    = $cs.Workgroup
        SystemeExploitation= $os.Caption
        Version            = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
        Build              = $os.BuildNumber
        MemoireGo          = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        Processeurs        = $cs.NumberOfLogicalProcessors
        DebutDeploiement   = $debut.ToString('yyyy-MM-dd HH:mm:ss')
        FinDeploiement     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        DureeTotaleSecondes= [math]::Round($chronoGlobal.Elapsed.TotalSeconds, 1)
        DureeTotaleMinutes = [math]::Round($chronoGlobal.Elapsed.TotalMinutes, 2)
        Etapes             = $script:Etapes
        Logiciels          = $script:ResultatsLogiciels
    }

    $json = Join-Path $dossierLogs 'rapport-deploiement.json'
    $rapport | ConvertTo-Json -Depth 5 | Set-Content -Path $json -Encoding UTF8
    Write-Ok "Rapport JSON : $json"

    $csv = Join-Path $dossierLogs 'durees-etapes.csv'
    $script:Etapes | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8 -Delimiter ';'
    Write-Ok "Durees par etape : $csv"

    # Copie lisible sur le bureau public, pour la capture d'ecran de preuve
    $resume = Join-Path $env:PUBLIC 'Desktop\Rapport-deploiement.txt'
    $lignes = @()
    $lignes += '==============================================================='
    $lignes += "  DEPLOIEMENT TERMINE - $nomPoste"
    $lignes += '==============================================================='
    $lignes += "  Systeme        : $($os.Caption) $($rapport.Version) (build $($os.BuildNumber))"
    $lignes += "  Groupe travail : $($cs.Workgroup)"
    $lignes += "  Debut          : $($rapport.DebutDeploiement)"
    $lignes += "  Fin            : $($rapport.FinDeploiement)"
    $lignes += "  DUREE TOTALE   : $($rapport.DureeTotaleMinutes) minutes"
    $lignes += ''
    $lignes += '  Duree par etape :'
    foreach ($e in $script:Etapes) {
        $lignes += ('    {0,-52} {1,7:N1} s   {2}' -f $e.Etape, $e.Secondes, $e.Statut)
    }
    $lignes += ''
    $lignes += '  Logiciels :'
    foreach ($l in $script:ResultatsLogiciels) {
        $lignes += ('    {0,-26} {1,-16} {2,6:N1} s' -f $l.Logiciel, $l.Statut, $l.Secondes)
    }
    $lignes += '==============================================================='
    $lignes | Set-Content -Path $resume -Encoding UTF8
    Write-Ok "Resume depose sur le bureau : $resume"

    Write-Host ''
    $lignes | ForEach-Object { Write-Host $_ -ForegroundColor White }
}

# --------------------------------------------------------------------------- #
# Fin
# --------------------------------------------------------------------------- #
$chronoGlobal.Stop()
Write-Host ''
Write-Host ('DUREE TOTALE DU DEPLOIEMENT AUTOMATISE : {0:N2} minutes' -f $chronoGlobal.Elapsed.TotalMinutes) -ForegroundColor Green
Stop-Transcript | Out-Null

if (-not $PasDeRedemarrage) {
    Write-Host ''
    Write-Host 'Redemarrage dans 60 secondes pour appliquer le nom du poste.' -ForegroundColor Yellow
    Write-Host 'Appuyer sur Ctrl+C pour annuler.' -ForegroundColor Yellow
    for ($i = 60; $i -gt 0; $i--) {
        Write-Host -NoNewline ("`r   Redemarrage dans {0,3} s ..." -f $i)
        Start-Sleep -Seconds 1
    }
    Restart-Computer -Force
}
