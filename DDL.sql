-- ============================================================
-- DDL - SISTEMA DE GESTAO DE EVENTOS E ESPACOS (PostgreSQL)
-- ============================================================

DROP SCHEMA IF EXISTS eventos CASCADE;
CREATE SCHEMA eventos;
SET search_path TO eventos;

-- novas conexoes a este banco passam a enxergar o schema sem prefixo
DO $$
BEGIN
    EXECUTE format('ALTER DATABASE %I SET search_path TO eventos, public', current_database());
END;
$$;

-- ------------------------------------------------------------
-- TIPOS AUXILIARES
-- ------------------------------------------------------------
CREATE TYPE status_inscricao AS ENUM ('CONFIRMADA', 'LISTA_ESPERA', 'CANCELADA');
CREATE TYPE status_sessao    AS ENUM ('PROGRAMADA', 'REALIZADA', 'CANCELADA');

CREATE DOMAIN dom_id    AS VARCHAR(20) CHECK (VALUE ~ '^[A-Z0-9_-]+$');
CREATE DOMAIN dom_cpf   AS CHAR(11)    CHECK (VALUE ~ '^[0-9]{11}$');
CREATE DOMAIN dom_cnpj  AS CHAR(14)    CHECK (VALUE ~ '^[0-9]{14}$');
CREATE DOMAIN dom_email AS VARCHAR(120) CHECK (VALUE ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$');

-- ------------------------------------------------------------
-- TABELAS
-- ------------------------------------------------------------
CREATE TABLE evento (
    evento_id    dom_id       PRIMARY KEY,
    nome         VARCHAR(150) NOT NULL,
    descricao    TEXT,
    num_edicao   INTEGER      NOT NULL DEFAULT 1 CHECK (num_edicao > 0),
    data_inicio  DATE         NOT NULL,
    data_fim     DATE         NOT NULL,
    num_vagas    INTEGER      CHECK (num_vagas > 0),          -- NULL = sem limite
    duracao_dias INTEGER      GENERATED ALWAYS AS (data_fim - data_inicio + 1) STORED,
    CONSTRAINT ck_evento_periodo CHECK (data_fim >= data_inicio),
    CONSTRAINT uq_evento_edicao  UNIQUE (nome, num_edicao)
);

CREATE TABLE agente (
    agente_id dom_id       PRIMARY KEY,
    nome      VARCHAR(150) NOT NULL,
    telefone  VARCHAR(20)  CHECK (telefone ~ '^\+?[0-9 ()-]{8,20}$'),
    email     dom_email    NOT NULL UNIQUE
);

CREATE TABLE pessoa (
    agente_id dom_id  PRIMARY KEY
              REFERENCES agente (agente_id) ON DELETE CASCADE ON UPDATE CASCADE,
    cpf       dom_cpf NOT NULL UNIQUE
);

CREATE TABLE organizacao (
    agente_id dom_id   PRIMARY KEY
              REFERENCES agente (agente_id) ON DELETE CASCADE ON UPDATE CASCADE,
    cnpj      dom_cnpj NOT NULL UNIQUE
);

CREATE TABLE promove (
    evento_id dom_id REFERENCES evento (evento_id) ON DELETE CASCADE  ON UPDATE CASCADE,
    agente_id dom_id REFERENCES agente (agente_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    PRIMARY KEY (evento_id, agente_id)
);

CREATE TABLE colabora (
    evento_id dom_id      REFERENCES evento (evento_id)  ON DELETE CASCADE ON UPDATE CASCADE,
    pessoa_id dom_id      REFERENCES pessoa (agente_id)  ON DELETE CASCADE ON UPDATE CASCADE,
    funcao    VARCHAR(60) NOT NULL DEFAULT 'ORGANIZADOR',
    PRIMARY KEY (evento_id, pessoa_id)
);

CREATE TABLE inscricao_evento (
    evento_id      dom_id           REFERENCES evento (evento_id) ON DELETE CASCADE ON UPDATE CASCADE,
    pessoa_id      dom_id           REFERENCES pessoa (agente_id) ON DELETE CASCADE ON UPDATE CASCADE,
    data_inscricao DATE             NOT NULL DEFAULT CURRENT_DATE,
    status         status_inscricao NOT NULL DEFAULT 'CONFIRMADA',
    PRIMARY KEY (evento_id, pessoa_id)
);

CREATE TABLE atividade (
    atividade_id dom_id       PRIMARY KEY,
    evento_id    dom_id       NOT NULL
                 REFERENCES evento (evento_id) ON DELETE CASCADE ON UPDATE CASCADE,
    titulo       VARCHAR(150) NOT NULL,
    descricao    TEXT,
    tipo         VARCHAR(20)  NOT NULL DEFAULT 'PALESTRA'
                 CHECK (tipo IN ('PALESTRA', 'WORKSHOP', 'MINICURSO', 'PAINEL',
                                 'MESA_REDONDA', 'APRESENTACAO', 'OUTRO')),
    CONSTRAINT uq_atividade_titulo UNIQUE (evento_id, titulo)
);

CREATE TABLE atua (
    atividade_id dom_id      REFERENCES atividade (atividade_id) ON DELETE CASCADE ON UPDATE CASCADE,
    pessoa_id    dom_id      REFERENCES pessoa (agente_id)       ON DELETE CASCADE ON UPDATE CASCADE,
    papel        VARCHAR(20) NOT NULL DEFAULT 'PALESTRANTE'
                 CHECK (papel IN ('PALESTRANTE', 'INSTRUTOR', 'MEDIADOR', 'PAINELISTA', 'MONITOR')),
    PRIMARY KEY (atividade_id, pessoa_id)
);

CREATE TABLE espaco (
    espaco_id  dom_id       PRIMARY KEY,
    nome       VARCHAR(100) NOT NULL UNIQUE,
    capacidade INTEGER      NOT NULL CHECK (capacidade > 0),
    tipo       VARCHAR(20)  NOT NULL DEFAULT 'SALA'
               CHECK (tipo IN ('SALA', 'AUDITORIO', 'LABORATORIO', 'AREA_EXPOSICAO', 'OUTRO'))
);

CREATE TABLE recurso (
    recurso_id dom_id       PRIMARY KEY,
    nome       VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE dispoe (
    espaco_id  dom_id  REFERENCES espaco (espaco_id)   ON DELETE CASCADE ON UPDATE CASCADE,
    recurso_id dom_id  REFERENCES recurso (recurso_id) ON DELETE CASCADE ON UPDATE CASCADE,
    quantidade INTEGER NOT NULL DEFAULT 1 CHECK (quantidade > 0),
    PRIMARY KEY (espaco_id, recurso_id)
);

CREATE TABLE sessao (
    atividade_id    dom_id        REFERENCES atividade (atividade_id) ON DELETE CASCADE ON UPDATE CASCADE,
    num_sessao      INTEGER       CHECK (num_sessao > 0),
    espaco_id       dom_id        NOT NULL
                    REFERENCES espaco (espaco_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    data            DATE          NOT NULL,
    hora_inicio     TIME          NOT NULL,
    hora_fim        TIME          NOT NULL,
    vagas_limite    INTEGER       CHECK (vagas_limite > 0),   -- NULL = programacao geral (sem inscricao)
    status          status_sessao NOT NULL DEFAULT 'PROGRAMADA',
    duracao_minutos INTEGER       GENERATED ALWAYS AS
                    ((EXTRACT(EPOCH FROM (hora_fim - hora_inicio)) / 60)::INTEGER) STORED,
    PRIMARY KEY (atividade_id, num_sessao),
    CONSTRAINT ck_sessao_horario CHECK (hora_fim > hora_inicio)
);

CREATE TABLE inscricao_sessao (
    atividade_id        dom_id,
    num_sessao          INTEGER,
    pessoa_id           dom_id           REFERENCES pessoa (agente_id) ON DELETE CASCADE ON UPDATE CASCADE,
    data_hora_inscricao TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status              status_inscricao NOT NULL DEFAULT 'CONFIRMADA',
    PRIMARY KEY (atividade_id, num_sessao, pessoa_id),
    FOREIGN KEY (atividade_id, num_sessao)
        REFERENCES sessao (atividade_id, num_sessao) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE requer (
    atividade_id dom_id,
    num_sessao   INTEGER,
    recurso_id   dom_id  REFERENCES recurso (recurso_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    quantidade   INTEGER NOT NULL DEFAULT 1 CHECK (quantidade > 0),
    PRIMARY KEY (atividade_id, num_sessao, recurso_id),
    FOREIGN KEY (atividade_id, num_sessao)
        REFERENCES sessao (atividade_id, num_sessao) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE alteracao_sessao (
    atividade_id         dom_id,
    num_sessao           INTEGER,
    num_alteracao        INTEGER   CHECK (num_alteracao > 0),
    data_hora_alteracao  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_anterior        DATE      NOT NULL,
    hora_inicio_anterior TIME      NOT NULL,
    hora_fim_anterior    TIME      NOT NULL,
    espaco_anterior      dom_id    NOT NULL
                         REFERENCES espaco (espaco_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    motivo               VARCHAR(255),
    PRIMARY KEY (atividade_id, num_sessao, num_alteracao),
    FOREIGN KEY (atividade_id, num_sessao)
        REFERENCES sessao (atividade_id, num_sessao) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX idx_sessao_espaco_data  ON sessao (espaco_id, data);
CREATE INDEX idx_atividade_evento    ON atividade (evento_id);
CREATE INDEX idx_insc_sessao_pessoa  ON inscricao_sessao (pessoa_id);

-- ------------------------------------------------------------
-- FUNCOES AUXILIARES
-- ------------------------------------------------------------

-- Limite efetivo de uma sessao: menor valor entre vagas_limite e capacidade do espaco.
CREATE FUNCTION fn_limite_sessao(p_atividade dom_id, p_num INTEGER)
RETURNS INTEGER AS $$
    SELECT LEAST(s.vagas_limite, e.capacidade)
    FROM sessao s JOIN espaco e ON e.espaco_id = s.espaco_id
    WHERE s.atividade_id = p_atividade AND s.num_sessao = p_num;
$$ LANGUAGE sql STABLE;

-- Vagas restantes (NULL se a sessao nao exige inscricao especifica).
CREATE FUNCTION fn_vagas_disponiveis(p_atividade dom_id, p_num INTEGER)
RETURNS INTEGER AS $$
    SELECT CASE WHEN s.vagas_limite IS NULL THEN NULL
                ELSE fn_limite_sessao(s.atividade_id, s.num_sessao)
                     - (SELECT COUNT(*) FROM inscricao_sessao i
                        WHERE i.atividade_id = s.atividade_id
                          AND i.num_sessao = s.num_sessao
                          AND i.status = 'CONFIRMADA')::INTEGER
           END
    FROM sessao s
    WHERE s.atividade_id = p_atividade AND s.num_sessao = p_num;
$$ LANGUAGE sql STABLE;

-- ------------------------------------------------------------
-- TRIGGER 1: especializacao disjunta de AGENTE (pessoa XOR organizacao)
-- ------------------------------------------------------------
CREATE FUNCTION fn_agente_disjunto() RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'pessoa'
       AND EXISTS (SELECT 1 FROM organizacao WHERE agente_id = NEW.agente_id) THEN
        RAISE EXCEPTION 'Agente % ja e uma organizacao', NEW.agente_id;
    ELSIF TG_TABLE_NAME = 'organizacao'
       AND EXISTS (SELECT 1 FROM pessoa WHERE agente_id = NEW.agente_id) THEN
        RAISE EXCEPTION 'Agente % ja e uma pessoa', NEW.agente_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pessoa_disjunta
    BEFORE INSERT OR UPDATE OF agente_id ON pessoa
    FOR EACH ROW EXECUTE FUNCTION fn_agente_disjunto();

CREATE TRIGGER trg_organizacao_disjunta
    BEFORE INSERT OR UPDATE OF agente_id ON organizacao
    FOR EACH ROW EXECUTE FUNCTION fn_agente_disjunto();

-- ------------------------------------------------------------
-- TRIGGER 2: validacao do planejamento da sessao
--   (periodo do evento, capacidade do espaco, conflito de espaco)
-- ------------------------------------------------------------
CREATE FUNCTION fn_valida_sessao() RETURNS TRIGGER AS $$
DECLARE
    v_ini DATE; v_fim DATE; v_cap INTEGER; v_conflito RECORD;
BEGIN
    IF NEW.status = 'CANCELADA' THEN
        RETURN NEW;
    END IF;

    SELECT e.data_inicio, e.data_fim INTO v_ini, v_fim
    FROM atividade a JOIN evento e ON e.evento_id = a.evento_id
    WHERE a.atividade_id = NEW.atividade_id;

    IF NEW.data NOT BETWEEN v_ini AND v_fim THEN
        RAISE EXCEPTION 'Sessao em % fora do periodo do evento (% a %)', NEW.data, v_ini, v_fim;
    END IF;

    SELECT capacidade INTO v_cap FROM espaco WHERE espaco_id = NEW.espaco_id;
    IF NEW.vagas_limite > v_cap THEN
        RAISE EXCEPTION 'vagas_limite (%) excede a capacidade do espaco % (%)',
            NEW.vagas_limite, NEW.espaco_id, v_cap;
    END IF;

    SELECT atividade_id, num_sessao, hora_inicio, hora_fim INTO v_conflito
    FROM sessao s
    WHERE s.espaco_id = NEW.espaco_id
      AND s.data = NEW.data
      AND s.status <> 'CANCELADA'
      AND (s.atividade_id, s.num_sessao) <> (NEW.atividade_id, NEW.num_sessao)
      AND s.hora_inicio < NEW.hora_fim
      AND NEW.hora_inicio < s.hora_fim
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION 'Conflito de espaco: % ja ocupado pela sessao %/% das % as %',
            NEW.espaco_id, v_conflito.atividade_id, v_conflito.num_sessao,
            v_conflito.hora_inicio, v_conflito.hora_fim;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_valida_sessao
    BEFORE INSERT OR UPDATE OF espaco_id, data, hora_inicio, hora_fim, vagas_limite, status
    ON sessao
    FOR EACH ROW EXECUTE FUNCTION fn_valida_sessao();

-- ------------------------------------------------------------
-- TRIGGER 3: recursos exigidos pela sessao devem existir no espaco
--   (dispara ao cadastrar requisito e ao trocar a sessao de espaco)
-- ------------------------------------------------------------
CREATE FUNCTION fn_valida_recursos() RETURNS TRIGGER AS $$
DECLARE
    v_falta RECORD;
BEGIN
    IF TG_TABLE_NAME = 'requer' THEN
        SELECT r.recurso_id, r.quantidade AS exigida, COALESCE(d.quantidade, 0) AS disponivel
          INTO v_falta
        FROM (SELECT NEW.recurso_id AS recurso_id, NEW.quantidade AS quantidade) r
        JOIN sessao s ON s.atividade_id = NEW.atividade_id AND s.num_sessao = NEW.num_sessao
        LEFT JOIN dispoe d ON d.espaco_id = s.espaco_id AND d.recurso_id = r.recurso_id
        WHERE COALESCE(d.quantidade, 0) < r.quantidade;
    ELSE  -- sessao
        SELECT r.recurso_id, r.quantidade AS exigida, COALESCE(d.quantidade, 0) AS disponivel
          INTO v_falta
        FROM requer r
        LEFT JOIN dispoe d ON d.espaco_id = NEW.espaco_id AND d.recurso_id = r.recurso_id
        WHERE r.atividade_id = NEW.atividade_id AND r.num_sessao = NEW.num_sessao
          AND COALESCE(d.quantidade, 0) < r.quantidade
        LIMIT 1;
    END IF;

    IF FOUND THEN
        RAISE EXCEPTION 'Recurso % indisponivel no espaco: exigido %, disponivel %',
            v_falta.recurso_id, v_falta.exigida, v_falta.disponivel;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_requer_recurso
    BEFORE INSERT OR UPDATE ON requer
    FOR EACH ROW EXECUTE FUNCTION fn_valida_recursos();

CREATE TRIGGER trg_sessao_recurso
    BEFORE UPDATE OF espaco_id ON sessao
    FOR EACH ROW EXECUTE FUNCTION fn_valida_recursos();

-- ------------------------------------------------------------
-- TRIGGER 4: historico automatico de alteracoes da sessao
--   motivo opcional via: SET LOCAL app.motivo_alteracao = '...';
-- ------------------------------------------------------------
CREATE FUNCTION fn_historico_sessao() RETURNS TRIGGER AS $$
BEGIN
    -- ignora mera renomeacao do espaco propagada por ON UPDATE CASCADE
    IF NOT EXISTS (SELECT 1 FROM espaco WHERE espaco_id = OLD.espaco_id) THEN
        RETURN NULL;
    END IF;

    INSERT INTO alteracao_sessao (atividade_id, num_sessao, num_alteracao,
                                  data_anterior, hora_inicio_anterior, hora_fim_anterior,
                                  espaco_anterior, motivo)
    SELECT OLD.atividade_id, OLD.num_sessao, COALESCE(MAX(num_alteracao), 0) + 1,
           OLD.data, OLD.hora_inicio, OLD.hora_fim, OLD.espaco_id,
           NULLIF(current_setting('app.motivo_alteracao', true), '')
    FROM alteracao_sessao
    WHERE atividade_id = OLD.atividade_id AND num_sessao = OLD.num_sessao;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_historico_sessao
    AFTER UPDATE OF data, hora_inicio, hora_fim, espaco_id ON sessao
    FOR EACH ROW
    WHEN (OLD.data IS DISTINCT FROM NEW.data
       OR OLD.hora_inicio IS DISTINCT FROM NEW.hora_inicio
       OR OLD.hora_fim IS DISTINCT FROM NEW.hora_fim
       OR OLD.espaco_id IS DISTINCT FROM NEW.espaco_id)
    EXECUTE FUNCTION fn_historico_sessao();

-- ------------------------------------------------------------
-- TRIGGER 5: controle de vagas na inscricao do EVENTO
--   (sem vaga -> LISTA_ESPERA)
-- ------------------------------------------------------------
CREATE FUNCTION fn_controla_inscricao_evento() RETURNS TRIGGER AS $$
DECLARE
    v_vagas INTEGER; v_ocupadas INTEGER;
BEGIN
    IF NEW.status <> 'CONFIRMADA'
       OR (TG_OP = 'UPDATE' AND OLD.status = 'CONFIRMADA') THEN
        RETURN NEW;
    END IF;

    SELECT num_vagas INTO v_vagas FROM evento WHERE evento_id = NEW.evento_id FOR UPDATE;
    IF v_vagas IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT COUNT(*) INTO v_ocupadas FROM inscricao_evento
    WHERE evento_id = NEW.evento_id AND status = 'CONFIRMADA' AND pessoa_id <> NEW.pessoa_id;

    IF v_ocupadas >= v_vagas THEN
        IF TG_OP = 'INSERT' THEN
            NEW.status := 'LISTA_ESPERA';
        ELSE
            RAISE EXCEPTION 'Evento % sem vagas disponiveis', NEW.evento_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_controla_inscricao_evento
    BEFORE INSERT OR UPDATE OF status ON inscricao_evento
    FOR EACH ROW EXECUTE FUNCTION fn_controla_inscricao_evento();

-- ------------------------------------------------------------
-- TRIGGER 6: controle de inscricao na SESSAO
--   exige sessao com vagas_limite, sessao nao cancelada,
--   inscricao confirmada no evento; sem vaga -> LISTA_ESPERA
-- ------------------------------------------------------------
CREATE FUNCTION fn_controla_inscricao_sessao() RETURNS TRIGGER AS $$
DECLARE
    v_sessao RECORD; v_limite INTEGER; v_ocupadas INTEGER;
BEGIN
    SELECT s.*, a.evento_id INTO v_sessao
    FROM sessao s JOIN atividade a ON a.atividade_id = s.atividade_id
    WHERE s.atividade_id = NEW.atividade_id AND s.num_sessao = NEW.num_sessao
    FOR UPDATE OF s;

    IF NEW.status = 'CANCELADA'
       OR (TG_OP = 'UPDATE' AND OLD.status = 'CONFIRMADA' AND NEW.status = 'CONFIRMADA') THEN
        RETURN NEW;
    END IF;

    IF v_sessao.vagas_limite IS NULL THEN
        RAISE EXCEPTION 'Sessao %/% pertence a programacao geral e nao exige inscricao',
            NEW.atividade_id, NEW.num_sessao;
    END IF;

    IF v_sessao.status <> 'PROGRAMADA' THEN
        RAISE EXCEPTION 'Sessao %/% nao aceita inscricoes (status %)',
            NEW.atividade_id, NEW.num_sessao, v_sessao.status;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM inscricao_evento
                   WHERE evento_id = v_sessao.evento_id
                     AND pessoa_id = NEW.pessoa_id
                     AND status = 'CONFIRMADA') THEN
        RAISE EXCEPTION 'Pessoa % nao possui inscricao confirmada no evento %',
            NEW.pessoa_id, v_sessao.evento_id;
    END IF;

    IF NEW.status = 'CONFIRMADA' THEN
        v_limite := fn_limite_sessao(NEW.atividade_id, NEW.num_sessao);
        SELECT COUNT(*) INTO v_ocupadas FROM inscricao_sessao
        WHERE atividade_id = NEW.atividade_id AND num_sessao = NEW.num_sessao
          AND status = 'CONFIRMADA' AND pessoa_id <> NEW.pessoa_id;

        IF v_ocupadas >= v_limite THEN
            IF TG_OP = 'INSERT' THEN
                NEW.status := 'LISTA_ESPERA';
            ELSE
                RAISE EXCEPTION 'Sessao %/% sem vagas disponiveis', NEW.atividade_id, NEW.num_sessao;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_controla_inscricao_sessao
    BEFORE INSERT OR UPDATE OF status ON inscricao_sessao
    FOR EACH ROW EXECUTE FUNCTION fn_controla_inscricao_sessao();

-- ------------------------------------------------------------
-- TRIGGER 7: promocao automatica da lista de espera
--   ao cancelar/remover inscricao confirmada (evento ou sessao)
-- ------------------------------------------------------------
CREATE FUNCTION fn_promove_lista_espera() RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'inscricao_sessao' THEN
        UPDATE inscricao_sessao SET status = 'CONFIRMADA'
        WHERE (atividade_id, num_sessao, pessoa_id) = (
            SELECT atividade_id, num_sessao, pessoa_id FROM inscricao_sessao
            WHERE atividade_id = OLD.atividade_id AND num_sessao = OLD.num_sessao
              AND status = 'LISTA_ESPERA'
            ORDER BY data_hora_inscricao, pessoa_id
            LIMIT 1);
    ELSE
        UPDATE inscricao_evento SET status = 'CONFIRMADA'
        WHERE (evento_id, pessoa_id) = (
            SELECT evento_id, pessoa_id FROM inscricao_evento
            WHERE evento_id = OLD.evento_id AND status = 'LISTA_ESPERA'
            ORDER BY data_inscricao, pessoa_id
            LIMIT 1);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_promove_espera_sessao_upd
    AFTER UPDATE OF status ON inscricao_sessao
    FOR EACH ROW
    WHEN (OLD.status = 'CONFIRMADA' AND NEW.status <> 'CONFIRMADA')
    EXECUTE FUNCTION fn_promove_lista_espera();

CREATE TRIGGER trg_promove_espera_sessao_del
    AFTER DELETE ON inscricao_sessao
    FOR EACH ROW
    WHEN (OLD.status = 'CONFIRMADA')
    EXECUTE FUNCTION fn_promove_lista_espera();

CREATE TRIGGER trg_promove_espera_evento_upd
    AFTER UPDATE OF status ON inscricao_evento
    FOR EACH ROW
    WHEN (OLD.status = 'CONFIRMADA' AND NEW.status <> 'CONFIRMADA')
    EXECUTE FUNCTION fn_promove_lista_espera();

CREATE TRIGGER trg_promove_espera_evento_del
    AFTER DELETE ON inscricao_evento
    FOR EACH ROW
    WHEN (OLD.status = 'CONFIRMADA')
    EXECUTE FUNCTION fn_promove_lista_espera();

-- ------------------------------------------------------------
-- TRIGGER 8: cancelamentos em cascata logica
--   sessao cancelada -> cancela suas inscricoes;
--   inscricao no evento cancelada -> cancela inscricoes nas sessoes do evento
-- ------------------------------------------------------------
CREATE FUNCTION fn_cancela_dependentes() RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'sessao' THEN
        UPDATE inscricao_sessao SET status = 'CANCELADA'
        WHERE atividade_id = NEW.atividade_id AND num_sessao = NEW.num_sessao
          AND status <> 'CANCELADA';
    ELSE
        UPDATE inscricao_sessao i SET status = 'CANCELADA'
        FROM atividade a
        WHERE a.atividade_id = i.atividade_id
          AND a.evento_id = NEW.evento_id
          AND i.pessoa_id = NEW.pessoa_id
          AND i.status <> 'CANCELADA';
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_cancela_sessao
    AFTER UPDATE OF status ON sessao
    FOR EACH ROW
    WHEN (NEW.status = 'CANCELADA' AND OLD.status <> 'CANCELADA')
    EXECUTE FUNCTION fn_cancela_dependentes();

CREATE TRIGGER trg_cancela_inscricao_evento
    AFTER UPDATE OF status ON inscricao_evento
    FOR EACH ROW
    WHEN (NEW.status = 'CANCELADA' AND OLD.status <> 'CANCELADA')
    EXECUTE FUNCTION fn_cancela_dependentes();
