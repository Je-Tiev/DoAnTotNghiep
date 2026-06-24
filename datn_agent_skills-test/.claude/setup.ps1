<#
  setup.ps1 - Wire up the Claude Code layer (.claude) for the Automotive ECU monorepo.

  This machine has no Developer Mode / no admin, so symlinks cannot be created.
  Instead we use Directory Junctions (mklink /J) which need no admin rights.

  Single source of truth:
    - Skills: real content under .agents/skills/ (git-tracked). .claude/skills/<name>
      are junctions to those folders (flattened: category level dropped).
    - CLAUDE.md: real file at <this-folder>/.claude/CLAUDE.md; the monorepo-root
      CLAUDE.md is a 1-line pointer that @imports it.

  Idempotent: removes existing links before recreating them.
  Run:  powershell -ExecutionPolicy Bypass -File datn_agent_skills-test\.claude\setup.ps1
#>

$ErrorActionPreference = 'Stop'

# Paths derived dynamically (folder may be renamed without breaking this script).
$ClaudeSrc = Split-Path -Parent $MyInvocation.MyCommand.Path   # ...\datn_agent_skills-test\.claude
$DAS       = Split-Path -Parent $ClaudeSrc                      # ...\datn_agent_skills-test
$DASName   = Split-Path -Leaf   $DAS                            # datn_agent_skills-test
$Root      = Split-Path -Parent $DAS                            # monorepo root
$Agents    = Join-Path $DAS '.agents'

Write-Host "Root      = $Root"
Write-Host "Agents    = $Agents"
Write-Host "ClaudeSrc = $ClaudeSrc`n"

# --- helpers --------------------------------------------------------------
function Remove-Link($path) {
  if (Test-Path -LiteralPath $path) {
    $item = Get-Item -LiteralPath $path -Force
    if ($item.PSIsContainer) { cmd /c rmdir "`"$path`"" | Out-Null }   # junction -> rmdir (target untouched)
    else                     { Remove-Item -LiteralPath $path -Force }
  }
}
function New-Junction($link, $target) {
  Remove-Link $link
  cmd /c mklink /J "`"$link`"" "`"$target`"" | Out-Null
  Write-Host "  [J] $link  ->  $target"
}

# --- 1) root\.claude (real local folder holding the junctions) ------------
$RootClaude = Join-Path $Root '.claude'
if (-not (Test-Path -LiteralPath $RootClaude)) { New-Item -ItemType Directory -Path $RootClaude | Out-Null }

# --- 2) CLAUDE.md (root = 1-line pointer that @imports the real file) ------
Write-Host "CLAUDE.md:"
$RootClaudeMd = Join-Path $Root 'CLAUDE.md'
Remove-Link $RootClaudeMd
Set-Content -LiteralPath $RootClaudeMd -Value "@$DASName/.claude/CLAUDE.md" -Encoding ASCII -NoNewline
Write-Host "  [P] $RootClaudeMd  ->  @$DASName/.claude/CLAUDE.md"

# --- 2b) root\.agents -> datn_agent_skills-test\.agents (for Antigravity) ---
# Lets Antigravity (and any agent opened at the workspace root) see rules + skills
# while having full access to the sub-projects (STM32-1st, STM32-2nd, ClusterApp).
Write-Host "`n.agents:"
New-Junction (Join-Path $Root '.agents') $Agents

# --- 3) commands -> .agents\workflows (only if workflows exist) ------------
$Workflows = Join-Path $Agents 'workflows'
if (Test-Path -LiteralPath $Workflows) {
  Write-Host "`nCommands:"
  New-Junction (Join-Path $RootClaude 'commands') $Workflows
}

# --- 4) skills (junctions, flattened - drop the category level) -----------
Write-Host "`nSkills:"
$SkillsLink = Join-Path $RootClaude 'skills'
if (-not (Test-Path -LiteralPath $SkillsLink)) { New-Item -ItemType Directory -Path $SkillsLink | Out-Null }

# Automotive ECU project skills: 'category/name' under .agents\skills
$skills = @(
  'firmware/stm32-hal-driver',
  'firmware/freertos-task-manager',
  'firmware/can-protocol',
  'firmware/w5500-ethernet',
  'firmware/cubeide-build-flash',
  'android/cluster-ui',
  'general/git-ops-manager',
  'general/task-breakdown',
  'general/arch-doc-sync',
  'general/report-writer'
)
foreach ($rel in $skills) {
  $name   = Split-Path $rel -Leaf
  $target = Join-Path $Agents (Join-Path 'skills' ($rel -replace '/','\'))
  if (-not (Test-Path -LiteralPath (Join-Path $target 'SKILL.md'))) {
    Write-Warning "  Skip $name - no SKILL.md at $target"
    continue
  }
  New-Junction (Join-Path $SkillsLink $name) $target
}

Write-Host "`nDone. Reopen Claude Code in $Root to load CLAUDE.md and skills."
