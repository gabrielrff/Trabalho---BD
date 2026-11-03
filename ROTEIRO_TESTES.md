# Roteiro de testes — Sistema de Gestão de Eventos e Espaços

Este roteiro serve para qualquer integrante do grupo instalar e testar o projeto completo na própria máquina: banco, dados, triggers, consultas e protótipo com Ollama.

> **Este arquivo não faz parte da entrega.** Não o coloque no `.zip` final (veja o checklist no fim do roteiro).

**Tempo estimado:** de 30 a 45 minutos na primeira vez. A maior parte é o download do modelo, de 5,2 GB.

---

## 0. Estrutura esperada da pasta

```
TrabBD_NEW/
├── Projeto.txt          ← DDL (seção 3) e consultas (seção 4) ficam aqui
├── DML.sql              ← dados de teste
├── ER.pdf / .xml        ← modelo E/R (draw.io)
├── Relacional.pdf / .mmd← modelo relacional (mermaid)
└── Prototipo/
    ├── main.py
    ├── config.json
    └── requirements.txt
```

O protótipo lê o `Projeto.txt` e o `DML.sql` **da pasta acima de `Prototipo/`**. Por isso, não mude essa estrutura.

---

## 1. Requisitos de software

| Software | Versão | Como verificar |
|---|---|---|
| PostgreSQL | 13 ou superior (testado no 18) | `psql --version` |
| Python | 3.11 ou superior | `python --version` |
| Ollama | qualquer versão recente (testado na 0.40) | `ollama --version` |
| Modelo | `qwen3:8b` | `ollama list` |

**Hardware:** o `qwen3:8b` ocupa cerca de 6 GB de memória. Com 8 GB de RAM e sem GPU dedicada ele funciona, mas leva de 1 a 3 min por pergunta. A primeira pergunta leva até 4 min, porque o modelo é carregado na memória. Com GPU de 8 GB ou mais, a resposta sai em poucos segundos.

---

## 2. Instalar o PostgreSQL

- **Windows:** use o instalador de https://www.postgresql.org/download/windows/ e anote a senha do usuário `postgres`.
- **Linux (Debian/Ubuntu):** `sudo apt install postgresql postgresql-contrib`
- **macOS:** `brew install postgresql@17` ou Postgres.app.

> **Windows: `psql` não é reconhecido.** O instalador não coloca o `psql` no PATH. Escolha uma das saídas:
>
> - **Caminho completo:** no PowerShell, o `&` na frente é obrigatório.
>   ```powershell
>   & "C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -c "CREATE DATABASE eventos"
>   ```
> - **Só para a janela atual:**
>   ```powershell
>   $env:Path += ";C:\Program Files\PostgreSQL\17\bin"
>   ```
> - **Para sempre:** feche e abra o PowerShell depois.
>   ```powershell
>   $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
>   [Environment]::SetEnvironmentVariable("Path", "$userPath;C:\Program Files\PostgreSQL\17\bin", "User")
>   ```
>
> Troque `17` pela versão instalada (veja em `C:\Program Files\PostgreSQL\`).

> **Mais de uma versão instalada?** Cada versão usa uma porta. A primeira instalada costuma ficar na 5432 e a segunda na 5433. Para descobrir qual é qual, veja a linha `port =` em `C:\Program Files\PostgreSQL\<versão>\data\postgresql.conf`. Use nos comandos `-p <porta>` e o mesmo valor em `"port"` no `config.json`.

---

## 3. Criar o banco `eventos`

```bash
psql -U postgres -c "CREATE DATABASE eventos"
```

(No pgAdmin: botão direito em *Databases* → *Create* → *Database...* → nome `eventos`.)

---

## 4. Criar a estrutura (DDL)

O DDL oficial é a **seção 3 do `Projeto.txt`**. Execute-o com o usuário `postgres` ou com o dono do banco, porque o DDL roda um `ALTER DATABASE` para configurar o `search_path`. Escolha **uma** das opções abaixo.

### Opção A — como o professor fará (recomendada para validar a entrega)

1. Abra o `Projeto.txt`.
2. Copie tudo o que está entre a linha `3. DDL COMPLETO` e a linha `4. CONSULTAS`, **sem as linhas de `=====`**.
3. No pgAdmin, abra o *Query Tool* no banco `eventos`, cole o texto e execute (F5).
4. **Resultado esperado:** a execução termina sem erros. Pode aparecer o aviso `esquema "eventos" não existe, ignorando`, que é normal na primeira vez.

### Opção B — pelo terminal

Na pasta do projeto, extraia o DDL e execute:

```bash
python -c "import re;t=open('Projeto.txt',encoding='utf-8').read().split('3. DDL COMPLETO',1)[1].split('4. CONSULTAS',1)[0];open('ddl_extraido.sql','w',encoding='utf-8').write('\n'.join(l for l in t.splitlines() if not re.fullmatch(r'\s*=+\s*',l)))"
psql -U postgres -d eventos -v ON_ERROR_STOP=1 -f ddl_extraido.sql
```

Depois apague o `ddl_extraido.sql`, que não faz parte da entrega.

### Opção C — pelo protótipo

Use a opção **I** do menu (seção 9 deste roteiro). Ela executa o DDL e o DML de uma vez.

> **Atenção:** o DDL começa com `DROP SCHEMA IF EXISTS eventos CASCADE`, ou seja, **apaga todos os dados**. Sempre execute o DML de novo depois de executar o DDL.

---

## 5. Carregar os dados (DML)

```bash
psql -U postgres -d eventos -v ON_ERROR_STOP=1 -f DML.sql
```

No pgAdmin, abra o `DML.sql` no *Query Tool* e execute.

O arquivo pode ser executado várias vezes, porque começa com `TRUNCATE`. **Não reordene os comandos:** vários estados (lista de espera, histórico, cancelamentos) são produzidos pelos triggers, na ordem em que estão no arquivo.

### Verificação rápida

Rode no `psql` ou no pgAdmin, conectado ao banco `eventos`:

```sql
SELECT (SELECT count(*) FROM evento)           AS eventos,
       (SELECT count(*) FROM agente)           AS agentes,
       (SELECT count(*) FROM sessao)           AS sessoes,
       (SELECT count(*) FROM inscricao_evento) AS insc_evento,
       (SELECT count(*) FROM inscricao_sessao) AS insc_sessao,
       (SELECT count(*) FROM alteracao_sessao) AS alteracoes;
```

**Resultado esperado:** `5 | 36 | 26 | 47 | 47 | 4`

> Se aparecer `relação "evento" não existe`, a conexão foi aberta antes do DDL. Reconecte-se ou rode `SET search_path TO eventos;`.

---

## 6. Testar os triggers

Cada teste roda dentro de `BEGIN ... ROLLBACK`, então **nenhum altera os dados**. Cole um bloco por vez no `psql`.

Nos testes de erro, o erro **é** o comportamento correto. O `ROLLBACK` em seguida desfaz a transação.

> **Usando o pgAdmin (Query Tool)?** Ele se comporta diferente do `psql` em dois pontos:
>
> 1. Depois de um erro, o pgAdmin para e **não executa** o `ROLLBACK` seguinte.
> 2. Ele mostra só o resultado do **último** comando.
>
> Por isso, no pgAdmin:
> - **Testes de erro (T1, T2a–c, T3, T6a–b):** execute **só o comando**, sem `BEGIN` e sem `ROLLBACK`. Como o comando falha, nada é gravado.
> - **Testes de efeito (T4, T5, T7, T8):** execute o bloco **sem** o `ROLLBACK` final, para que o resultado do `SELECT` apareça. Confira o resultado e **depois execute `ROLLBACK;` sozinho**.
> - Se aparecer `current transaction is aborted`, execute `ROLLBACK;` e repita o teste.
> - **No fim, confira:** `SELECT (SELECT count(*) FROM inscricao_evento), (SELECT count(*) FROM alteracao_sessao);` deve dar `47 | 4`. Se der outro valor, execute o `DML.sql` de novo.

| # | O que testa | Comando | Resultado esperado |
|---|---|---|---|
| T1 | Pessoa e organização são disjuntas | `BEGIN; INSERT INTO organizacao VALUES ('P01', '11111111000111'); ROLLBACK;` | ERRO: `Agente P01 ja e uma pessoa` |
| T2a | Sessão dentro do período do evento | `BEGIN; INSERT INTO sessao (atividade_id, num_sessao, espaco_id, data, hora_inicio, hora_fim) VALUES ('A09', 2, 'AUD_PRINC', '2026-12-01', '09:00', '10:00'); ROLLBACK;` | ERRO: `Sessao em 2026-12-01 fora do periodo do evento` |
| T2b | Conflito de espaço | `BEGIN; INSERT INTO sessao (atividade_id, num_sessao, espaco_id, data, hora_inicio, hora_fim) VALUES ('A09', 2, 'SALA_201', '2026-11-17', '10:00', '11:00'); ROLLBACK;` | ERRO: `Conflito de espaco: SALA_201 ja ocupado pela sessao A11/1` |
| T2c | Vagas da sessão não passam da capacidade da sala | `BEGIN; UPDATE sessao SET vagas_limite = 50 WHERE atividade_id = 'A13' AND num_sessao = 1; ROLLBACK;` | ERRO: `vagas_limite (50) excede a capacidade do espaco SALA_REUNIAO (12)` |
| T3 | Recurso exigido precisa existir no espaço | `BEGIN; UPDATE sessao SET espaco_id = 'SALA_102' WHERE atividade_id = 'A10' AND num_sessao = 1; ROLLBACK;` | ERRO: `Recurso COMP indisponivel no espaco: exigido 30, disponivel 0` |
| T6a | Inscrição em sessão exige inscrição no evento | `BEGIN; INSERT INTO inscricao_sessao (atividade_id, num_sessao, pessoa_id) VALUES ('A13', 1, 'P30'); ROLLBACK;` | ERRO: `Pessoa P30 nao possui inscricao confirmada no evento EV03` |
| T6b | Programação geral não aceita inscrição específica | `BEGIN; INSERT INTO inscricao_sessao (atividade_id, num_sessao, pessoa_id) VALUES ('A09', 1, 'P21'); ROLLBACK;` | ERRO: `Sessao A09/1 pertence a programacao geral e nao exige inscricao` |

Os testes abaixo **não dão erro**: eles mostram o efeito do trigger no `SELECT`.

**T4 — histórico automático de alterações**
```sql
BEGIN;
SET LOCAL app.motivo_alteracao = 'Teste do roteiro';
UPDATE sessao SET hora_inicio = '15:00', hora_fim = '18:00'
WHERE atividade_id = 'A13' AND num_sessao = 1;
SELECT num_alteracao, hora_inicio_anterior, espaco_anterior, motivo
FROM alteracao_sessao WHERE atividade_id = 'A13';
ROLLBACK;
```
**Resultado esperado:** 1 linha → `1 | 14:00:00 | SALA_REUNIAO | Teste do roteiro`

**T5 — evento lotado manda a inscrição para a lista de espera**
```sql
BEGIN;
INSERT INTO inscricao_evento (evento_id, pessoa_id) VALUES ('EV05', 'P30');
SELECT pessoa_id, status FROM inscricao_evento
WHERE evento_id = 'EV05' AND pessoa_id = 'P30';
ROLLBACK;
```
**Resultado esperado:** `P30 | LISTA_ESPERA`

**T7 — cancelamento promove o primeiro da lista de espera**
```sql
BEGIN;
UPDATE inscricao_sessao SET status = 'CANCELADA'
WHERE atividade_id = 'A17' AND num_sessao = 1 AND pessoa_id = 'P21';
SELECT pessoa_id, status FROM inscricao_sessao
WHERE atividade_id = 'A17' ORDER BY pessoa_id;
ROLLBACK;
```
**Resultado esperado:** P21 aparece `CANCELADA` e **P26 passa a `CONFIRMADA`**, embora antes estivesse em `LISTA_ESPERA`.

**T8 — sessão cancelada cancela todas as inscrições nela**
```sql
BEGIN;
UPDATE sessao SET status = 'CANCELADA' WHERE atividade_id = 'A13' AND num_sessao = 1;
SELECT pessoa_id, status FROM inscricao_sessao
WHERE atividade_id = 'A13' ORDER BY pessoa_id;
ROLLBACK;
```
**Resultado esperado:** as 5 inscrições (P14, P15, P20, P21, P22) aparecem como `CANCELADA`.

---

## 7. Instalar o Ollama e o modelo

1. **Instale o Ollama:**
   - **Windows:** `winget install Ollama.Ollama`, ou use o instalador de https://ollama.com/download.
   - **Linux:** `curl -fsSL https://ollama.com/install.sh | sh`
   - **macOS:** use o instalador de https://ollama.com/download.
2. **Baixe o modelo** (cerca de 5,2 GB):
   ```bash
   ollama pull qwen3:8b
   ```
3. **Verifique:**
   ```bash
   ollama list                               # deve listar qwen3:8b
   curl http://localhost:11434/api/version   # deve responder {"version": ...}
   ```

No Windows, o servidor do Ollama inicia sozinho junto com o sistema, e aparece um ícone na bandeja. No Linux, se não estiver rodando, use `ollama serve`.

---

## 8. Preparar o protótipo

Dentro da pasta `Prototipo/`:

```bash
python -m pip install -r requirements.txt
```

Para não misturar com outros projetos, você pode usar um ambiente virtual antes (é opcional):

```bash
python -m venv .venv
.venv\Scripts\activate        # Windows
source .venv/bin/activate     # Linux/macOS
python -m pip install -r requirements.txt
```

> **Importante:** se criar a `.venv`, crie-a **fora** da pasta `Prototipo/` ou apague-a antes da entrega, porque a pasta só pode conter os 3 arquivos.

Edite o `config.json` **apenas com os dados da sua máquina**, normalmente só a senha:

```json
"database": { "host": "localhost", "port": 5432, "dbname": "eventos",
              "user": "postgres", "password": "SUA_SENHA" }
```

> **Antes de entregar**, volte a senha para `"postgres"`, que é o padrão do enunciado.

---

## 9. Executar o protótipo

```bash
cd Prototipo
python main.py
```

### Roteiro dentro do programa

1. **Conexão:** o programa mostra os parâmetros do `config.json`. Responda **ENTER**, que equivale a "S", para usá-los. Para testar outro banco, responda `n` e digite cada valor. **Resultado esperado:** `Conectado a 'eventos' em localhost:5432.`
2. **(Opcional) Opção `I`:** recria o banco a partir do `Projeto.txt` e do `DML.sql`. É preciso digitar `SIM`.
3. **Opções `1` a `5`:** executam as consultas da seção 4 do `Projeto.txt`.

   | Opção | Consulta | Linhas esperadas |
   |---|---|---|
   | 1 | Programação do Simpósio de BD | 8 |
   | 2 | Sessões com ocupação de 50% ou mais | 3 |
   | 3 | Pessoas com 2 ou mais papéis | 13 |
   | 4 | Espaços alternativos por sessão | 15 |
   | 5 | Top 3 de carga horária por evento | 17 |

   Tabelas largas aparecem no formato de um registro por bloco. Isso é intencional.

4. **Opção `P`:** faça perguntas em linguagem natural. O programa mostra o SQL gerado pelo modelo e o SQL realmente executado, em que as buscas por texto foram ajustadas para ignorar acentos. Depois mostra o resultado. Se der erro, ele oferece pedir uma correção ao modelo, até 2 vezes.

   | Pergunta | Resposta correta (segundo o DML) |
   |---|---|
   | Quais espaços possuem projetor? | 6: Auditório B, Auditório Principal, Laboratório 1, Salas 101, 102 e 201 |
   | Quais sessões têm pessoas na lista de espera? | Workshop de Modelagem de Dados (Vinícius Araújo) e PostgreSQL: Administração Básica (Igor Monteiro) |
   | Quem foram os palestrantes da Semana da Computação de 2026? | Eduardo Nascimento |
   | Quais eventos foram promovidos pela USP? | Semana da Computação (12ª e 13ª edições) e Simpósio Brasileiro de Banco de Dados |
   | Em quais sessões a Ana Clara Mendes está inscrita? | 8 sessões (7 confirmadas e 1 cancelada) |
   | Liste as sessões do dia 18 de novembro de 2026 com horário e espaço. | Sessão Técnica (Sala 201, 9h) e Painel: Privacidade e LGPD (Auditório B, 14h) |
   | Qual o histórico de alterações do Painel de Privacidade e LGPD? | 2 alterações: mudança de horário, depois de sala |
   | Quantos inscritos confirmados tem cada evento? | 12ª ed.: 10, 13ª ed.: 11, Simpósio: 11, Feira: 7, Treinamento: 5 |

   > O modelo não é determinístico: a mesma pergunta pode gerar SQLs diferentes a cada vez. Erros ocasionais de interpretação são esperados num modelo de 8B. O que se avalia é a integração funcionando: pergunta → SQL → execução → resultado ou mensagem de erro.

5. **Segurança:** o SQL gerado roda em transação **somente leitura** e com limite de 15 s. Se quiser confirmar, peça ao modelo para "apagar todos os eventos". A execução deve ser recusada pelo PostgreSQL e nada é apagado.
6. **Opção `0`:** sai do programa.

---

## 10. Problemas comuns

| Sintoma | Causa provável e solução |
|---|---|
| `psql : O termo 'psql' não é reconhecido...` | O `psql` não está no PATH. Veja o aviso no passo 2. |
| `autenticação do tipo senha falhou para o usuário "postgres"` | A senha no `config.json` está errada. Edite o arquivo ou responda `n` na conexão e digite a senha. |
| `banco de dados "eventos" não existe` | Falta o passo 3 deste roteiro. |
| `relação "evento" não existe` (no protótipo) | O DDL não foi executado. Use a opção `I` ou o passo 4. |
| `Erro: Projeto.txt não encontrado.` | O `main.py` não está numa pasta `Prototipo/` logo abaixo da pasta do `Projeto.txt`. |
| `Erro ao acessar o Ollama: Failed to connect` | O Ollama não está rodando. Abra o aplicativo ou rode `ollama serve`. |
| `model "qwen3:8b" not found` | Falta rodar `ollama pull qwen3:8b`. |
| A pergunta em linguagem natural demora vários minutos | O computador está sem GPU ou com pouca RAM. Feche outros programas. A primeira pergunta é sempre a mais lenta. |
| `ModuleNotFoundError: No module named 'psycopg'` | Falta o passo 8, ou o `python` usado não é o do ambiente onde os pacotes foram instalados. |
| Acentos estranhos no `psql` do Windows | Rode `chcp 65001` antes do `psql`. O `DML.sql` já define `client_encoding` como UTF-8. |
| Pasta `__pycache__` dentro de `Prototipo/` | É criada pelo Python ao executar. **Apague antes da entrega.** |

---

## 11. Checklist de entrega (seção 12 do enunciado)

Cada item não cumprido custa **0,5 ponto**.

- [ ] `ER.pdf` e o `.xml` do draw.io
- [ ] `Relacional.pdf` e o arquivo-fonte do mermaid (`.mmd`). **Exporte o PDF de novo:** o `.mmd` ganhou as colunas geradas `duracao_dias` e `duracao_minutos`.
- [ ] `Projeto.txt` fiel ao template, com GRUPO e INTEGRANTES preenchidos
- [ ] `DML.sql`
- [ ] `Prototipo.zip` contendo só `main.py`, `config.json` (com a senha padrão `postgres`) e `requirements.txt`, sem `__pycache__` nem `.venv`
- [ ] `Instrucoes.txt`: integrantes, requisitos, criação da base, DML, execução do protótipo, modelo do Ollama e limitações
- [ ] Tudo num único arquivo compactado
- [ ] **Não incluir:** `ROTEIRO_TESTES.md`, `DDL.sql`, `Consultas.txt` e `ddl_extraido.sql`, que são só arquivos de trabalho
- [ ] Teste final numa máquina "limpa": criar o banco → executar o DDL copiado do `Projeto.txt` → executar o `DML.sql` → `python main.py`
