<#
===============================================================================
 Projet 5 - Deploiement standardise d'un poste
 p5-chrono.ps1 - Chronometre de phases (a lancer sur la machine HOTE)
-------------------------------------------------------------------------------
 Auteur : Paul Giocanti (PG) - 17.09.2026

 A quoi sert ce script :
 Le comparatif "installation manuelle vs installation automatisee" ne vaut que
 si les deux sont mesurees de la meme facon. Ce script sert de chronometre : il
 affiche la phase en cours, et chaque appui sur Entree cloture la phase et
 demarre la suivante. Il produit un CSV exploitable directement dans le rapport.

 Utilisation :
   powershell -ExecutionPolicy Bypass -File p5-chrono.ps1 -Scenario manuel
   powershell -ExecutionPolicy Bypass -File p5-chrono.ps1 -Scenario auto
   powershell -ExecutionPolicy Bypass -File p5-chrono.ps1 -Scenario image
===============================================================================
#>

[CmdletBinding()]
param(
    [ValidateSet('manuel','auto','image')]
    [string] $Scenario = 'manuel',

    # Numero de la phase a laquelle reprendre, si une session precedente a ete
    # interrompue. Les phases precedentes sont ignorees.
    [int] $Depuis = 1,

    [string] $DossierSortie
)

$racineProjet = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $DossierSortie) { $DossierSortie = Join-Path $racineProjet 'doc' }

$phases = switch ($Scenario) {
    'manuel' { @(
        'Creation et parametrage de la machine virtuelle',
        'Installation de Windows (copie des fichiers et redemarrages)',
        'Ecrans de bienvenue OOBE (langue, clavier, reseau, compte)',
        'Renommage du poste et groupe de travail',
        'Creation des comptes et politique de mot de passe',
        'Reglages regionaux (clavier, fuseau, formats)',
        'Reseau et pare-feu',
        'Reglages de securite (UAC, verrouillage, SmartScreen, mises a jour)',
        'Suppression des applications preinstallees',
        'Installation des 7 logiciels metier',
        'Creation de l arborescence et des droits',
        'Verification finale'
    )}
    'auto' { @(
        'Creation et parametrage de la machine virtuelle',
        'Montage des deux ISO et demarrage',
        'Installation de Windows pilotee par le fichier de reponses (sans intervention)',
        'Phase de bienvenue OOBE (a la main)',
        'Execution du script de post-installation (sans intervention)',
        'Controle de conformite'
    )}
    'image' { @(
        'Preparation du poste de reference (Sysprep /generalize)',
        'Demarrage de Clonezilla et capture de l image',
        'Creation de la machine virtuelle cible',
        'Restauration de l image sur la machine cible',
        'Premier demarrage et finalisation (mini-OOBE + script)',
        'Controle de conformite'
    )}
}

$resultats = @()
$debutGlobal = Get-Date

New-Item -Path $DossierSortie -ItemType Directory -Force | Out-Null
$fichier = Join-Path $DossierSortie ("chrono-$Scenario.csv")
if ($Depuis -gt 1) { $fichier = Join-Path $DossierSortie ("chrono-$Scenario-reprise.csv") }

Write-Host ''
Write-Host '###############################################################' -ForegroundColor White
Write-Host "#   CHRONOMETRE DE DEPLOIEMENT - scenario : $Scenario" -ForegroundColor White
Write-Host '###############################################################' -ForegroundColor White
Write-Host ''
Write-Host 'Regle : appuyer sur Entree AU MOMENT OU la phase affichee est terminee.' -ForegroundColor Yellow
Write-Host 'Le chronometre de la phase suivante demarre immediatement.' -ForegroundColor Yellow
Write-Host ''
Read-Host 'Appuyer sur Entree pour DEMARRER la premiere phase'

$numero = 0
foreach ($phase in $phases) {
    $numero++
    if ($numero -lt $Depuis) { continue }   # reprise apres interruption
    $debut = Get-Date
    Write-Host ''
    Write-Host ("  Phase {0}/{1} : {2}" -f $numero, $phases.Count, $phase) -ForegroundColor Cyan
    Write-Host ("  Demarree a {0:HH:mm:ss}" -f $debut) -ForegroundColor DarkGray
    Read-Host '  -> Entree quand cette phase est TERMINEE'
    $fin    = Get-Date
    $duree  = $fin - $debut

    $resultats += [pscustomobject]@{
        Numero        = $numero
        Phase         = $phase
        Debut         = $debut.ToString('HH:mm:ss')
        Fin           = $fin.ToString('HH:mm:ss')
        DureeSecondes = [math]::Round($duree.TotalSeconds, 0)
        DureeMinutes  = [math]::Round($duree.TotalMinutes, 2)
    }
    Write-Host ("  Duree : {0:N1} minutes" -f $duree.TotalMinutes) -ForegroundColor Green

    # Le CSV est reecrit apres CHAQUE phase et non a la fin : si la fenetre se
    # ferme en cours de route, les mesures deja prises sont conservees.
    $resultats | Export-Csv -Path $fichier -NoTypeInformation -Encoding UTF8 -Delimiter ';'
}

$dureeGlobale = (Get-Date) - $debutGlobal

Write-Host ''
Write-Host '===============================================================' -ForegroundColor White
$resultats | Format-Table Numero, Phase, Debut, Fin, DureeMinutes -AutoSize
Write-Host ("  TOTAL : {0:N1} minutes ({1:N0} secondes)" -f $dureeGlobale.TotalMinutes, $dureeGlobale.TotalSeconds) -ForegroundColor Green
Write-Host '===============================================================' -ForegroundColor White

$resultats | Export-Csv -Path $fichier -NoTypeInformation -Encoding UTF8 -Delimiter ';'
Write-Host ''
Write-Host "Chronometrage enregistre : $fichier" -ForegroundColor Cyan
