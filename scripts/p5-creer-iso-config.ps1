<#
===============================================================================
 Projet 5 - Deploiement standardise d'un poste
 p5-creer-iso-config.ps1 - Fabrication du media de configuration (ISO)
-------------------------------------------------------------------------------
 Auteur : Paul Giocanti (PG) - 17.09.2026

 A quoi sert ce script :
 Windows Setup cherche automatiquement un fichier nomme "autounattend.xml" a la
 RACINE de tous les lecteurs amovibles et de tous les lecteurs de CD/DVD au
 moment ou il demarre. Il suffit donc de lui presenter un petit disque contenant
 ce fichier pour que l'installation devienne entierement automatique, SANS avoir
 a reconstruire l'ISO de Windows (qui pese 5 a 6 Go).

 Ce script fabrique ce petit disque : une image ISO d'environ 100 Ko contenant
   \autounattend.xml                      <- lu par Windows Setup
   \PPE-P5\p5-post-install.ps1            <- configuration du poste
   \PPE-P5\p5-verifier-conformite.ps1     <- controle de conformite
   \PPE-P5\demarrer-post-install.cmd      <- lanceur (installation neuve)
   \PPE-P5\demarrer-post-image.cmd        <- lanceur (apres restauration d'image)
   \PPE-P5\poste.txt                      <- numero du poste a deployer

 Il n'utilise aucun outil externe : il pilote IMAPI2, le composant de gravure
 integre a Windows depuis Vista, via des objets COM.

 Utilisation :
   powershell -ExecutionPolicy Bypass -File p5-creer-iso-config.ps1 -Numero 02
===============================================================================
#>

[CmdletBinding()]
param(
    # Numero du poste a deployer (ecrit dans poste.txt)
    [string] $Numero = '02',

    # Dossier dont le contenu devient la racine de l'ISO
    [string] $Source,

    # Chemin de l'image ISO produite
    [string] $Destination,

    [string] $NomVolume = 'CONFIG-P5'
)

$ErrorActionPreference = 'Stop'

# Racine du projet, deduite de l'emplacement du script (..\ depuis scripts\)
$racineProjet = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $Source)      { $Source      = Join-Path $racineProjet 'deploiement\media-config' }
if (-not $Destination) { $Destination = Join-Path $racineProjet 'deploiement\PPE-P5-Config.iso' }

Write-Host ''
Write-Host '=== Fabrication du media de configuration ===' -ForegroundColor Cyan
Write-Host "   Source      : $Source"
Write-Host "   Destination : $Destination"
Write-Host "   Poste cible : STD-PG-$($Numero.PadLeft(2,'0'))"
Write-Host ''

# --- 1. Mise a jour du contenu du media --------------------------------------
New-Item -Path (Join-Path $Source 'PPE-P5') -ItemType Directory -Force | Out-Null

Copy-Item (Join-Path $racineProjet 'deploiement\autounattend.xml') $Source -Force
foreach ($f in @('p5-post-install.ps1','p5-verifier-conformite.ps1','demarrer-post-install.cmd','demarrer-post-image.cmd')) {
    Copy-Item (Join-Path $racineProjet "scripts\$f") (Join-Path $Source 'PPE-P5') -Force
}
Set-Content -Path (Join-Path $Source 'PPE-P5\poste.txt') -Value $Numero.PadLeft(2,'0') -NoNewline -Encoding ASCII
Write-Host '   [OK] Contenu du media synchronise avec le dossier scripts\' -ForegroundColor Green

# --- 2. Classe utilitaire : ecriture du flux COM vers un fichier -------------
# IMAPI2 fournit l'image gravee sous forme de flux COM (IStream). PowerShell ne
# sait pas ecrire un IStream directement : on ajoute quelques lignes de C# qui
# lisent le flux bloc par bloc et les ecrivent dans le fichier ISO.
if (-not ('P5.IsoWriter' -as [type])) {
    Add-Type -TypeDefinition @'
namespace P5 {
  public static class IsoWriter {
    public static void Write(string chemin, object flux, int tailleBloc, int nbBlocs) {
      System.Runtime.InteropServices.ComTypes.IStream i =
          (System.Runtime.InteropServices.ComTypes.IStream)flux;
      System.IO.FileStream o = System.IO.File.Create(chemin);
      byte[] tampon = new byte[tailleBloc];
      System.IntPtr lus = System.Runtime.InteropServices.Marshal.AllocHGlobal(4);
      try {
        while (nbBlocs-- > 0) {
          i.Read(tampon, tailleBloc, lus);
          int n = System.Runtime.InteropServices.Marshal.ReadInt32(lus);
          if (n <= 0) break;
          o.Write(tampon, 0, n);
        }
        o.Flush();
      } finally {
        o.Close();
        System.Runtime.InteropServices.Marshal.FreeHGlobal(lus);
      }
    }
  }
}
'@
}

# --- 3. Construction de l'image ----------------------------------------------
$image = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$image.FileSystemsToCreate = 3          # 1 = ISO9660, 2 = Joliet -> 3 = les deux
$image.VolumeName          = $NomVolume
$image.Root.AddTree($Source, $false)    # $false : on ajoute le CONTENU du dossier

$resultat = $image.CreateResultImage()

# L'image precedente peut etre verrouillee : VMware la tient ouverte tant qu'elle
# est montee comme CD dans une machine virtuelle. On le detecte pour afficher la
# marche a suivre plutot qu'une exception incomprehensible.
if (Test-Path $Destination) {
    try {
        Remove-Item $Destination -Force -ErrorAction Stop
    } catch {
        Write-Host ''
        Write-Host '   [BLOQUE] L image ISO est verrouillee par un autre programme.' -ForegroundColor Red
        Write-Host '   Cause la plus frequente : elle est montee comme CD dans une machine' -ForegroundColor Yellow
        Write-Host '   virtuelle. Dans VMware : Modifier les parametres -> CD/DVD ->' -ForegroundColor Yellow
        Write-Host '   decocher "Connecte" -> OK, puis relancer ce script.' -ForegroundColor Yellow
        Write-Host ''
        exit 1
    }
}
[P5.IsoWriter]::Write($Destination, $resultat.ImageStream, $resultat.BlockSize, $resultat.TotalBlocks)

$taille = [math]::Round((Get-Item $Destination).Length / 1KB, 1)
Write-Host ''
Write-Host "   [OK] Image creee : $Destination ($taille Ko)" -ForegroundColor Green
Write-Host ''
Write-Host '   Etape suivante : dans VMware, ajouter un SECOND lecteur de CD/DVD' -ForegroundColor Yellow
Write-Host '   a la machine virtuelle et y monter cette image, en plus de l ISO' -ForegroundColor Yellow
Write-Host '   de Windows 11. Puis demarrer la machine.' -ForegroundColor Yellow
Write-Host ''
