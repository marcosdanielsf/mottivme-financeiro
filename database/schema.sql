-- ========================================
-- SCHEMA POSTGRESQL - LUNA FINANCEIRO
-- Arquitetura Híbrida: PostgreSQL + Airtable
-- ========================================

-- Extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- Para full-text search

-- Schema principal
CREATE SCHEMA IF NOT EXISTS luna_financeiro;

-- ========================================
-- ENUMS (Tipos Personalizados)
-- ========================================

CREATE TYPE luna_financeiro.tipo_documento AS ENUM (
    'contas_pagar',
    'contas_receber'
);

CREATE TYPE luna_financeiro.status_documento AS ENUM (
    'pendente',
    'aprovado',
    'rejeitado',
    'pago',
    'recebido',
    'cancelado',
    'vencido'
);

CREATE TYPE luna_financeiro.tipo_pagamento AS ENUM (
    'recorrente_mensal',
    'recorrente_anual',
    'pagamento_unico'
);

CREATE TYPE luna_financeiro.tipo_entidade AS ENUM (
    'fornecedor',
    'cliente'
);

CREATE TYPE luna_financeiro.forma_pagamento AS ENUM (
    'pix',
    'ted',
    'doc',
    'boleto',
    'cartao_credito',
    'cartao_debito',
    'dinheiro',
    'cheque'
);

-- ========================================
-- TABELA: Entidades (Fornecedores/Clientes)
-- ========================================

CREATE TABLE luna_financeiro.entidades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tipo luna_financeiro.tipo_entidade NOT NULL,
    nome VARCHAR(255) NOT NULL,
    nome_fantasia VARCHAR(255),
    cnpj_cpf VARCHAR(18) UNIQUE,
    email VARCHAR(255),
    telefone VARCHAR(20),
    whatsapp VARCHAR(20),

    -- Endereço
    cep VARCHAR(9),
    logradouro VARCHAR(255),
    numero VARCHAR(20),
    complemento VARCHAR(100),
    bairro VARCHAR(100),
    cidade VARCHAR(100),
    estado VARCHAR(2),

    -- Dados bancários
    banco VARCHAR(100),
    agencia VARCHAR(20),
    conta VARCHAR(30),
    tipo_conta VARCHAR(20),
    pix_key VARCHAR(255),

    -- Gestão
    ativo BOOLEAN DEFAULT TRUE,
    score INTEGER DEFAULT 50, -- Score de 0-100 para avaliação
    observacoes TEXT,

    -- Sincronização Airtable
    airtable_record_id VARCHAR(50) UNIQUE,

    -- Auditoria
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_by VARCHAR(100),

    -- Índices
    CONSTRAINT chk_cnpj_cpf_format CHECK (
        cnpj_cpf IS NULL OR
        cnpj_cpf ~ '^[0-9]{3}\.[0-9]{3}\.[0-9]{3}-[0-9]{2}$' OR  -- CPF
        cnpj_cpf ~ '^[0-9]{2}\.[0-9]{3}\.[0-9]{3}/[0-9]{4}-[0-9]{2}$' -- CNPJ
    )
);

CREATE INDEX idx_entidades_tipo ON luna_financeiro.entidades(tipo);
CREATE INDEX idx_entidades_cnpj_cpf ON luna_financeiro.entidades(cnpj_cpf);
CREATE INDEX idx_entidades_nome ON luna_financeiro.entidades USING gin(nome gin_trgm_ops);
CREATE INDEX idx_entidades_airtable ON luna_financeiro.entidades(airtable_record_id);

-- ========================================
-- TABELA: Categorias
-- ========================================

CREATE TABLE luna_financeiro.categorias (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome VARCHAR(100) NOT NULL UNIQUE,
    descricao TEXT,
    tipo luna_financeiro.tipo_documento NOT NULL,
    cor VARCHAR(7), -- Hex color (ex: #FF5733)
    icone VARCHAR(50),
    parent_id UUID REFERENCES luna_financeiro.categorias(id), -- Para subcategorias

    -- Orçamento
    orcamento_mensal DECIMAL(15, 2),

    -- Sincronização
    airtable_record_id VARCHAR(50) UNIQUE,

    -- Auditoria
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_categorias_tipo ON luna_financeiro.categorias(tipo);
CREATE INDEX idx_categorias_parent ON luna_financeiro.categorias(parent_id);

-- ========================================
-- TABELA: Centros de Custo
-- ========================================

CREATE TABLE luna_financeiro.centros_custo (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo VARCHAR(20) UNIQUE NOT NULL,
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    departamento VARCHAR(100),
    responsavel VARCHAR(100),
    ativo BOOLEAN DEFAULT TRUE,

    -- Orçamento
    orcamento_mensal DECIMAL(15, 2),

    -- Sincronização
    airtable_record_id VARCHAR(50) UNIQUE,

    -- Auditoria
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_centros_custo_codigo ON luna_financeiro.centros_custo(codigo);

-- ========================================
-- TABELA: Documentos Financeiros (Principal)
-- ========================================

CREATE TABLE luna_financeiro.documentos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Tipo e Status
    tipo luna_financeiro.tipo_documento NOT NULL,
    status luna_financeiro.status_documento DEFAULT 'pendente',

    -- Identificação do Documento
    numero_documento VARCHAR(100),
    numero_nf VARCHAR(50),
    chave_nfe VARCHAR(44), -- Chave NFe

    -- Datas
    data_emissao DATE NOT NULL,
    data_vencimento DATE NOT NULL,
    data_pagamento DATE,
    data_competencia DATE, -- Mês/ano que o gasto se refere

    -- Valores
    valor_bruto DECIMAL(15, 2) NOT NULL,
    valor_desconto DECIMAL(15, 2) DEFAULT 0,
    valor_juros DECIMAL(15, 2) DEFAULT 0,
    valor_multa DECIMAL(15, 2) DEFAULT 0,
    valor_liquido DECIMAL(15, 2) GENERATED ALWAYS AS (
        valor_bruto - valor_desconto + valor_juros + valor_multa
    ) STORED,
    moeda VARCHAR(3) DEFAULT 'BRL',

    -- Relacionamentos
    entidade_id UUID REFERENCES luna_financeiro.entidades(id),
    categoria_id UUID REFERENCES luna_financeiro.categorias(id),
    centro_custo_id UUID REFERENCES luna_financeiro.centros_custo(id),

    -- Descrição
    descricao TEXT NOT NULL,
    observacoes TEXT,

    -- Pagamento
    tipo_pagamento luna_financeiro.tipo_pagamento,
    forma_pagamento luna_financeiro.forma_pagamento,

    -- Arquivos
    arquivo_url TEXT,
    arquivo_google_drive_id VARCHAR(100),
    arquivo_nome VARCHAR(255),
    arquivo_mime_type VARCHAR(100),

    -- OCR e IA
    ocr_confianca DECIMAL(3, 2), -- 0.00 a 1.00
    ocr_processado_em TIMESTAMP,
    ia_categorizado BOOLEAN DEFAULT FALSE,
    ia_validado BOOLEAN DEFAULT FALSE,

    -- Recorrência
    recorrente BOOLEAN DEFAULT FALSE,
    documento_pai_id UUID REFERENCES luna_financeiro.documentos(id),

    -- Aprovação
    aprovado_por VARCHAR(100),
    aprovado_em TIMESTAMP,
    rejeitado_por VARCHAR(100),
    rejeitado_em TIMESTAMP,
    motivo_rejeicao TEXT,

    -- Conciliação Bancária
    conciliado BOOLEAN DEFAULT FALSE,
    conciliado_em TIMESTAMP,
    transacao_bancaria_id VARCHAR(100),

    -- Sincronização Airtable
    airtable_record_id VARCHAR(50) UNIQUE,
    ultima_sincronizacao TIMESTAMP,

    -- Auditoria
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_by VARCHAR(100),

    -- Constraints
    CONSTRAINT chk_valor_positivo CHECK (valor_bruto > 0),
    CONSTRAINT chk_datas CHECK (data_vencimento >= data_emissao),
    CONSTRAINT chk_ocr_confianca CHECK (ocr_confianca IS NULL OR (ocr_confianca >= 0 AND ocr_confianca <= 1))
);

-- Índices para performance
CREATE INDEX idx_documentos_tipo ON luna_financeiro.documentos(tipo);
CREATE INDEX idx_documentos_status ON luna_financeiro.documentos(status);
CREATE INDEX idx_documentos_data_vencimento ON luna_financeiro.documentos(data_vencimento);
CREATE INDEX idx_documentos_data_pagamento ON luna_financeiro.documentos(data_pagamento);
CREATE INDEX idx_documentos_entidade ON luna_financeiro.documentos(entidade_id);
CREATE INDEX idx_documentos_categoria ON luna_financeiro.documentos(categoria_id);
CREATE INDEX idx_documentos_centro_custo ON luna_financeiro.documentos(centro_custo_id);
CREATE INDEX idx_documentos_airtable ON luna_financeiro.documentos(airtable_record_id);
CREATE INDEX idx_documentos_created_at ON luna_financeiro.documentos(created_at DESC);
CREATE INDEX idx_documentos_conciliado ON luna_financeiro.documentos(conciliado) WHERE NOT conciliado;
CREATE INDEX idx_documentos_vencidos ON luna_financeiro.documentos(data_vencimento)
    WHERE status = 'pendente' AND data_vencimento < CURRENT_DATE;

-- Full-text search
CREATE INDEX idx_documentos_descricao_fts ON luna_financeiro.documentos USING gin(to_tsvector('portuguese', descricao));

-- ========================================
-- TABELA: Itens do Documento (Line Items)
-- ========================================

CREATE TABLE luna_financeiro.documentos_itens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    documento_id UUID NOT NULL REFERENCES luna_financeiro.documentos(id) ON DELETE CASCADE,

    sequencia INTEGER NOT NULL,
    descricao TEXT NOT NULL,
    quantidade DECIMAL(10, 3) DEFAULT 1,
    valor_unitario DECIMAL(15, 2) NOT NULL,
    valor_desconto DECIMAL(15, 2) DEFAULT 0,
    valor_total DECIMAL(15, 2) GENERATED ALWAYS AS (
        (quantidade * valor_unitario) - valor_desconto
    ) STORED,

    -- Produto/Serviço
    codigo_produto VARCHAR(50),
    categoria VARCHAR(100),

    -- Auditoria
    created_at TIMESTAMP DEFAULT NOW(),

    CONSTRAINT chk_quantidade_positiva CHECK (quantidade > 0),
    CONSTRAINT chk_valor_unitario_positivo CHECK (valor_unitario >= 0)
);

CREATE INDEX idx_documentos_itens_documento ON luna_financeiro.documentos_itens(documento_id);

-- ========================================
-- TABELA: Transações (Audit Log Imutável)
-- ========================================

CREATE TABLE luna_financeiro.transacoes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    documento_id UUID REFERENCES luna_financeiro.documentos(id),

    tipo_operacao VARCHAR(50) NOT NULL, -- INSERT, UPDATE, DELETE, APROVACAO, etc
    tabela VARCHAR(100) NOT NULL,

    -- Dados da mudança
    dados_anteriores JSONB,
    dados_novos JSONB,

    -- Quem fez
    usuario VARCHAR(100) NOT NULL,
    ip_address INET,
    user_agent TEXT,

    -- Quando
    created_at TIMESTAMP DEFAULT NOW(),

    -- Metadata
    observacao TEXT
);

-- Índices para auditoria
CREATE INDEX idx_transacoes_documento ON luna_financeiro.transacoes(documento_id);
CREATE INDEX idx_transacoes_usuario ON luna_financeiro.transacoes(usuario);
CREATE INDEX idx_transacoes_created_at ON luna_financeiro.transacoes(created_at DESC);
CREATE INDEX idx_transacoes_tipo ON luna_financeiro.transacoes(tipo_operacao);

-- ========================================
-- TABELA: Alertas e Notificações
-- ========================================

CREATE TABLE luna_financeiro.alertas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    documento_id UUID REFERENCES luna_financeiro.documentos(id),

    tipo VARCHAR(50) NOT NULL, -- vencimento, anomalia, aprovacao, etc
    severidade VARCHAR(20) DEFAULT 'info', -- info, warning, critical

    titulo VARCHAR(255) NOT NULL,
    mensagem TEXT NOT NULL,

    -- Destinatários
    destinatario_email VARCHAR(255),
    destinatario_whatsapp VARCHAR(20),

    -- Status
    enviado BOOLEAN DEFAULT FALSE,
    enviado_em TIMESTAMP,
    lido BOOLEAN DEFAULT FALSE,
    lido_em TIMESTAMP,

    -- Agendamento
    agendar_para TIMESTAMP,

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_alertas_documento ON luna_financeiro.alertas(documento_id);
CREATE INDEX idx_alertas_enviado ON luna_financeiro.alertas(enviado) WHERE NOT enviado;
CREATE INDEX idx_alertas_severidade ON luna_financeiro.alertas(severidade);

-- ========================================
-- TABELA: Configurações de Aprovação
-- ========================================

CREATE TABLE luna_financeiro.config_aprovacao (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    valor_minimo DECIMAL(15, 2) NOT NULL,
    valor_maximo DECIMAL(15, 2),

    aprovador_email VARCHAR(255) NOT NULL,
    aprovador_nome VARCHAR(100),
    cargo VARCHAR(100),

    tipo_documento luna_financeiro.tipo_documento,

    ativo BOOLEAN DEFAULT TRUE,
    ordem INTEGER DEFAULT 1, -- Para múltiplos níveis de aprovação

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    CONSTRAINT chk_valores_aprovacao CHECK (valor_maximo IS NULL OR valor_maximo > valor_minimo)
);

CREATE INDEX idx_config_aprovacao_valores ON luna_financeiro.config_aprovacao(valor_minimo, valor_maximo);

-- ========================================
-- TABELA: Conciliação Bancária
-- ========================================

CREATE TABLE luna_financeiro.conciliacao_bancaria (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Dados da transação bancária
    data_transacao DATE NOT NULL,
    descricao_banco TEXT,
    valor DECIMAL(15, 2) NOT NULL,
    tipo VARCHAR(20), -- debito, credito

    banco VARCHAR(100),
    agencia VARCHAR(20),
    conta VARCHAR(30),

    -- Identificadores
    transacao_id VARCHAR(100) UNIQUE,
    documento_origem TEXT,

    -- Match com documento
    documento_id UUID REFERENCES luna_financeiro.documentos(id),
    match_automatico BOOLEAN DEFAULT FALSE,
    match_confianca DECIMAL(3, 2), -- 0.00 a 1.00

    -- Status
    conciliado BOOLEAN DEFAULT FALSE,
    conciliado_por VARCHAR(100),
    conciliado_em TIMESTAMP,

    observacoes TEXT,

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_conciliacao_data ON luna_financeiro.conciliacao_bancaria(data_transacao DESC);
CREATE INDEX idx_conciliacao_documento ON luna_financeiro.conciliacao_bancaria(documento_id);
CREATE INDEX idx_conciliacao_pendente ON luna_financeiro.conciliacao_bancaria(conciliado) WHERE NOT conciliado;

-- ========================================
-- VIEWS (Consultas Úteis)
-- ========================================

-- View: Documentos Vencidos
CREATE VIEW luna_financeiro.vw_documentos_vencidos AS
SELECT
    d.*,
    e.nome as entidade_nome,
    c.nome as categoria_nome,
    CURRENT_DATE - d.data_vencimento as dias_vencido
FROM luna_financeiro.documentos d
LEFT JOIN luna_financeiro.entidades e ON d.entidade_id = e.id
LEFT JOIN luna_financeiro.categorias c ON d.categoria_id = c.id
WHERE d.status = 'pendente'
  AND d.data_vencimento < CURRENT_DATE;

-- View: Resumo Mensal
CREATE VIEW luna_financeiro.vw_resumo_mensal AS
SELECT
    DATE_TRUNC('month', data_vencimento) as mes,
    tipo,
    status,
    COUNT(*) as quantidade,
    SUM(valor_liquido) as total
FROM luna_financeiro.documentos
GROUP BY DATE_TRUNC('month', data_vencimento), tipo, status;

-- View: Fluxo de Caixa
CREATE VIEW luna_financeiro.vw_fluxo_caixa AS
WITH recebimentos AS (
    SELECT data_vencimento, SUM(valor_liquido) as total
    FROM luna_financeiro.documentos
    WHERE tipo = 'contas_receber' AND status IN ('pendente', 'aprovado')
    GROUP BY data_vencimento
),
pagamentos AS (
    SELECT data_vencimento, SUM(valor_liquido) as total
    FROM luna_financeiro.documentos
    WHERE tipo = 'contas_pagar' AND status IN ('pendente', 'aprovado')
    GROUP BY data_vencimento
)
SELECT
    COALESCE(r.data_vencimento, p.data_vencimento) as data,
    COALESCE(r.total, 0) as recebimentos,
    COALESCE(p.total, 0) as pagamentos,
    COALESCE(r.total, 0) - COALESCE(p.total, 0) as saldo_dia
FROM recebimentos r
FULL OUTER JOIN pagamentos p ON r.data_vencimento = p.data_vencimento
ORDER BY data;

-- ========================================
-- FUNCTIONS (Funções Úteis)
-- ========================================

-- Função: Marcar pagamentos atrasados automaticamente
CREATE OR REPLACE FUNCTION luna_financeiro.marcar_pagamentos_atrasados()
RETURNS INTEGER AS $$
DECLARE
    quantidade_atualizada INTEGER;
BEGIN
    UPDATE luna_financeiro.documentos
    SET status = 'vencido',
        updated_at = NOW()
    WHERE status = 'pendente'
      AND data_vencimento < CURRENT_DATE;

    GET DIAGNOSTICS quantidade_atualizada = ROW_COUNT;

    -- Criar alertas
    INSERT INTO luna_financeiro.alertas (documento_id, tipo, severidade, titulo, mensagem)
    SELECT
        id,
        'vencimento',
        'critical',
        'Documento Vencido',
        'O documento ' || numero_documento || ' venceu em ' || data_vencimento
    FROM luna_financeiro.documentos
    WHERE status = 'vencido'
      AND NOT EXISTS (
          SELECT 1 FROM luna_financeiro.alertas a
          WHERE a.documento_id = documentos.id
            AND a.tipo = 'vencimento'
      );

    RETURN quantidade_atualizada;
END;
$$ LANGUAGE plpgsql;

-- Função: Atualizar timestamp automático
CREATE OR REPLACE FUNCTION luna_financeiro.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Função: Registrar auditoria automática
CREATE OR REPLACE FUNCTION luna_financeiro.registrar_auditoria()
RETURNS TRIGGER AS $$
DECLARE
    tipo_op VARCHAR(50);
    usuario_atual VARCHAR(100);
BEGIN
    -- Determinar tipo de operação
    IF TG_OP = 'INSERT' THEN
        tipo_op := 'INSERT';
    ELSIF TG_OP = 'UPDATE' THEN
        tipo_op := 'UPDATE';
    ELSIF TG_OP = 'DELETE' THEN
        tipo_op := 'DELETE';
    END IF;

    -- Pegar usuário atual (você pode ajustar isso conforme sua lógica de auth)
    usuario_atual := COALESCE(current_setting('app.current_user', TRUE), 'sistema');

    -- Inserir log
    IF TG_OP = 'DELETE' THEN
        INSERT INTO luna_financeiro.transacoes (
            documento_id, tipo_operacao, tabela, dados_anteriores, usuario, created_at
        ) VALUES (
            OLD.id, tipo_op, TG_TABLE_NAME, row_to_json(OLD), usuario_atual, NOW()
        );
        RETURN OLD;
    ELSE
        INSERT INTO luna_financeiro.transacoes (
            documento_id, tipo_operacao, tabela, dados_anteriores, dados_novos, usuario, created_at
        ) VALUES (
            NEW.id, tipo_op, TG_TABLE_NAME,
            CASE WHEN TG_OP = 'UPDATE' THEN row_to_json(OLD) ELSE NULL END,
            row_to_json(NEW), usuario_atual, NOW()
        );
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- TRIGGERS
-- ========================================

-- Trigger: Atualizar timestamp em entidades
CREATE TRIGGER trg_entidades_update_timestamp
    BEFORE UPDATE ON luna_financeiro.entidades
    FOR EACH ROW
    EXECUTE FUNCTION luna_financeiro.update_timestamp();

-- Trigger: Atualizar timestamp em documentos
CREATE TRIGGER trg_documentos_update_timestamp
    BEFORE UPDATE ON luna_financeiro.documentos
    FOR EACH ROW
    EXECUTE FUNCTION luna_financeiro.update_timestamp();

-- Trigger: Auditoria em documentos
CREATE TRIGGER trg_documentos_auditoria
    AFTER INSERT OR UPDATE OR DELETE ON luna_financeiro.documentos
    FOR EACH ROW
    EXECUTE FUNCTION luna_financeiro.registrar_auditoria();

-- Trigger: Auditoria em entidades
CREATE TRIGGER trg_entidades_auditoria
    AFTER INSERT OR UPDATE OR DELETE ON luna_financeiro.entidades
    FOR EACH ROW
    EXECUTE FUNCTION luna_financeiro.registrar_auditoria();

-- ========================================
-- DADOS INICIAIS (Seed)
-- ========================================

-- Categorias padrão para Contas a Pagar
INSERT INTO luna_financeiro.categorias (nome, descricao, tipo, cor) VALUES
('Aluguel', 'Pagamento de aluguel', 'contas_pagar', '#FF6B6B'),
('Salários', 'Folha de pagamento', 'contas_pagar', '#4ECDC4'),
('Impostos', 'Impostos e taxas', 'contas_pagar', '#95E1D3'),
('Marketing', 'Despesas com marketing', 'contas_pagar', '#F38181'),
('TI e Software', 'Sistemas e tecnologia', 'contas_pagar', '#AA96DA'),
('Fornecedores', 'Compras de fornecedores', 'contas_pagar', '#FCBAD3'),
('Utilidades', 'Energia, água, internet', 'contas_pagar', '#A8D8EA'),
('Despesas Gerais', 'Outras despesas', 'contas_pagar', '#E8B4B8');

-- Categorias padrão para Contas a Receber
INSERT INTO luna_financeiro.categorias (nome, descricao, tipo, cor) VALUES
('Vendas de Produtos', 'Receita com vendas', 'contas_receber', '#90EE90'),
('Prestação de Serviços', 'Receita com serviços', 'contas_receber', '#87CEEB'),
('Assinaturas', 'Receitas recorrentes', 'contas_receber', '#DDA0DD'),
('Outras Receitas', 'Receitas diversas', 'contas_receber', '#F0E68C');

-- Configurações de aprovação padrão
INSERT INTO luna_financeiro.config_aprovacao (valor_minimo, valor_maximo, aprovador_email, cargo, ordem) VALUES
(0, 1000, 'financeiro@mottivme.com.br', 'Automático', 1),
(1000, 5000, 'gerente@mottivme.com.br', 'Gerente Financeiro', 2),
(5000, NULL, 'diretoria@mottivme.com.br', 'Diretoria', 3);

-- ========================================
-- PERMISSÕES (ajuste conforme necessário)
-- ========================================

-- Grant acesso ao schema
GRANT USAGE ON SCHEMA luna_financeiro TO PUBLIC;

-- Grant acesso às tabelas
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA luna_financeiro TO PUBLIC;

-- Grant acesso às sequences
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA luna_financeiro TO PUBLIC;

-- Grant execução das funções
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA luna_financeiro TO PUBLIC;

-- ========================================
-- COMENTÁRIOS (Documentação)
-- ========================================

COMMENT ON SCHEMA luna_financeiro IS 'Schema principal do sistema financeiro Luna - Arquitetura híbrida PostgreSQL + Airtable';
COMMENT ON TABLE luna_financeiro.documentos IS 'Tabela principal de documentos financeiros (contas a pagar e receber)';
COMMENT ON TABLE luna_financeiro.transacoes IS 'Log imutável de auditoria - NUNCA deletar registros desta tabela';
COMMENT ON COLUMN luna_financeiro.documentos.airtable_record_id IS 'ID do registro sincronizado no Airtable';
COMMENT ON FUNCTION luna_financeiro.marcar_pagamentos_atrasados IS 'Job diário para marcar documentos vencidos';

-- ========================================
-- FIM DO SCHEMA
-- ========================================
