# Sistema de Gestão de Eventos e Espaços — SCC0640

Projeto de curso de Bases de Dados. Os integrantes e o modelo utilizado estão no cabeçalho do `Projeto.txt`.

O teste é feito inteiramente pelo **protótipo de linha de comando**. Ele cria a estrutura do banco a partir do DDL do `Projeto.txt`, carrega os dados do `DML.sql`, executa as 5 consultas do projeto e converte perguntas em linguagem natural para SQL com um modelo local via Ollama.

---

## Requisitos

- PostgreSQL 13 ou superior (testado nas versões 17 e 18)
- Python 3.11 ou superior
- Ollama em execução, com o modelo baixado:
  ```bash
  ollama pull qwen3:8b
  ```

---

## Passo a passo

### 1. Criar um banco vazio chamado `eventos`

```bash
psql -U postgres -c "CREATE DATABASE eventos"
```

Também pode ser criado pelo pgAdmin: *Databases → Create → Database*.

Tabelas e dados **não** precisam ser criados manualmente. O próprio protótipo faz isso no passo 4.

### 2. Instalar as dependências

```bash
cd Prototipo
python -m pip install -r requirements.txt
```

### 3. Ajustar o `config.json`

Edite apenas os valores que forem diferentes no seu ambiente, normalmente a senha do PostgreSQL:

```json
{
  "database": { "host": "localhost", "port": 5432, "dbname": "eventos",
                "user": "postgres", "password": "postgres" },
  "ollama":   { "host": "http://localhost:11434", "model": "qwen3:8b" }
}
```

Nenhum arquivo `.py` precisa ser alterado.

### 4. Executar

```bash
python main.py
```

1. **Conexão:** o programa mostra os parâmetros do `config.json`. Pressione **ENTER** para usá-los, ou responda `n` para digitar outros valores.
2. **Criar a estrutura e carregar os dados:** escolha a opção **`I`** e digite `SIM` para confirmar. O programa:
   - executa o DDL da seção **3. DDL COMPLETO** do `Projeto.txt`, que cria o schema `eventos` com tipos, domínios, tabelas, funções e 8 triggers;
   - carrega o `DML.sql`.

   **Resultado esperado:** `Estrutura criada.` e `Dados carregados.`

   A opção `I` pode ser repetida quando quiser: ela sempre recria o banco do zero.

3. **Consultas do projeto:** as opções **`1`** a **`5`** executam as consultas da seção 4 do `Projeto.txt`, lidas diretamente do arquivo.

   | Opção | Consulta | Linhas esperadas |
   |---|---|---|
   | `1` | Programação do Simpósio Brasileiro de Banco de Dados | 8 |
   | `2` | Sessões com inscrição específica com 50% ou mais de ocupação | 3 |
   | `3` | Pessoas com dois ou mais tipos de papel | 13 |
   | `4` | Espaços alternativos para cada sessão programada | 15 |
   | `5` | As 3 pessoas com maior carga horária em cada evento | 17 |

4. **Pergunta em linguagem natural:** opção **`P`**.
5. **Sair:** opção **`0`**.

---

## Perguntas em linguagem natural (opção `P`)

O fluxo é este:

1. A pergunta é enviada ao modelo junto com o esquema extraído do DDL, um mapa das junções principais, as regras do domínio e alguns exemplos.
2. O programa mostra o **SQL gerado pelo modelo**.
3. Buscas textuais no formato `coluna ILIKE '%frase%'` são reescritas como busca por palavras-chave, sem acentos e sem pontuação. Quando isso acontece, o **SQL executado** também é exibido.
4. A consulta roda em uma **transação somente leitura**, com limite de 15 s. Comandos que alteram dados são recusados pelo PostgreSQL.
5. O programa exibe o resultado. Em caso de erro, mostra a mensagem do PostgreSQL e oferece pedir uma correção ao modelo, até 2 vezes.

Exemplos de perguntas e as respostas corretas segundo os dados carregados:

| Pergunta | Resposta correta |
|---|---|
| Quais espaços possuem projetor? | Auditório B, Auditório Principal, Laboratório 1, Salas 101, 102 e 201 |
| Quais sessões têm pessoas na lista de espera? | Workshop de Modelagem de Dados e PostgreSQL: Administração Básica |
| Quem foram os palestrantes da Semana da Computação de 2026? | Eduardo Nascimento |
| Quais eventos foram promovidos pela USP? | Semana da Computação (12ª e 13ª edições) e Simpósio Brasileiro de Banco de Dados |
| Qual o histórico de alterações do Painel de Privacidade e LGPD? | 2 alterações (horário e, depois, espaço) |
| Quantas vagas ainda restam em cada sessão do Tutorial de Otimização de Consultas? | Sessão 1: 26; sessão 2: 27 |

---

## Mensagens de erro possíveis

| Mensagem | Causa |
|---|---|
| `Falha na conexão: ... banco de dados "eventos" não existe` | O banco do passo 1 não foi criado |
| `Falha na conexão: ... autenticação do tipo senha falhou` | Senha incorreta no `config.json`. Também é possível responder `n` na conexão e digitá-la. |
| `relação "..." não existe` ao executar uma consulta | A opção `I` ainda não foi executada |
| `Erro ao acessar o Ollama` | O Ollama não está em execução, ou o modelo do `config.json` não foi baixado |

---

## Limitações conhecidas

- **Desempenho do modelo:** com o qwen3:8b rodando em CPU (máquina de teste com 8 GB de RAM), cada pergunta leva de 1 a 3 minutos. A primeira leva mais, porque inclui o carregamento do modelo. Com GPU, a resposta é bem mais rápida. O protótipo desativa o modo de raciocínio do qwen3 (`think=False`), que sozinho levaria mais de 10 minutos por pergunta. Se o modelo configurado não aceitar esse parâmetro, a chamada é repetida sem ele.
- **Qualidade do SQL gerado:** o modelo não é determinístico. Num teste com 11 perguntas, todas geraram SQL executável, e 9 retornaram a resposta correta. Os erros observados foram de interpretação: por exemplo, confundir o nome de um evento com o título de uma atividade, o que gera uma consulta válida com resultado vazio.
- **Busca textual:** a reescrita das buscas cobre o formato `coluna ILIKE '%texto%'`. Outros formatos de comparação de texto são executados como o modelo os gerou.
- **Permissão:** a opção `I` executa um `ALTER DATABASE` para configurar o `search_path`. Por isso, o usuário do `config.json` deve ser o dono do banco `eventos` ou o `postgres`.
