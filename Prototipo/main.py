"""Prototipo CLI - Sistema de Gestao de Eventos e Espacos (SCC0640).

Executa as consultas definidas em Projeto.txt e converte perguntas em
linguagem natural para SQL usando um modelo local via Ollama.
"""

import getpass
import json
import re
import shutil
import sys
import textwrap
import unicodedata
from pathlib import Path

import psycopg
from ollama import Client, ResponseError

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(errors="replace")

BASE_DIR = Path(__file__).resolve().parent

with open(BASE_DIR / "config.json", encoding="utf-8") as f:
    config = json.load(f)

projeto_path = BASE_DIR.parent / "Projeto.txt"

if not projeto_path.exists():
    print("Erro: Projeto.txt não encontrado.")
    raise SystemExit(1)

projeto = projeto_path.read_text(encoding="utf-8")

try:
    ddl = projeto.split("3. DDL COMPLETO", 1)[1]
    ddl = ddl.split("4. CONSULTAS", 1)[0]
    ddl = ddl.strip()
except IndexError:
    print("Erro: seção '3. DDL COMPLETO' não encontrada em Projeto.txt.")
    raise SystemExit(1)

MAX_LINHAS = 100      # linhas exibidas por resultado
MAX_LARGURA = 45      # largura maxima de cada coluna na tela
MAX_TENTATIVAS = 3    # geracoes de SQL por pergunta (1 + 2 correcoes)


# ------------------------------------------------------------
# Leitura do Projeto.txt
# ------------------------------------------------------------
def remover_separadores(texto):
    """Remove as linhas '=====' do template, que nao sao SQL."""
    linhas = [l for l in texto.splitlines() if not re.fullmatch(r"\s*=+\s*", l)]
    return "\n".join(linhas).strip()


def extrair_consultas(texto):
    """Le a secao '4. CONSULTAS' e devolve [{numero, objetivo, sql}]."""
    try:
        secao = texto.split("4. CONSULTAS", 1)[1]
    except IndexError:
        return []
    secao = secao.split("FIM DO ARQUIVO", 1)[0]
    secao = remover_separadores(secao)

    consultas = []
    blocos = re.split(r"^CONSULTA\s+(\d+)\s*$", secao, flags=re.MULTILINE)
    for i in range(1, len(blocos) - 1, 2):
        numero, corpo = blocos[i], blocos[i + 1]
        objetivo = re.search(r"^OBJETIVO:\s*(.*)$", corpo, flags=re.MULTILINE)
        sql = re.search(r"^SQL:\s*(.*)", corpo, flags=re.MULTILINE | re.DOTALL)
        if sql and sql.group(1).strip():
            consultas.append({
                "numero": numero,
                "objetivo": objetivo.group(1).strip() if objetivo else "",
                "sql": sql.group(1).strip(),
            })
    return consultas


def esquema_resumido(texto_ddl):
    """Extrai apenas tipos, dominios e tabelas do DDL (sem funcoes/triggers),
    para caber no contexto do modelo."""
    sem_comentarios = re.sub(r"--[^\n]*", "", texto_ddl)
    comandos = re.findall(
        r"CREATE\s+(?:TYPE|DOMAIN|TABLE)\b.*?;\s*$",
        sem_comentarios,
        flags=re.IGNORECASE | re.DOTALL | re.MULTILINE,
    )
    resumo = []
    for cmd in comandos:
        cmd = re.sub(r"\s+ON\s+(?:DELETE|UPDATE)\s+(?:SET\s+NULL|SET\s+DEFAULT|NO\s+ACTION|\w+)",
                     "", cmd, flags=re.IGNORECASE)
        linhas = [re.sub(r"\s+", " ", l).strip() for l in cmd.splitlines()]
        linhas = [l for l in linhas if l and not l.upper().startswith("CONSTRAINT CK_")]
        resumo.append("\n".join(linhas))
    return "\n\n".join(resumo)


DDL_SQL = remover_separadores(ddl)
CONSULTAS = extrair_consultas(projeto)
ESQUEMA = esquema_resumido(DDL_SQL)


# ------------------------------------------------------------
# Conexao com o PostgreSQL
# ------------------------------------------------------------
def ler_parametros():
    """Permite confirmar ou alterar os parametros do config.json."""
    db = dict(config["database"])
    print("\nParâmetros de conexão (config.json):")
    print(f"  host={db['host']}  port={db['port']}  dbname={db['dbname']}  user={db['user']}")
    resp = input("Usar esses parâmetros? [S/n]: ").strip().lower()
    if resp in ("n", "nao", "não"):
        print("Pressione ENTER para manter o valor entre colchetes.")
        for chave in ("host", "port", "dbname", "user"):
            valor = input(f"  {chave} [{db[chave]}]: ").strip()
            if valor:
                db[chave] = int(valor) if chave == "port" else valor
        senha = getpass.getpass("  password [manter]: ")
        if senha:
            db["password"] = senha
    return db


def conectar():
    while True:
        db = ler_parametros()
        try:
            conn = psycopg.connect(
                host=db["host"],
                port=db["port"],
                dbname=db["dbname"],
                user=db["user"],
                password=db["password"]
            )
            conn.autocommit = True
            conn.execute("SET search_path TO eventos, public")
            print(f"Conectado a '{db['dbname']}' em {db['host']}:{db['port']}.")
            return conn
        except (psycopg.Error, ValueError) as e:
            print(f"\nFalha na conexão: {e}")
            if input("Tentar novamente? [S/n]: ").strip().lower() in ("n", "nao", "não"):
                raise SystemExit(1)


# ------------------------------------------------------------
# Execucao e exibicao
# ------------------------------------------------------------
def formatar(valor):
    if valor is None:
        return ""
    texto = str(valor).replace("\n", " ")
    return texto if len(texto) <= MAX_LARGURA else texto[: MAX_LARGURA - 3] + "..."


def imprimir_tabela(colunas, linhas):
    if not linhas:
        print("\n(nenhuma linha retornada)")
        return
    exibidas = [[formatar(v) for v in linha] for linha in linhas[:MAX_LINHAS]]
    larguras = [len(c) for c in colunas]
    for linha in exibidas:
        for i, v in enumerate(linha):
            larguras[i] = max(larguras[i], len(v))

    def montar(valores):
        return " | ".join(v.ljust(larguras[i]) for i, v in enumerate(valores))

    print()
    largura_total = sum(larguras) + 3 * (len(larguras) - 1)
    if largura_total <= shutil.get_terminal_size((120, 30)).columns:
        print(montar(colunas))
        print("-+-".join("-" * w for w in larguras))
        for linha in exibidas:
            print(montar(linha))
    else:
        # tabela mais larga que o terminal: um registro por bloco
        rotulo = max(len(c) for c in colunas)
        for n, linha in enumerate(linhas[:MAX_LINHAS], 1):
            print(f"-[ registro {n} ]" + "-" * 30)
            for coluna, valor in zip(colunas, linha):
                texto = "" if valor is None else str(valor).replace("\n", " ")
                print(f"{coluna.ljust(rotulo)} | {texto}")
    total = len(linhas)
    if total > MAX_LINHAS:
        print(f"... exibindo {MAX_LINHAS} de {total} linhas")
    else:
        print(f"({total} linha{'s' if total != 1 else ''})")


def executar_consulta(conn, sql, somente_leitura=False):
    """Executa o SQL e exibe o resultado. Retorna None em caso de sucesso
    ou a mensagem de erro do PostgreSQL."""
    try:
        with conn.transaction(force_rollback=somente_leitura):
            with conn.cursor() as cur:
                if somente_leitura:
                    cur.execute("SET TRANSACTION READ ONLY")
                    cur.execute("SET LOCAL statement_timeout = '15s'")
                cur.execute(sql)
                if cur.description is None:
                    print(f"\nComando executado ({cur.rowcount} linhas afetadas).")
                else:
                    colunas = [d.name for d in cur.description]
                    imprimir_tabela(colunas, cur.fetchall())
        return None
    except psycopg.Error as e:
        mensagem = e.diag.message_primary or str(e)
        if e.diag.message_detail:
            mensagem += f" ({e.diag.message_detail})"
        return mensagem


# ------------------------------------------------------------
# Linguagem natural -> SQL (Ollama)
# ------------------------------------------------------------
JUNCOES = """\
Junções corretas (use exatamente estas):
- nome de pessoa/organização: agente.nome. A tabela pessoa NÃO tem nome:
  JOIN agente ag ON ag.agente_id = <tabela>.pessoa_id
- atividade -> evento: atividade.evento_id = evento.evento_id
- sessao -> atividade: sessao.atividade_id = atividade.atividade_id
- sessao -> espaco: sessao.espaco_id = espaco.espaco_id
- inscricao_sessao / requer / alteracao_sessao -> sessao: mesmas colunas
  (atividade_id, num_sessao)
- promove -> agente: promove.agente_id = agente.agente_id
- dispoe -> recurso: dispoe.recurso_id = recurso.recurso_id
"""

REGRAS = """\
Regras obrigatórias:
- Gere UMA única consulta PostgreSQL somente de leitura (SELECT ou WITH ... SELECT).
- Responda apenas com o SQL dentro de um bloco ```sql ... ```, sem explicações.
- Use somente tabelas e colunas que existem no esquema.
- Colunas *_id guardam códigos internos (ex.: 'EV01', 'P21', 'AUD_B'). NUNCA compare
  *_id com nomes digitados pelo usuário: procure por nome/titulo com ILIKE.
- Os textos do banco têm acentos e pontuação (ex.: 'Computação', 'Painel: Tema').
  NUNCA filtre pela frase inteira digitada: use ILIKE com UMA ou DUAS palavras-chave
  distintivas, sem letras acentuadas. Ex.: "mesa redonda sobre mercado de trabalho"
  -> ILIKE '%mercado de trabalho%'; "Semana da Computação" -> ILIKE '%semana da comput%'.
- Existem eventos com o mesmo nome em edições diferentes: ao agrupar ou listar
  eventos, agrupe por evento_id e mostre também num_edicao.
- Filtros sobre a tabela do lado direito de um LEFT JOIN vão no ON, não no WHERE.
- Atividades são procuradas por atividade.titulo; eventos por evento.nome;
  espaços por espaco.nome; recursos por recurso.nome. Nomes como "Semana da
  Computação", "Simpósio..." ou "Treinamento..." são de EVENTOS (evento.nome).
- "Ministra", "apresenta", "conduz" ou "participa da realização" = qualquer linha
  de atua; só filtre atua.papel se a pergunta citar o papel (ex.: "palestrante").
- Vagas restantes de uma sessão: fn_vagas_disponiveis(s.atividade_id, s.num_sessao).
- num_edicao é o número sequencial da edição, NÃO o ano. Para o ano de um evento
  use EXTRACT(YEAR FROM evento.data_inicio).
- Ao combinar AND e OR, use parênteses.
- Mostre colunas descritivas (título da atividade, nome do evento, nome do
  espaço, nome da pessoa) em vez de apenas códigos. Use aliases em português.
- Valores de status: inscrições 'CONFIRMADA', 'LISTA_ESPERA', 'CANCELADA';
  sessões 'PROGRAMADA', 'REALIZADA', 'CANCELADA'.
- atua.papel: PALESTRANTE, INSTRUTOR, MEDIADOR, PAINELISTA, MONITOR.
  colabora.funcao: função na organização do evento. promove: quem promove o evento.
- sessao.vagas_limite NULL = programação geral (sem inscrição específica).
- alteracao_sessao guarda o histórico de mudanças de data, horário e espaço.
- Funções: fn_vagas_disponiveis(atividade_id, num_sessao) e
  fn_limite_sessao(atividade_id, num_sessao) retornam integer.
- Para "hoje" use CURRENT_DATE.
"""

EXEMPLOS = """\
Exemplos:
Pergunta: Quais atividades a Bia Lopes realizou e com qual papel?
```sql
SELECT ag.nome AS pessoa, a.titulo AS atividade, t.papel
FROM atua t
JOIN agente ag ON ag.agente_id = t.pessoa_id
JOIN atividade a ON a.atividade_id = t.atividade_id
WHERE ag.nome ILIKE '%bia lopes%'
```
Pergunta: Quais sessões teve a Semana da Computação de 2025?
```sql
SELECT ev.nome AS evento, a.titulo AS atividade, s.num_sessao, s.data,
       s.hora_inicio, s.hora_fim, e.nome AS espaco
FROM evento ev
JOIN atividade a ON a.evento_id = ev.evento_id
JOIN sessao s ON s.atividade_id = a.atividade_id
JOIN espaco e ON e.espaco_id = s.espaco_id
WHERE ev.nome ILIKE '%semana da comput%'
  AND EXTRACT(YEAR FROM ev.data_inicio) = 2025
ORDER BY s.data, s.hora_inicio
```
Pergunta: Quem está inscrito no Workshop de Modelagem?
```sql
SELECT a.titulo AS atividade, i.num_sessao, ag.nome AS pessoa, i.status
FROM inscricao_sessao i
JOIN atividade a ON a.atividade_id = i.atividade_id
JOIN agente ag ON ag.agente_id = i.pessoa_id
WHERE a.titulo ILIKE '%workshop de modelagem%'
ORDER BY i.status, i.data_hora_inscricao
```
"""


def montar_prompt(pergunta, sql_anterior=None, erro=None):
    prompt = (
        "Você converte perguntas em português para SQL do PostgreSQL sobre um "
        "sistema de gestão de eventos e espaços.\n\n"
        f"Esquema do banco:\n{ESQUEMA}\n\n{JUNCOES}\n{REGRAS}\n{EXEMPLOS}\n"
        f"Pergunta: {pergunta}\n"
    )
    if sql_anterior:
        prompt += (
            "\nA consulta abaixo, gerada anteriormente, falhou:\n"
            f"```sql\n{sql_anterior}\n```\n"
            f"Erro do PostgreSQL: {erro}\n"
            "Reescreva a consulta corrigindo esse erro. Se uma coluna não existe, "
            "consulte o esquema e as junções corretas acima e use a tabela certa.\n"
        )
    return prompt


def extrair_sql(resposta):
    texto = re.sub(r"<think>.*?</think>", "", resposta, flags=re.DOTALL | re.IGNORECASE)
    bloco = re.search(r"```(?:sql)?\s*(.*?)```", texto, flags=re.DOTALL | re.IGNORECASE)
    if bloco:
        texto = bloco.group(1)
    inicio = re.search(r"\b(WITH|SELECT)\b", texto, flags=re.IGNORECASE)
    if not inicio:
        return None
    sql = texto[inicio.start():].strip()
    return sql.rstrip(";").strip() or None


ACENTOS = "áàâãäéèêëíìîïóòôõöúùûüç"
SEM_ACENTOS = "aaaaaeeeeiiiiooooouuuuc"
PALAVRAS_VAZIAS = {"a", "o", "as", "os", "e", "de", "da", "do", "das", "dos", "em", "no",
                   "na", "nos", "nas", "para", "por", "com", "sobre", "um", "uma"}


def sem_acentos(texto):
    decomposto = unicodedata.normalize("NFKD", texto.lower())
    return "".join(c for c in decomposto if not unicodedata.combining(c))


def reescrever_buscas(sql):
    """Troca `coluna ILIKE '%frase%'` por uma busca por palavras-chave que ignora
    acentos e pontuacao, pois o modelo costuma filtrar pela frase inteira digitada."""
    def trocar(m):
        coluna, frase = m.group(1), m.group(2)
        palavras = [p for p in re.findall(r"\w+", sem_acentos(frase)) if p not in PALAVRAS_VAZIAS]
        if not palavras:
            return m.group(0)
        expr = f"translate(lower({coluna}), '{ACENTOS}', '{SEM_ACENTOS}')"
        return "(" + " AND ".join(f"{expr} LIKE '%{p}%'" for p in palavras) + ")"

    return re.sub(r"\b(?!NOT\b)([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)\s+ILIKE\s+'%([^'%]*)%'",
                  trocar, sql, flags=re.IGNORECASE)


def gerar_sql(client, pergunta, sql_anterior=None, erro=None):
    ollama_config = config["ollama"]
    prompt = montar_prompt(pergunta, sql_anterior, erro)
    # think=False desliga o raciocinio do qwen3 (resposta muito mais rapida);
    # modelos sem esse modo podem recusar o parametro, entao repete sem ele.
    extras = {"think": False}
    try:
        response = client.chat(
            model=ollama_config["model"],
            messages=[
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            **extras
        )
    except ResponseError as e:
        if "think" not in str(e).lower():
            raise
        response = client.chat(
            model=ollama_config["model"],
            messages=[
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        )
    resposta = response["message"]["content"]
    return extrair_sql(resposta), resposta


def pergunta_linguagem_natural(conn, client):
    pergunta = input("\nDigite sua pergunta (ENTER para voltar): ").strip()
    if not pergunta:
        return

    sql_anterior = erro = None
    for tentativa in range(1, MAX_TENTATIVAS + 1):
        print(f"\nConsultando o modelo '{config['ollama']['model']}'... (pode levar alguns segundos)")
        try:
            sql, resposta = gerar_sql(client, pergunta, sql_anterior, erro)
        except Exception as e:  # conexao recusada, modelo inexistente etc.
            print(f"Erro ao acessar o Ollama: {e}")
            print("Verifique se o Ollama está em execução e se o modelo foi baixado "
                  f"(ollama pull {config['ollama']['model']}).")
            return

        if not sql:
            print("O modelo não retornou uma consulta SQL reconhecível. Resposta recebida:")
            print(resposta.strip()[:1000])
            return

        print("\nSQL gerado pelo modelo:\n" + sql)
        ajustado = reescrever_buscas(sql)
        if ajustado != sql:
            print("\nSQL executado (buscas textuais sem acento, por palavra-chave):\n" + ajustado)
            sql = ajustado
        erro = executar_consulta(conn, sql, somente_leitura=True)
        if erro is None:
            return

        print(f"\nErro ao executar a consulta: {erro}")
        if tentativa == MAX_TENTATIVAS:
            print("Número máximo de tentativas atingido.")
            return
        if input("Pedir ao modelo para corrigir a consulta? [s/N]: ").strip().lower() not in ("s", "sim"):
            return
        sql_anterior = sql


# ------------------------------------------------------------
# Inicializacao opcional do banco
# ------------------------------------------------------------
def inicializar_banco(conn):
    dml_path = BASE_DIR.parent / "DML.sql"
    print("\nATENÇÃO: o schema 'eventos' será apagado e recriado com o DDL do Projeto.txt.")
    if dml_path.exists():
        print("Em seguida, os dados de DML.sql serão carregados.")
    if input("Digite SIM para confirmar: ").strip() != "SIM":
        print("Operação cancelada.")
        return
    try:
        conn.execute(DDL_SQL)
        print("Estrutura criada.")
        if dml_path.exists():
            conn.execute(dml_path.read_text(encoding="utf-8"))
            print("Dados carregados.")
        conn.execute("SET search_path TO eventos, public")
    except psycopg.Error as e:
        print(f"Erro: {e.diag.message_primary or e}")


# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------
# Titulos curtos exibidos no menu; o objetivo completo aparece ao executar.
# Consultas sem titulo aqui usam o OBJETIVO do Projeto.txt, com quebra de linha.
RESUMOS = {
    "1": "Programação do SBBD (41ª edição): horários, espaços, responsáveis e vagas",
    "2": "Sessões com inscrição específica e ocupação de pelo menos 50%",
    "3": "Pessoas que exerceram dois ou mais tipos de papel nos eventos",
    "4": "Espaços alternativos livres e equipados para cada sessão",
    "5": "Top 3 pessoas com maior carga horária em atividades, por evento",
}


def quebrar(texto, prefixo=""):
    """Quebra o texto na largura do terminal, alinhando as linhas seguintes."""
    largura = max(40, shutil.get_terminal_size((80, 24)).columns - 1)
    return textwrap.fill(texto, width=largura, initial_indent=prefixo,
                         subsequent_indent=" " * len(prefixo))


def menu(conn, client):
    while True:
        print("\n" + "=" * 60)
        print("SISTEMA DE GESTÃO DE EVENTOS E ESPAÇOS")
        print("=" * 60)
        for c in CONSULTAS:
            print(quebrar(RESUMOS.get(c["numero"], c["objetivo"]), f"{c['numero']}. "))
        print("P. Fazer uma pergunta em linguagem natural (Ollama)")
        print("I. Inicializar banco (DDL do Projeto.txt + DML.sql)")
        print("0. Sair")
        opcao = input("\nOpção: ").strip().upper()

        if opcao == "0":
            return
        if opcao == "P":
            pergunta_linguagem_natural(conn, client)
        elif opcao == "I":
            inicializar_banco(conn)
        else:
            consulta = next((c for c in CONSULTAS if c["numero"] == opcao), None)
            if consulta is None:
                print("Opção inválida.")
                continue
            print("\n" + quebrar(consulta["objetivo"], f"CONSULTA {consulta['numero']}: "))
            erro = executar_consulta(conn, consulta["sql"])
            if erro:
                print(f"\nErro ao executar a consulta: {erro}")
        input("\nENTER para continuar...")


def main():
    if not CONSULTAS:
        print("Aviso: nenhuma consulta encontrada na seção '4. CONSULTAS' do Projeto.txt.")

    conn = conectar()

    ollama_config = config["ollama"]
    client = Client(
        host=ollama_config["host"]
    )

    try:
        menu(conn, client)
    except (KeyboardInterrupt, EOFError):
        print()
    finally:
        conn.close()
        print("Conexão encerrada.")


if __name__ == "__main__":
    main()
