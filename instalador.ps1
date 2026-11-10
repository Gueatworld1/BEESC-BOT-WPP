# Instalador do BEESC BOT (sem Docker, sem winget, sem administrador, sem reiniciar o PC)
# Roda pelo instalar.bat (dois cliques). Pode ser executado de novo sem problema:
# mensagens e ajustes já feitos são mantidos.

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
$Host.UI.RawUI.WindowTitle = "Instalador - BEESC BOT"

$Origem  = Split-Path -Parent $PSCommandPath
$Destino = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "whatsapp-bot"
$Painel  = "http://127.0.0.1:5000"
$Utf8    = New-Object System.Text.UTF8Encoding $false
$TOTAL   = 6
$Versao  = "3.0"

function Passo($n, $t) { Write-Host ""; Write-Host "[$n/$TOTAL] $t" -ForegroundColor Cyan }
function Ok($t)    { Write-Host "   OK  $t" -ForegroundColor Green }
function Aviso($t) { Write-Host "   !   $t" -ForegroundColor Yellow }
function Falha($t) {
    Write-Host ""; Write-Host "ERRO: $t" -ForegroundColor Red
    Read-Host "Pressione Enter para fechar"; exit 1
}
function Atualizar-Path {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}
function Tem($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Escrever($caminho, $texto) { [IO.File]::WriteAllText($caminho, $texto, $Utf8) }

Write-Host "=====================================================" -ForegroundColor White
Write-Host "  Instalador do BEESC BOT - WhatsApp da Biblioteca EESC" -ForegroundColor White
Write-Host "=====================================================" -ForegroundColor White
Write-Host "Pasta de instalação: $Destino"
Write-Host "Nada aqui exige reiniciar o computador."

if (-not (Test-Path (Join-Path $Origem "arquivos\painel\index.html"))) {
    Falha "Não encontrei a pasta 'arquivos'. Extraia o .zip inteiro antes de rodar o instalar.bat (botão direito > Extrair tudo)."
}

# Programas baixados pelo instalador ficam aqui (fora da pasta do bot, para não
# serem apagados a cada atualização). Nada exige administrador nem o winget.
$Ferramentas = Join-Path $env:LOCALAPPDATA "BEESC-BOT"
New-Item -ItemType Directory -Force -Path $Ferramentas | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Baixar($url, $arquivo) {
    try { Invoke-WebRequest -UseBasicParsing $url -OutFile $arquivo; return $true }
    catch { return $false }
}

# ---------- 1. Node.js ----------
Passo 1 "Verificando o Node.js (faz a conexão com o WhatsApp)"
function Versao-Node($exe) {
    try { $v = & $exe --version 2>&1; if ("$v" -match "^v(\d+)") { return [int]$Matches[1] } } catch { }
    return 0
}
$NodeDir = Join-Path $Ferramentas "node"
$NodeExe = $null
if ((Tem "node") -and (Versao-Node "node") -ge 20) {
    $NodeExe = (Get-Command node).Source
} elseif ((Test-Path "$NodeDir\node.exe") -and (Versao-Node "$NodeDir\node.exe") -ge 20) {
    $NodeExe = "$NodeDir\node.exe"
} else {
    Aviso "Node.js não encontrado. Baixando a versão portátil oficial (nodejs.org)..."
    try {
        $lts = (Invoke-RestMethod "https://nodejs.org/dist/index.json") |
            Where-Object { $_.lts -and $_.files -contains "win-x64-zip" -and $_.version -match "^v22\." } | Select-Object -First 1
    } catch { $lts = $null }
    if (-not $lts) { Falha "Não consegui consultar o site do Node.js. Verifique a internet." }
    $zip = Join-Path $env:TEMP "node-$($lts.version).zip"
    if (-not (Baixar "https://nodejs.org/dist/$($lts.version)/node-$($lts.version)-win-x64.zip" $zip)) { Falha "Não consegui baixar o Node.js. Verifique a internet." }
    $tmp = Join-Path $env:TEMP "node-extraido"
    Remove-Item $tmp, $NodeDir -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $zip $tmp -Force
    Move-Item (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName $NodeDir
    Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
    $NodeExe = "$NodeDir\node.exe"
    if ((Versao-Node $NodeExe) -lt 20) { Falha "O Node.js foi baixado, mas não funcionou." }
}
$NodePasta = Split-Path $NodeExe
$env:Path = "$NodePasta;" + $env:Path
Ok ("Node.js " + (& $NodeExe --version))

# ---------- 2. Python ----------
Passo 2 "Verificando o Python (roda o bot e as mensagens)"
function Achar-Python {
    foreach ($c in @(
        @("py", "-3"), @("python"),
        @("$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"),
        @("$env:LOCALAPPDATA\Programs\Python\Python313\python.exe"))) {
        if ($c[0] -match "\\" -and -not (Test-Path $c[0])) { continue }
        if ($c[0] -notmatch "\\" -and -not (Tem $c[0])) { continue }
        $resto = @($c | Select-Object -Skip 1)
        # "return ,$c": a vírgula impede o PowerShell de transformar @("python") em só "python"
        try { $v = & $c[0] @resto --version 2>&1; if ("$v" -match "^Python 3\.(\d+)" -and [int]$Matches[1] -ge 9) { return ,$c } } catch { }
    }
    return $null
}
$Py = Achar-Python
if (-not $Py) {
    Aviso "Python não encontrado. Baixando o instalador oficial (python.org)..."
    $inst = Join-Path $env:TEMP "python-3.12.10-amd64.exe"
    if (-not (Baixar "https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe" $inst)) { Falha "Não consegui baixar o Python. Verifique a internet." }
    Write-Host "   Instalando o Python só para este usuário (sem pedir administrador)..."
    Start-Process $inst -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_launcher=0 Include_test=0 Include_doc=0" -Wait
    Remove-Item $inst -Force -ErrorAction SilentlyContinue
    Atualizar-Path
    $Py = Achar-Python
    if (-not $Py) { Falha "O Python não foi instalado. Rode o instalar.bat de novo." }
}
$PyExe  = $Py[0]
$PyArgs = @($Py | Select-Object -Skip 1)
$PyCmd  = (@("`"$PyExe`"") + $PyArgs) -join " "
Ok ("" + (& $PyExe @PyArgs --version 2>&1))
$global:LASTEXITCODE = 0
& $PyExe @PyArgs -m pip install --quiet --disable-pip-version-check flask requests beautifulsoup4
if (-not $? -or $LASTEXITCODE -ne 0) { Falha "Não consegui instalar as bibliotecas do Python. Verifique a internet." }
Ok "Bibliotecas do Python instaladas"

# ---------- 3. Instalação anterior com Docker ----------
Passo 3 "Procurando instalações anteriores (Evolution API / Docker)"
$antigos = @()
if (Tem "docker") {
    cmd /c "docker info >nul 2>&1"
    if ($LASTEXITCODE -eq 0) {
        $antigos = @(docker ps -a --format "{{.Names}}" | Where-Object { $_ -match "^(evolution_|biblio_)" })
    }
}
if ($antigos.Count -gt 0) {
    Aviso ("Encontrei a versão anterior do bot rodando no Docker: " + ($antigos -join ", "))
    Aviso "Se as duas ficarem ligadas, cada mensagem vai ser respondida duas vezes."
    $r = Read-Host "   Desligar e remover a versão anterior? (S/N)"
    if ($r -match "^[sS]") {
        docker rm -f @antigos | Out-Null
        Ok "Versão anterior removida"
    } else { Aviso "Mantida. Desligue-a antes de usar o bot novo." }
    Aviso "No celular, em Aparelhos conectados, remova o aparelho antigo da Evolution API."
} else { Ok "Nenhuma instalação anterior em uso" }

# ---------- 4. Arquivos ----------
Passo 4 "Copiando os arquivos do bot"
New-Item -ItemType Directory -Force -Path $Destino, (Join-Path $Destino "painel") | Out-Null

# Desliga a versão que estiver rodando, para poder trocar os arquivos
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and ($_.CommandLine -match "ponte\.js" -or $_.CommandLine -match "bot\.py") } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep 2

# Limpa a instalação anterior. Só ficam:
#   respostas.db  - mensagens, horário e histórico editados no painel
#   auth\         - a conexão com o WhatsApp (sem ela, seria preciso escanear o QR code de novo)
#   local.json    - a pasta compartilhada configurada neste computador (vários computadores)
$VersaoArq = Join-Path $Destino "versao.txt"
$anterior = if (Test-Path $VersaoArq) { (Get-Content $VersaoArq -Raw).Trim() } else { $null }
$manter = "respostas.db", "auth", "local.json"
$removidos = 0
Get-ChildItem $Destino -Force | Where-Object { $manter -notcontains $_.Name } | ForEach-Object {
    Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    $removidos++
}
if ($removidos -gt 0) {
    if ($anterior) { Ok "Versão $anterior removida ($removidos itens). Mensagens, horário e conexão do WhatsApp mantidos." }
    else { Ok "Instalação anterior removida ($removidos itens). Mensagens, horário e conexão do WhatsApp mantidos." }
}
New-Item -ItemType Directory -Force -Path (Join-Path $Destino "painel") | Out-Null

# Pasta da primeira versão (Evolution API com Docker), se ainda existir
$PastaDocker = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "evolution-api"
if (Test-Path $PastaDocker) {
    Aviso "Encontrei a pasta da primeira versão, com Docker: $PastaDocker"
    $r = Read-Host "   Apagar essa pasta? Ela não é mais usada. (S/N)"
    if ($r -match "^[sS]") { Remove-Item $PastaDocker -Recurse -Force -ErrorAction SilentlyContinue; Ok "Pasta da versão com Docker apagada" }
}

$arquivos = "ponte.js", "package.json", "bot.py", "criar_banco.py", "dedalus.py", "testar_dedalus.py",
            "iniciar_oculto.vbs", "abrir_painel.vbs", "painel\index.html", "painel\logo.png", "painel\logo.svg", "painel\logo.ico", "painel\tucano.svg"
foreach ($arq in $arquivos) {
    Copy-Item (Join-Path $Origem "arquivos\$arq") (Join-Path $Destino $arq) -Force
}
Escrever $VersaoArq $Versao
Ok "Arquivos do programa e do painel copiados"
Push-Location $Destino
Write-Host "   Baixando os componentes do WhatsApp (npm)..."
cmd /c "`"$NodePasta\npm.cmd`" install --omit=dev --no-audit --no-fund --loglevel=error"
if ($LASTEXITCODE -ne 0) { Pop-Location; Falha "O npm install falhou. Verifique a internet e rode de novo." }
Ok "Componentes do WhatsApp instalados"
$global:LASTEXITCODE = 0
& $PyExe @PyArgs criar_banco.py
if (-not $? -or $LASTEXITCODE -ne 0) { Pop-Location; Falha "Não consegui criar o banco de mensagens (criar_banco.py)." }
Pop-Location

# ---------- 5. Atalhos ----------
Passo 5 "Criando o aplicativo na área de trabalho e no menu Iniciar"
$Bat = Join-Path $Destino "iniciar_bot.bat"
$conteudo = @"
@echo off
cd /d "%~dp0"
for %%F in (bot.log ponte.log) do if exist "%%F" if %%~zF GTR 2000000 del "%%F"
set "PATH=$NodePasta;%PATH%"
start "" /b cmd /c ""$NodeExe" ponte.js >> ponte.log 2>&1"
$PyCmd -u bot.py >> bot.log 2>&1
"@
[IO.File]::WriteAllText($Bat, ($conteudo -replace "`r?`n", "`r`n"), [Text.Encoding]::ASCII)

$Wscript = Join-Path $env:WINDIR "System32\wscript.exe"
$Icone   = Join-Path $Destino "painel\logo.ico"
$ws = New-Object -ComObject WScript.Shell
function Atalho($pasta, $nome, $script, $descricao) {
    $lnk = $ws.CreateShortcut((Join-Path $pasta "$nome.lnk"))
    $lnk.TargetPath = $Wscript
    $lnk.Arguments = "`"$(Join-Path $Destino $script)`""
    $lnk.WorkingDirectory = $Destino
    $lnk.IconLocation = "$Icone,0"
    $lnk.Description = $descricao
    $lnk.Save()
}
$Desktop  = [Environment]::GetFolderPath("Desktop")
$Startup  = [Environment]::GetFolderPath("Startup")
$Programas = [Environment]::GetFolderPath("Programs")
# remove atalhos da versão anterior (janela preta)
$atalhosVelhos = "Bot WhatsApp Biblioteca.lnk", "Bot da Biblioteca.lnk", "Bot da Biblioteca (iniciar).lnk"
foreach ($velho in ($atalhosVelhos | ForEach-Object { (Join-Path $Desktop $_), (Join-Path $Startup $_), (Join-Path $Programas $_) })) {
    if (Test-Path $velho) { Remove-Item $velho -Force }
}
Atalho $Desktop   "BEESC BOT" "abrir_painel.vbs"   "BEESC BOT - painel do WhatsApp da Biblioteca EESC"
Atalho $Programas "BEESC BOT" "abrir_painel.vbs"   "BEESC BOT - painel do WhatsApp da Biblioteca EESC"
Atalho $Startup   "BEESC BOT (iniciar)" "iniciar_oculto.vbs" "Liga o BEESC BOT em segundo plano"
Ok "Ícone 'BEESC BOT' na área de trabalho e no menu Iniciar"
Ok "O bot liga sozinho, sem janela, quando esta conta entra no Windows"

# ---------- 6. Ligar e conectar ----------
Passo 6 "Ligando o bot e abrindo o painel"
function BotNoAr { try { Invoke-RestMethod "$Painel/api/ping" -TimeoutSec 3 | Out-Null; return $true } catch { return $false } }
function Conectado {
    try { return [bool](Invoke-RestMethod "$Painel/api/status" -TimeoutSec 5).whatsapp.conectado } catch { return $false }
}
Start-Process $Wscript -ArgumentList "`"$(Join-Path $Destino 'abrir_painel.vbs')`""
$limite = (Get-Date).AddSeconds(45)
while (-not (BotNoAr)) {
    if ((Get-Date) -gt $limite) { Falha "O bot não ligou. Veja o arquivo bot.log em $Destino e envie para análise." }
    Start-Sleep 2
}
Ok "Bot ligado e painel aberto"
if (-not (Conectado)) {
    Write-Host ""
    Write-Host "   Se o painel mostrar um QR code, escaneie com o WhatsApp Business da biblioteca:" -ForegroundColor White
    Write-Host "   Aparelhos conectados > Conectar um aparelho" -ForegroundColor White
    $limite = (Get-Date).AddMinutes(5)
    while (-not (Conectado)) {
        if ((Get-Date) -gt $limite) { Aviso "Ainda não conectado. Pode fechar o instalador e escanear depois pelo painel."; break }
        Start-Sleep 3
    }
}
if (Conectado) { Ok "WhatsApp conectado" }

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "  Instalação concluída (versão $Versao)." -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "  Para abrir o painel: ícone 'BEESC BOT' na área de trabalho."
Write-Host "  Pelo painel você edita as mensagens, o horário, testa a busca de"
Write-Host "  livros e acompanha o atendimento. Não há mais janela preta: o bot"
Write-Host "  roda em segundo plano."
Write-Host ""
Read-Host "Pressione Enter para fechar o instalador"
