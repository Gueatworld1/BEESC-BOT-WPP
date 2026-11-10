<p align="center"><img src="docs/imagens/logo.png" width="120" alt="Logo do BEESC BOT"></p>

<h1 align="center">BEESC BOT</h1>

<p align="center">Atendimento automático no WhatsApp para a Biblioteca da Escola de Engenharia de São Carlos (EESC-USP).<br>
Roda num computador da biblioteca, sem servidor externo, sem Docker e sem precisar de administrador.</p>

---

## O que ele faz

- **Menu de boas-vindas** na primeira mensagem de cada pessoa, com respostas prontas para cada opção (empréstimo, ficha catalográfica, EEB, sala multiuso, Turnitin, doações, achados e perdidos, cursos).
- **Busca de livros no Dedalus:** a pessoa escreve o livro do jeito que quiser (“cálculo 2 do Stewart edição 5”) e recebe a localização e a disponibilidade. Mostra primeiro a EESC; só procura nas outras bibliotecas de São Carlos se a EESC não tiver o livro ou se estiver tudo emprestado.
- **Encaminha para a equipe:** quem digita *atendimento* (ou pede a sala multiuso) recebe a resposta e o bot sai da conversa por algumas horas, para a equipe atender pelo celular. Fora do horário, avisa quando a equipe volta.
- **Painel de controle** em forma de aplicativo, para editar mensagens e horário, testar a busca, ver a atividade e as estatísticas por pessoa.
- **Vários computadores:** com uma pasta compartilhada da rede, todos usam o mesmo banco de dados, e só um responde de cada vez. Se ele desligar, outro assume sozinho.

| Início | Mensagens | Pessoas |
|---|---|---|
| ![Tela inicial](docs/imagens/inicio.png) | ![Edição de mensagens](docs/imagens/mensagens.png) | ![Estatísticas por pessoa](docs/imagens/pessoas.png) |

## Instalação

1. Entre no Windows com a conta que vai ficar sempre aberta no computador (os outros usuários podem usar “Trocar de usuário”).
2. Baixe o `.zip` da [página de versões](../../releases) e extraia tudo.
3. Dê dois cliques em **`instalar.bat`**.
4. O painel abre sozinho. Escaneie o QR code com o WhatsApp Business da biblioteca: *Aparelhos conectados → Conectar um aparelho*.

O instalador baixa o que faltar (Node.js portátil e Python, direto dos sites oficiais), não exige administrador, nem winget, nem reinício. Ele cria o ícone **BEESC BOT** na área de trabalho e no menu Iniciar, e faz o bot ligar sozinho, em segundo plano, quando a conta entra no Windows.

**Para atualizar**, rode o `instalar.bat` de uma versão nova. A instalação anterior é apagada; ficam só as mensagens e estatísticas (`respostas.db`), a conexão com o WhatsApp (`auth\`) e a configuração da pasta compartilhada (`local.json`).

### Vários computadores

Instale em cada computador e, no painel de cada um, vá em **Ajustes → Vários computadores** e informe a mesma pasta da rede (por exemplo `\\servidor\biblioteca\beesc-bot`). Cada computador escaneia o QR code uma vez; o WhatsApp aceita até 4 aparelhos conectados.

## Como funciona

```
WhatsApp ⇄ ponte.js (Node.js + Baileys) ⇄ bot.py (Python + Flask) ⇄ banco SQLite
                                               │
                                               ├─ dedalus.py → catálogo Dedalus (USP)
                                               └─ painel/ → http://127.0.0.1:5000
```

| Arquivo | Papel |
|---|---|
| `arquivos/ponte.js` | Conecta ao WhatsApp como aparelho conectado, repassa as mensagens ao bot e envia as respostas. |
| `arquivos/bot.py` | Decide o que responder, serve o painel e coordena vários computadores. |
| `arquivos/criar_banco.py` | Banco de dados e textos padrão das mensagens. |
| `arquivos/dedalus.py` | Busca de livros no Dedalus, com prioridade para a EESC. |
| `arquivos/painel/` | Interface do painel (HTML único, sem dependências externas). |
| `arquivos/*.vbs` | Ligam o bot sem janela e abrem o painel como aplicativo. |
| `instalador.ps1` | Instala, atualiza e cria os atalhos. |

Tudo escuta só em `127.0.0.1`: ninguém na rede acessa o painel ou o bot. Detalhes em [docs/ARQUITETURA.md](docs/ARQUITETURA.md).

### Testar a busca de livros pelo terminal

```powershell
cd ([Environment]::GetFolderPath("MyDocuments") + "\whatsapp-bot")
py -3 testar_dedalus.py calculo 2 stewart edicao 5
```

O teste mostra cada etapa e o tempo da busca, e salva as páginas do Dedalus em `dedalus_debug_*.html` para diagnóstico.

## Avisos importantes

- **Conexão não oficial com o WhatsApp.** A ponte usa o [Baileys](https://github.com/WhiskeySockets/Baileys), que se conecta como o WhatsApp Web e viola os termos do WhatsApp. Existe risco de o número ser banido. O bot só responde a quem escreveu primeiro e não faz envio em massa, o que reduz bastante o risco, mas não o elimina.
- **Consulta ao Dedalus.** O `robots.txt` do Dedalus pede que programas não acessem o site. O bot faz uma consulta por pedido de usuário (como uma pessoa no navegador) e guarda o resultado por 10 minutos. Antes de liberar ao público, combine com o SIBi/informática; se houver acesso oficial (X-Server ou Z39.50 do Aleph), ele é preferível.
- **Nunca publique** a pasta `auth\` nem o arquivo `respostas.db`: o primeiro dá acesso ao WhatsApp da biblioteca e o segundo tem nomes e números de usuários. O `.gitignore` já os exclui.

## Gerar uma versão

Crie uma tag no formato `vX.Y` e envie ao GitHub. O workflow em `.github/workflows/release.yml` monta o `.zip` de instalação e publica na página de versões:

```bash
git tag v3.0
git push origin v3.0
```

## Licença

[MIT](LICENSE).
