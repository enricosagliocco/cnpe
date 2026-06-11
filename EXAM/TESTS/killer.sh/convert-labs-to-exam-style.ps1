param(
    [string]$Root = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

$excluded = @('crossplane-lab')
$labs = Get-ChildItem -LiteralPath $Root -Directory |
    Where-Object { $_.Name -like '*-lab' -and $_.Name -notin $excluded }

function Get-CoursePath {
    param([string]$Text, [string]$LabName)

    $match = [regex]::Match($Text, '~/course-[A-Za-z0-9-]+')
    if ($match.Success) {
        return $match.Value
    }

    return '~/course-' + $LabName.Replace('-lab', '')
}

function Convert-Question {
    param(
        [string]$Section,
        [string]$CoursePath,
        [bool]$UsesLifecycleScripts
    )

    $section = $Section -replace '(?m)^\*\*Ticket:\*\*[^\r\n]*(?:\r?\n)?', ''
    $section = $section.TrimEnd()
    $section = $section -replace '(?s)\r?\n---\s*$', ''
    $section = $section.TrimEnd()
    if ($section -match '(?m)^\*\*Solution\*\*') {
        return $section
    }

    $pathMatch = [regex]::Match(
        $section,
        '(?m)^(?:Percorso|Path):\s*`([^`]+)`'
    )
    $questionPath = if ($pathMatch.Success) {
        $pathMatch.Groups[1].Value
    } else {
        $CoursePath
    }

    $usesCreate =
        $UsesLifecycleScripts -or $section -match 'create-resources\.sh'
    $usesRemove =
        $UsesLifecycleScripts -or $section -match 'remove-resources\.sh'
    $manifestNames = @([regex]::Matches(
        $section,
        '`([^`]+\.(?:yaml|yml|json|sh))`'
    ) | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)

    $tipCommand = if ($usesCreate) {
        './create-resources.sh'
    } elseif ($manifestNames.Count -gt 0) {
        'kubectl apply --server-side --dry-run=server -f ' + $manifestNames[0]
    } else {
        'kubectl get events -A --sort-by=.lastTimestamp'
    }

    $applyLines = New-Object System.Collections.Generic.List[string]
    $applyLines.Add("cd $questionPath")
    if ($usesCreate) {
        $applyLines.Add('./create-resources.sh')
    }
    foreach ($manifest in $manifestNames) {
        if ($manifest -notmatch '\.sh$') {
            $applyLines.Add("kubectl apply -f $manifest")
        }
    }
    if ($manifestNames.Count -eq 0) {
        $applyLines.Add('kubectl get all -A')
    }
    $applyLines.Add('kubectl get events -A --sort-by=.lastTimestamp')
    if ($usesRemove) {
        $applyLines.Add('./remove-resources.sh')
    }

    $commands = ($applyLines | Select-Object -Unique) -join "`n"
    return @"
$section

**Tip 1**

Esamina tutti i manifest presenti in ``$questionPath`` prima di applicarli.

**Tip 2**

``````bash
$tipCommand
``````

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

``````bash
$commands
``````
"@.TrimEnd()
}

foreach ($lab in $labs) {
    $questionsPath = Join-Path $lab.FullName 'domande.md'
    if (-not (Test-Path -LiteralPath $questionsPath)) {
        continue
    }

    $text = [IO.File]::ReadAllText($questionsPath)
    $coursePath = Get-CoursePath -Text $text -LabName $lab.Name
    $firstQuestion = [regex]::Match($text, '(?m)^### Q1(?:\s|$)')
    if (-not $firstQuestion.Success) {
        throw "Q1 not found in $questionsPath"
    }

    $title = ([regex]::Match($text, '(?m)^#\s+(.+)$')).Groups[1].Value.Trim()
    $title = $title -replace '^Le 20 domande dell.esame\s+\S+\s+', ''
    $title = $title -replace '\s*\(simulatore lab\)\s*$', ''
    $title = $title -replace '\s*-\s*20 exam-style tasks\s*$', ''
    $usesLifecycleScripts =
        $text -match 'create-resources\.sh' -or
        $text -match 'remove-resources\.sh'
    $lifecycle = if ($usesLifecycleScripts) {
        @"

Per ogni domanda esegui ``./create-resources.sh`` quando presente e termina
con ``./remove-resources.sh``. Non lasciare risorse di uno scenario attive
durante la prova successiva.
"@
    } else {
        ''
    }

    $intro = @"
# $title - 20 exam-style tasks

Ogni domanda e una prova pratica autonoma. Esamina i file forniti, applica
le risorse richieste e verifica il risultato nel cluster. Le sezioni
``Tip`` aiutano a individuare API, file e comandi utili; la sezione
``Solution`` riporta il flusso operativo di applicazione e verifica.

Non modificare o disinstallare i componenti core installati dal setup.
Usa il kubeconfig corrente e conserva le evidenze richieste dalla domanda.
$lifecycle

Comandi utili:

``````bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
``````

---

"@

    $questionsText = $text.Substring($firstQuestion.Index)
    $matches = [regex]::Matches($questionsText, '(?m)^### Q\d+(?:\s|$)')
    if ($matches.Count -ne 20) {
        throw "Expected 20 questions in $questionsPath, found $($matches.Count)"
    }

    $converted = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $matches.Count; $i++) {
        $start = $matches[$i].Index
        $end = if ($i + 1 -lt $matches.Count) {
            $matches[$i + 1].Index
        } else {
            $questionsText.Length
        }
        $section = $questionsText.Substring($start, $end - $start)
        $converted.Add(
            (Convert-Question `
                -Section $section `
                -CoursePath $coursePath `
                -UsesLifecycleScripts $usesLifecycleScripts)
        )
    }

    $output = $intro + ($converted -join "`n`n---`n`n") + "`n"
    [IO.File]::WriteAllText(
        $questionsPath,
        $output,
        [Text.UTF8Encoding]::new($false)
    )

    $readmePath = Join-Path $lab.FullName 'README.md'
    if (Test-Path -LiteralPath $readmePath) {
        $readme = [IO.File]::ReadAllText($readmePath)
        if ($readme -notmatch 'exam-style') {
            $lines = $readme -split '\r?\n'
            $insert = @(
                '',
                'Le 20 domande sono presentate in formato exam-style: obiettivo',
                'diretto, tip, soluzione operativa e verifica runtime.'
            )
            $lines = @($lines[0]) + $insert + @($lines[1..($lines.Count - 1)])
            [IO.File]::WriteAllText(
                $readmePath,
                ($lines -join "`n"),
                [Text.UTF8Encoding]::new($false)
            )
        }
    } else {
        $displayName = ($lab.Name -replace '-lab$', '') -replace '-', ' '
        $readme = @"
# $displayName Lab

Laboratorio con 20 domande in formato exam-style: obiettivo diretto, tip,
soluzione operativa e verifica runtime.

Esegui lo script ``setup-*-lab.sh`` della directory per preparare il cluster
e generare il materiale del corso.
"@
        [IO.File]::WriteAllText(
            $readmePath,
            $readme,
            [Text.UTF8Encoding]::new($false)
        )
    }
}
