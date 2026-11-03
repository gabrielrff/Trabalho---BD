-- ============================================================
-- DML - SISTEMA DE GESTAO DE EVENTOS E ESPACOS
-- Pre-requisito: DDL.sql executado (schema "eventos").
-- A ordem dos comandos importa: varios estados (lista de espera,
-- historico de alteracoes, cancelamentos) sao produzidos pelos triggers.
-- ============================================================

SET client_encoding TO 'UTF8';
SET search_path TO eventos;

TRUNCATE alteracao_sessao, requer, inscricao_sessao, sessao, dispoe, recurso, espaco,
         atua, atividade, inscricao_evento, colabora, promove,
         organizacao, pessoa, agente, evento CASCADE;

-- ------------------------------------------------------------
-- EVENTOS (duas edicoes da Semana da Computacao: Q4)
-- ------------------------------------------------------------
INSERT INTO evento (evento_id, nome, descricao, num_edicao, data_inicio, data_fim, num_vagas) VALUES
('EV01', 'Semana da Computação', 'Semana acadêmica anual com palestras, minicursos e mesas-redondas.', 12, '2025-09-15', '2025-09-19', 200),
('EV02', 'Semana da Computação', 'Semana acadêmica anual com palestras, minicursos, painéis e maratona.', 13, '2026-09-14', '2026-09-18', 250),
('EV03', 'Simpósio Brasileiro de Banco de Dados', 'Simpósio científico com keynotes, tutoriais e sessões técnicas.', 41, '2026-11-16', '2026-11-20', 150),
('EV04', 'Feira de Inovação e Startups', 'Feira aberta com exposição de startups, pitches e palestras.', 3, '2026-12-03', '2026-12-05', NULL),
('EV05', 'Treinamento Intensivo em PostgreSQL', 'Treinamento prático de curta duração com turmas reduzidas.', 1, '2026-11-23', '2026-11-24', 5);

-- ------------------------------------------------------------
-- AGENTES (generalizacao de pessoa e organizacao: Q1)
-- ------------------------------------------------------------
INSERT INTO agente (agente_id, nome, telefone, email) VALUES
('O01', 'Instituto de Ciências Matemáticas e de Computação - USP', '(16) 3373-9700', 'contato@icmc.usp.br'),
('O02', 'Sociedade Brasileira de Computação', '(51) 3308-6835', 'eventos@sbc.org.br'),
('O03', 'TechNova Soluções Ltda', '(11) 4002-8922', 'parcerias@technova.com.br'),
('O04', 'DataCorp Analytics S.A.', '(11) 3500-1200', 'eventos@datacorp.com.br'),
('O05', 'PET Computação ICMC', '(16) 3373-9800', 'pet@icmc.usp.br'),
('O06', 'Incubadora de Empresas de São Carlos', '(16) 3411-5000', 'contato@incubadorasc.org.br'),
('P01', 'Carlos Eduardo Lima', '(16) 99101-0001', 'carlos.lima@usp.br'),
('P02', 'Fernanda Souza', '(16) 99101-0002', 'fernanda.souza@usp.br'),
('P03', 'Rafael Martins', '(16) 99101-0003', 'rafael.martins@usp.br'),
('P04', 'Juliana Rocha', '(16) 99101-0004', 'juliana.rocha@usp.br'),
('P05', 'Marcos Vinícius Teixeira', '(16) 99101-0005', 'marcos.teixeira@usp.br'),
('P06', 'Helena Carvalho', '(11) 99101-0006', 'helena.carvalho@ufmg.br'),
('P07', 'Ricardo Almeida', '(31) 99101-0007', 'ricardo.almeida@ufmg.br'),
('P08', 'Patrícia Gomes', '(16) 99101-0008', 'patricia.gomes@incubadorasc.org.br'),
('P09', 'Eduardo Nascimento', '(11) 99101-0009', 'eduardo.nascimento@technova.com.br'),
('P10', 'Camila Ferreira', '(16) 99101-0010', 'camila.ferreira@usp.br'),
('P11', 'Roberto Pires', '(11) 99101-0011', 'roberto.pires@datacorp.com.br'),
('P12', 'Luciana Barros', '(11) 99101-0012', 'luciana.barros@gmail.com'),
('P13', 'André Moreira', '(16) 99101-0013', 'andre.moreira@gmail.com'),
('P14', 'Beatriz Ramos', '(16) 99101-0014', 'beatriz.ramos@usp.br'),
('P15', 'Larissa Costa', '(16) 99101-0015', 'larissa.costa@usp.br'),
('P16', 'Tatiane Oliveira', '(19) 99101-0016', 'tatiane.oliveira@unicamp.br'),
('P17', 'Gustavo Henrique Prado', '(21) 99101-0017', 'gustavo.prado@puc-rio.br'),
('P18', 'Marina Duarte', '(61) 99101-0018', 'marina.duarte@unb.br'),
('P19', 'Thiago Ribeiro', '(16) 99101-0019', 'thiago.ribeiro@gmail.com'),
('P20', 'Vinícius Araújo', '(16) 99101-0020', 'vinicius.araujo@usp.br'),
('P21', 'Ana Clara Mendes', '(16) 99101-0021', 'ana.mendes@usp.br'),
('P22', 'Bruno Santos', '(16) 99101-0022', 'bruno.santos@usp.br'),
('P23', 'Daniela Freitas', '(16) 99101-0023', 'daniela.freitas@usp.br'),
('P24', 'Felipe Cardoso', '(16) 99101-0024', 'felipe.cardoso@usp.br'),
('P25', 'Gabriela Nunes', '(16) 99101-0025', 'gabriela.nunes@usp.br'),
('P26', 'Igor Monteiro', '(16) 99101-0026', 'igor.monteiro@usp.br'),
('P27', 'Isabela Correia', '(16) 99101-0027', 'isabela.correia@usp.br'),
('P28', 'João Pedro Dias', '(16) 99101-0028', 'joao.dias@usp.br'),
('P29', 'Letícia Vieira', '(16) 99101-0029', 'leticia.vieira@usp.br'),
('P30', 'Mateus Batista', '(16) 99101-0030', 'mateus.batista@usp.br');

INSERT INTO organizacao (agente_id, cnpj) VALUES
('O01', '63025530000104'),
('O02', '29532264000178'),
('O03', '11222333000181'),
('O04', '44555666000192'),
('O05', '63025530001003'),
('O06', '77888999000150');

INSERT INTO pessoa (agente_id, cpf) VALUES
('P01', '90000000101'), ('P02', '90000000202'), ('P03', '90000000303'),
('P04', '90000000404'), ('P05', '90000000505'), ('P06', '90000000606'),
('P07', '90000000707'), ('P08', '90000000808'), ('P09', '90000000909'),
('P10', '90000001010'), ('P11', '90000001111'), ('P12', '90000001212'),
('P13', '90000001313'), ('P14', '90000001414'), ('P15', '90000001515'),
('P16', '90000001616'), ('P17', '90000001717'), ('P18', '90000001818'),
('P19', '90000001919'), ('P20', '90000002020'), ('P21', '90000002121'),
('P22', '90000002222'), ('P23', '90000002323'), ('P24', '90000002424'),
('P25', '90000002525'), ('P26', '90000002626'), ('P27', '90000002727'),
('P28', '90000002828'), ('P29', '90000002929'), ('P30', '90000003030');

-- Promocao: conjunta entre organizacoes, ou diretamente por uma pessoa (EV05)
INSERT INTO promove (evento_id, agente_id) VALUES
('EV01', 'O01'), ('EV01', 'O05'),
('EV02', 'O01'), ('EV02', 'O05'), ('EV02', 'O03'),
('EV03', 'O02'), ('EV03', 'O01'),
('EV04', 'O06'), ('EV04', 'O03'), ('EV04', 'O04'),
('EV05', 'P05');

-- Papeis na organizacao do evento (Q2)
INSERT INTO colabora (evento_id, pessoa_id, funcao) VALUES
('EV01', 'P01', 'COORDENADOR'),
('EV01', 'P02', 'ORGANIZADOR'),
('EV02', 'P01', 'COORDENADOR'),
('EV02', 'P03', 'ORGANIZADOR'),
('EV02', 'P04', 'APOIO'),
('EV03', 'P06', 'COORDENADOR'),
('EV03', 'P07', 'COORDENADOR DE PROGRAMA'),
('EV03', 'P04', 'APOIO'),
('EV04', 'P08', 'COORDENADOR'),
('EV05', 'P05', 'COORDENADOR');

-- ------------------------------------------------------------
-- ESPACOS E RECURSOS
-- ------------------------------------------------------------
INSERT INTO espaco (espaco_id, nome, capacidade, tipo) VALUES
('AUD_PRINC', 'Auditório Principal', 300, 'AUDITORIO'),
('AUD_B', 'Auditório B', 120, 'AUDITORIO'),
('SALA_101', 'Sala 101', 40, 'SALA'),
('SALA_102', 'Sala 102', 40, 'SALA'),
('SALA_201', 'Sala 201', 60, 'SALA'),
('SALA_REUNIAO', 'Sala de Reuniões', 12, 'SALA'),
('LAB_1', 'Laboratório 1', 30, 'LABORATORIO'),
('LAB_2', 'Laboratório 2', 25, 'LABORATORIO'),
('HALL', 'Hall de Exposições', 500, 'AREA_EXPOSICAO');

INSERT INTO recurso (recurso_id, nome) VALUES
('PROJ', 'Projetor'),
('COMP', 'Computador'),
('AUDIO', 'Sistema de áudio'),
('MIC', 'Microfone sem fio'),
('INTERNET', 'Acesso à Internet'),
('LOUSA', 'Lousa digital'),
('ESTANDE', 'Estande de exposição');

INSERT INTO dispoe (espaco_id, recurso_id, quantidade) VALUES
('AUD_PRINC', 'PROJ', 2), ('AUD_PRINC', 'AUDIO', 1), ('AUD_PRINC', 'MIC', 4), ('AUD_PRINC', 'INTERNET', 1),
('AUD_B', 'PROJ', 1), ('AUD_B', 'AUDIO', 1), ('AUD_B', 'MIC', 2), ('AUD_B', 'INTERNET', 1),
('SALA_101', 'PROJ', 1), ('SALA_101', 'INTERNET', 1), ('SALA_101', 'LOUSA', 1),
('SALA_102', 'PROJ', 1),
('SALA_201', 'PROJ', 1), ('SALA_201', 'INTERNET', 1), ('SALA_201', 'AUDIO', 1),
('SALA_REUNIAO', 'LOUSA', 1), ('SALA_REUNIAO', 'INTERNET', 1),
('LAB_1', 'COMP', 30), ('LAB_1', 'PROJ', 1), ('LAB_1', 'INTERNET', 1),
('LAB_2', 'COMP', 25), ('LAB_2', 'INTERNET', 1),
('HALL', 'INTERNET', 1), ('HALL', 'AUDIO', 1), ('HALL', 'ESTANDE', 40);

-- ------------------------------------------------------------
-- ATIVIDADES (titulo/descricao/tipo pertencem a atividade: Q3)
-- ------------------------------------------------------------
INSERT INTO atividade (atividade_id, evento_id, titulo, descricao, tipo) VALUES
('A01', 'EV01', 'Palestra Magna: O Futuro da Computação', 'Abertura oficial da semana.', 'PALESTRA'),
('A02', 'EV01', 'Minicurso de Python para Ciência de Dados', 'Pandas, NumPy e visualização de dados.', 'MINICURSO'),
('A03', 'EV01', 'Mesa-redonda: Mercado de Trabalho em TI', 'Profissionais discutem carreiras em TI.', 'MESA_REDONDA'),
('A04', 'EV02', 'Palestra Magna: IA Generativa na Prática', 'Aplicações reais de modelos de linguagem.', 'PALESTRA'),
('A05', 'EV02', 'Workshop de PostgreSQL', 'Modelagem, SQL avançado e triggers na prática.', 'WORKSHOP'),
('A06', 'EV02', 'Introdução a Python', 'Minicurso introdutório para iniciantes.', 'MINICURSO'),
('A07', 'EV02', 'Painel: Mulheres na Computação', 'Trajetórias e desafios de mulheres na área.', 'PAINEL'),
('A08', 'EV02', 'Maratona de Programação', 'Competição em equipes no estilo ICPC.', 'OUTRO'),
('A09', 'EV03', 'Keynote: Bancos de Dados Vetoriais', 'Indexação e busca por similaridade em larga escala.', 'PALESTRA'),
('A10', 'EV03', 'Tutorial: Otimização de Consultas no PostgreSQL', 'Planos de execução, índices e estatísticas.', 'MINICURSO'),
('A11', 'EV03', 'Sessão Técnica: Artigos Completos', 'Apresentação dos artigos aceitos.', 'APRESENTACAO'),
('A12', 'EV03', 'Painel: Privacidade e LGPD', 'Impactos da LGPD no projeto de bancos de dados.', 'PAINEL'),
('A13', 'EV03', 'Workshop de Modelagem de Dados', 'Dinâmica em grupo com turma reduzida.', 'WORKSHOP'),
('A14', 'EV04', 'Exposição de Startups', 'Estandes das startups participantes.', 'APRESENTACAO'),
('A15', 'EV04', 'Pitch de Startups', 'Apresentações de 5 minutos para investidores.', 'APRESENTACAO'),
('A16', 'EV04', 'Palestra: Captação de Investimento', 'Como preparar uma rodada de investimento-anjo.', 'PALESTRA'),
('A17', 'EV05', 'PostgreSQL: Administração Básica', 'Instalação, usuários, backup e restauração.', 'MINICURSO'),
('A18', 'EV05', 'PostgreSQL: Funções e Triggers', 'PL/pgSQL aplicado a regras de negócio.', 'MINICURSO');

-- Papeis na realizacao das atividades (Q2): a mesma pessoa pode ter varios papeis
INSERT INTO atua (atividade_id, pessoa_id, papel) VALUES
('A01', 'P09', 'PALESTRANTE'),
('A02', 'P10', 'INSTRUTOR'), ('A02', 'P04', 'MONITOR'),
('A03', 'P11', 'MEDIADOR'), ('A03', 'P12', 'PAINELISTA'), ('A03', 'P13', 'PAINELISTA'),
('A04', 'P09', 'PALESTRANTE'),
('A05', 'P05', 'INSTRUTOR'), ('A05', 'P04', 'MONITOR'),
('A06', 'P10', 'INSTRUTOR'),
('A07', 'P14', 'MEDIADOR'), ('A07', 'P15', 'PAINELISTA'), ('A07', 'P16', 'PAINELISTA'),
('A08', 'P03', 'MONITOR'),
('A09', 'P17', 'PALESTRANTE'),
('A10', 'P05', 'INSTRUTOR'),
('A11', 'P07', 'MEDIADOR'),
('A12', 'P18', 'MEDIADOR'), ('A12', 'P11', 'PAINELISTA'), ('A12', 'P16', 'PAINELISTA'),
('A13', 'P06', 'INSTRUTOR'),
('A14', 'P08', 'MONITOR'),
('A15', 'P19', 'MEDIADOR'),
('A16', 'P12', 'PALESTRANTE'),
('A17', 'P05', 'INSTRUTOR'),
('A18', 'P05', 'INSTRUTOR'), ('A18', 'P20', 'MONITOR');

-- ------------------------------------------------------------
-- SESSOES (data/horario/espaco/vagas pertencem a sessao: Q3)
-- vagas_limite NULL = programacao geral, sem inscricao especifica (Q5)
-- ------------------------------------------------------------
INSERT INTO sessao (atividade_id, num_sessao, espaco_id, data, hora_inicio, hora_fim, vagas_limite) VALUES
-- EV01 (2025)
('A01', 1, 'AUD_PRINC', '2025-09-15', '09:00', '11:00', NULL),
('A02', 1, 'LAB_1', '2025-09-16', '14:00', '18:00', 25),
('A03', 1, 'AUD_B', '2025-09-17', '10:00', '12:00', NULL),
-- EV02 (2026)
('A04', 1, 'AUD_PRINC', '2026-09-14', '09:00', '11:00', NULL),
('A05', 1, 'LAB_2', '2026-09-15', '09:00', '12:00', 20),
('A05', 2, 'LAB_1', '2026-09-15', '14:00', '17:00', 20),
('A06', 1, 'LAB_2', '2026-09-16', '09:00', '12:00', 25),
('A06', 2, 'LAB_2', '2026-09-17', '09:00', '12:00', 25),
('A07', 1, 'AUD_B', '2026-09-16', '14:00', '16:00', NULL),
('A08', 1, 'LAB_1', '2026-09-18', '08:00', '13:00', 30),
-- EV03
('A09', 1, 'AUD_PRINC', '2026-11-16', '09:00', '10:30', NULL),
('A10', 1, 'LAB_1', '2026-11-16', '14:00', '17:30', 30),
('A10', 2, 'LAB_1', '2026-11-17', '14:00', '17:30', 30),
('A11', 1, 'SALA_201', '2026-11-17', '09:00', '12:00', NULL),
('A11', 2, 'SALA_201', '2026-11-18', '09:00', '12:00', NULL),
('A11', 3, 'SALA_201', '2026-11-19', '09:00', '12:00', NULL),
('A12', 1, 'SALA_101', '2026-11-18', '10:00', '12:00', NULL),
('A13', 1, 'SALA_REUNIAO', '2026-11-19', '14:00', '17:00', 3),
-- EV04
('A14', 1, 'HALL', '2026-12-03', '10:00', '18:00', NULL),
('A14', 2, 'HALL', '2026-12-04', '10:00', '18:00', NULL),
('A14', 3, 'HALL', '2026-12-05', '10:00', '16:00', NULL),
('A15', 1, 'AUD_B', '2026-12-04', '14:00', '17:00', NULL),
('A16', 1, 'AUD_B', '2026-12-03', '10:00', '11:30', NULL),
('A16', 2, 'AUD_B', '2026-12-05', '10:00', '11:30', 50),
-- EV05
('A17', 1, 'LAB_2', '2026-11-23', '08:00', '12:00', 4),
('A18', 1, 'LAB_2', '2026-11-24', '08:00', '12:00', 5);

-- ------------------------------------------------------------
-- ALTERACOES DE PROGRAMACAO (historico gerado pelo trigger: Q6)
-- ------------------------------------------------------------
BEGIN;
SET LOCAL app.motivo_alteracao = 'Laboratório 2 em manutenção';
UPDATE sessao SET espaco_id = 'LAB_1' WHERE atividade_id = 'A05' AND num_sessao = 1;
COMMIT;

BEGIN;
SET LOCAL app.motivo_alteracao = 'Conflito de agenda da mediadora';
UPDATE sessao SET hora_inicio = '14:00', hora_fim = '16:00' WHERE atividade_id = 'A12' AND num_sessao = 1;
COMMIT;

BEGIN;
SET LOCAL app.motivo_alteracao = 'Número de interessados excede a capacidade da Sala 101';
UPDATE sessao SET espaco_id = 'AUD_B' WHERE atividade_id = 'A12' AND num_sessao = 1;
COMMIT;

BEGIN;
SET LOCAL app.motivo_alteracao = 'Ajuste solicitado pelo instrutor';
UPDATE sessao SET hora_inicio = '13:30', hora_fim = '17:00' WHERE atividade_id = 'A10' AND num_sessao = 2;
COMMIT;

-- Recursos exigidos (validados contra o espaco atual de cada sessao)
INSERT INTO requer (atividade_id, num_sessao, recurso_id, quantidade) VALUES
('A01', 1, 'PROJ', 1), ('A01', 1, 'AUDIO', 1), ('A01', 1, 'MIC', 1),
('A02', 1, 'COMP', 25), ('A02', 1, 'PROJ', 1),
('A03', 1, 'MIC', 2),
('A04', 1, 'PROJ', 1), ('A04', 1, 'AUDIO', 1), ('A04', 1, 'MIC', 1),
('A05', 1, 'COMP', 20), ('A05', 1, 'PROJ', 1),
('A05', 2, 'COMP', 20), ('A05', 2, 'PROJ', 1),
('A06', 1, 'COMP', 25),
('A06', 2, 'COMP', 25),
('A07', 1, 'MIC', 2),
('A08', 1, 'COMP', 30), ('A08', 1, 'INTERNET', 1),
('A09', 1, 'PROJ', 1), ('A09', 1, 'AUDIO', 1),
('A10', 1, 'COMP', 30), ('A10', 1, 'PROJ', 1),
('A10', 2, 'COMP', 30), ('A10', 2, 'PROJ', 1),
('A11', 1, 'PROJ', 1), ('A11', 2, 'PROJ', 1), ('A11', 3, 'PROJ', 1),
('A12', 1, 'MIC', 2), ('A12', 1, 'PROJ', 1),
('A13', 1, 'LOUSA', 1),
('A14', 1, 'ESTANDE', 30), ('A14', 2, 'ESTANDE', 30), ('A14', 3, 'ESTANDE', 30),
('A15', 1, 'PROJ', 1), ('A15', 1, 'AUDIO', 1),
('A16', 1, 'PROJ', 1),
('A17', 1, 'COMP', 4),
('A18', 1, 'COMP', 5);

-- ------------------------------------------------------------
-- INSCRICOES NOS EVENTOS
-- (EV05 tem 5 vagas: P26 e P27 entram automaticamente em LISTA_ESPERA)
-- ------------------------------------------------------------
INSERT INTO inscricao_evento (evento_id, pessoa_id, data_inscricao) VALUES
('EV01', 'P21', '2025-08-01'), ('EV01', 'P22', '2025-08-01'), ('EV01', 'P23', '2025-08-03'),
('EV01', 'P24', '2025-08-05'), ('EV01', 'P25', '2025-08-06'), ('EV01', 'P26', '2025-08-10'),
('EV01', 'P27', '2025-08-12'), ('EV01', 'P03', '2025-08-15'), ('EV01', 'P04', '2025-08-15'),
('EV01', 'P19', '2025-08-20'),
('EV02', 'P21', '2026-08-01'), ('EV02', 'P22', '2026-08-02'), ('EV02', 'P23', '2026-08-02'),
('EV02', 'P24', '2026-08-04'), ('EV02', 'P25', '2026-08-05'), ('EV02', 'P26', '2026-08-07'),
('EV02', 'P27', '2026-08-07'), ('EV02', 'P28', '2026-08-09'), ('EV02', 'P29', '2026-08-10'),
('EV02', 'P30', '2026-08-11'), ('EV02', 'P13', '2026-08-12'), ('EV02', 'P19', '2026-08-15'),
('EV03', 'P21', '2026-10-01'), ('EV03', 'P22', '2026-10-01'), ('EV03', 'P23', '2026-10-02'),
('EV03', 'P24', '2026-10-03'), ('EV03', 'P25', '2026-10-05'), ('EV03', 'P26', '2026-10-06'),
('EV03', 'P04', '2026-10-07'), ('EV03', 'P10', '2026-10-08'), ('EV03', 'P14', '2026-10-09'),
('EV03', 'P15', '2026-10-10'), ('EV03', 'P20', '2026-10-12'),
('EV04', 'P21', '2026-10-15'), ('EV04', 'P23', '2026-10-15'), ('EV04', 'P27', '2026-10-18'),
('EV04', 'P29', '2026-10-20'), ('EV04', 'P30', '2026-10-21'), ('EV04', 'P13', '2026-10-22'),
('EV04', 'P16', '2026-10-25'),
('EV05', 'P21', '2026-10-20'), ('EV05', 'P22', '2026-10-20'), ('EV05', 'P23', '2026-10-21'),
('EV05', 'P24', '2026-10-22'), ('EV05', 'P25', '2026-10-23'), ('EV05', 'P26', '2026-10-24'),
('EV05', 'P27', '2026-10-25');

-- P23 desiste do EV05: trigger promove P26 (primeiro da lista de espera)
UPDATE inscricao_evento SET status = 'CANCELADA' WHERE evento_id = 'EV05' AND pessoa_id = 'P23';

-- ------------------------------------------------------------
-- INSCRICOES NAS SESSOES COM VAGAS LIMITADAS
-- ------------------------------------------------------------
INSERT INTO inscricao_sessao (atividade_id, num_sessao, pessoa_id, data_hora_inscricao) VALUES
-- EV01
('A02', 1, 'P21', '2025-08-02 10:00'), ('A02', 1, 'P22', '2025-08-02 10:05'),
('A02', 1, 'P23', '2025-08-04 14:30'), ('A02', 1, 'P24', '2025-08-06 09:12'),
('A02', 1, 'P25', '2025-08-07 16:40'), ('A02', 1, 'P26', '2025-08-11 11:00'),
('A02', 1, 'P27', '2025-08-13 08:20'),
-- EV02
('A05', 1, 'P21', '2026-08-02 09:00'), ('A05', 1, 'P22', '2026-08-03 10:15'),
('A05', 1, 'P23', '2026-08-03 11:00'), ('A05', 1, 'P24', '2026-08-05 13:45'),
('A05', 2, 'P25', '2026-08-06 08:30'), ('A05', 2, 'P26', '2026-08-08 19:10'),
('A05', 2, 'P27', '2026-08-08 20:00'),
('A06', 1, 'P21', '2026-08-02 09:05'), ('A06', 1, 'P28', '2026-08-10 15:00'),
('A06', 1, 'P29', '2026-08-11 10:00'),
('A06', 2, 'P30', '2026-08-12 18:00'), ('A06', 2, 'P13', '2026-08-13 09:30'),
('A08', 1, 'P22', '2026-08-03 10:20'), ('A08', 1, 'P23', '2026-08-03 11:05'),
('A08', 1, 'P24', '2026-08-05 13:50'), ('A08', 1, 'P19', '2026-08-16 17:00'),
('A08', 1, 'P28', '2026-08-10 15:10'),
-- EV03 (A13 tem 3 vagas: P15 e P20 vao para LISTA_ESPERA)
('A10', 1, 'P21', '2026-10-02 08:00'), ('A10', 1, 'P22', '2026-10-02 08:10'),
('A10', 1, 'P04', '2026-10-08 12:00'), ('A10', 1, 'P10', '2026-10-09 09:00'),
('A10', 2, 'P23', '2026-10-03 14:00'), ('A10', 2, 'P24', '2026-10-04 10:00'),
('A10', 2, 'P25', '2026-10-06 16:00'),
('A13', 1, 'P21', '2026-10-02 08:05'), ('A13', 1, 'P22', '2026-10-02 08:15'),
('A13', 1, 'P14', '2026-10-10 10:00'), ('A13', 1, 'P15', '2026-10-11 11:00'),
('A13', 1, 'P20', '2026-10-13 09:00'),
-- EV04
('A16', 2, 'P21', '2026-10-16 10:00'), ('A16', 2, 'P23', '2026-10-16 10:30'),
('A16', 2, 'P27', '2026-10-19 14:00'),
-- EV05 (A17 tem 4 vagas: P26 vai para LISTA_ESPERA)
('A17', 1, 'P21', '2026-10-21 09:00'), ('A17', 1, 'P22', '2026-10-21 09:30'),
('A17', 1, 'P24', '2026-10-22 10:00'), ('A17', 1, 'P25', '2026-10-23 11:00'),
('A17', 1, 'P26', '2026-10-25 12:00'),
('A18', 1, 'P21', '2026-10-21 09:05'), ('A18', 1, 'P22', '2026-10-21 09:35'),
('A18', 1, 'P26', '2026-10-25 12:05');

-- ------------------------------------------------------------
-- CANCELAMENTOS (tratados pelos triggers)
-- ------------------------------------------------------------
-- P22 desiste do workshop A13: P15 e promovido da lista de espera
UPDATE inscricao_sessao SET status = 'CANCELADA'
WHERE atividade_id = 'A13' AND num_sessao = 1 AND pessoa_id = 'P22';

-- P28 cancela a inscricao no EV02: suas inscricoes em sessoes do EV02 sao canceladas
UPDATE inscricao_evento SET status = 'CANCELADA' WHERE evento_id = 'EV02' AND pessoa_id = 'P28';

-- Segunda sessao da palestra A16 e cancelada: inscricoes nela sao canceladas
UPDATE sessao SET status = 'CANCELADA' WHERE atividade_id = 'A16' AND num_sessao = 2;

-- ------------------------------------------------------------
-- SESSOES JA REALIZADAS (eventos anteriores a data atual)
-- ------------------------------------------------------------
UPDATE sessao s SET status = 'REALIZADA'
FROM atividade a
WHERE a.atividade_id = s.atividade_id
  AND a.evento_id IN ('EV01', 'EV02')
  AND s.status = 'PROGRAMADA';
