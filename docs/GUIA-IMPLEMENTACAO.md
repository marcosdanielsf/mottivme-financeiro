# 🚀 GUIA DE IMPLEMENTAÇÃO - LUNA FINANCEIRO
## Arquitetura Híbrida PostgreSQL + Airtable

---

## 📋 PRÉ-REQUISITOS

Antes de começar, certifique-se de ter:

- [ ] Conta Google (para Drive, Sheets, Vision OCR)
- [ ] Conta Supabase (PostgreSQL gerenciado)
- [ ] Conta Airtable (plano Plus ou Pro)
- [ ] Conta Anthropic ou OpenAI (para IA)
- [ ] N8N instalado (cloud ou self-hosted)
- [ ] Domínio próprio (opcional mas recomendado)

---

## 🎯 FASE 1: SETUP DO BANCO DE DADOS (1-2 horas)

### **Passo 1.1: Criar Projeto no Supabase**

1. Acesse [supabase.com](https://supabase.com)
2. Crie novo projeto:
   - Nome: `luna-financeiro`
   - Database Password: **ANOTE EM LOCAL SEGURO**
   - Região: `South America (São Paulo)`
   - Plano: Pro ($25/mês)

3. Aguarde provisionamento (2-3 minutos)

### **Passo 1.2: Executar Schema SQL**

1. No Supabase, vá em **SQL Editor**
2. Cole o conteúdo de `/database/schema.sql`
3. Clique em **Run**
4. Aguarde execução (pode demorar 1-2 minutos)

**Validação:**
```sql
-- Execute no SQL Editor para verificar
SELECT
  table_schema,
  table_name
FROM information_schema.tables
WHERE table_schema = 'luna_financeiro'
ORDER BY table_name;

-- Deve retornar ~10 tabelas
```

### **Passo 1.3: Configurar Webhooks PostgreSQL**

```sql
-- Criar função para notificar N8N quando houver mudanças
CREATE OR REPLACE FUNCTION luna_financeiro.notify_n8n()
RETURNS TRIGGER AS $$
DECLARE
  payload JSON;
BEGIN
  -- Preparar payload
  payload = json_build_object(
    'table', TG_TABLE_NAME,
    'operation', TG_OP,
    'record_id', NEW.id,
    'timestamp', NOW()
  );

  -- Fazer HTTP request para N8N (você vai configurar a URL depois)
  -- Por enquanto só logamos
  RAISE NOTICE 'Webhook trigger: %', payload;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Adicionar trigger na tabela documentos
CREATE TRIGGER trg_notify_documentos_change
  AFTER INSERT OR UPDATE ON luna_financeiro.documentos
  FOR EACH ROW
  EXECUTE FUNCTION luna_financeiro.notify_n8n();
```

### **Passo 1.4: Anotar Credenciais**

No Supabase, vá em **Settings > API** e anote:

```
URL: https://xxxxxxxxxxxxx.supabase.co
anon key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
service_role key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**⚠️ IMPORTANTE**: Guarde essas chaves em local seguro!

---

## 🗂️ FASE 2: SETUP DO AIRTABLE (1 hora)

### **Passo 2.1: Criar Base**

1. Acesse [airtable.com](https://airtable.com)
2. Crie nova base: **Luna Financeiro**
3. Delete a tabela padrão

### **Passo 2.2: Criar Estrutura**

Siga o guia em `/database/airtable-structure.md` para criar:

1. **Tabela: Documentos Financeiros**
   - Copie todos os campos listados
   - Configure tipos corretamente
   - Adicione as 8 views sugeridas

2. **Tabela: Entidades**
   - Campos de fornecedores/clientes
   - Link reverso para Documentos

3. **Tabela: Categorias**
   - Categorias pré-populadas
   - Cores e ícones

4. **Tabela: Centros de Custo**
   - Departamentos
   - Orçamentos

5. **Tabela: Alertas**
   - Sistema de notificações

6. **Tabela: Conciliação Bancária**
   - Para matches automáticos

**Dica**: Use o botão "Duplicate base" se quiser criar de um template.

### **Passo 2.3: Configurar Automações Airtable**

**Automação 1: Webhook para N8N**

1. Em Automations, criar nova
2. Trigger: "When record matches conditions"
   - View: Todos os Documentos
   - Condition: When record is created OR updated
3. Action: "Send webhook"
   - URL: `https://seu-n8n.com/webhook/airtable-to-postgres`
   - Method: POST
   - Body:
   ```json
   {
     "record_id": "{Record ID}",
     "fields": "{All fields}"
   }
   ```

### **Passo 2.4: Obter API Key**

1. Vá em [airtable.com/create/tokens](https://airtable.com/create/tokens)
2. Criar novo token:
   - Name: `N8N Integration`
   - Scopes:
     - `data.records:read`
     - `data.records:write`
     - `schema.bases:read`
   - Access: Selecione a base "Luna Financeiro"
3. **COPIE O TOKEN** (só aparece uma vez!)

### **Passo 2.5: Anotar IDs**

```
Base ID: appXXXXXXXXXXXXXX
  → Encontre na URL: airtable.com/appXXXXXXXXXXXXXX/...

Table IDs:
  → Documentos: tblXXXXXXXXXXXXXX
  → Entidades: tblYYYYYYYYYYYYYY
  → etc
```

---

## ⚙️ FASE 3: SETUP DO N8N (2-3 horas)

### **Passo 3.1: Instalar N8N (se ainda não tem)**

**Opção A: N8N Cloud** (mais fácil)
```
1. Acesse n8n.cloud
2. Crie conta
3. Escolha plano (€20/mês)
4. Pronto!
```

**Opção B: Self-hosted** (mais barato)
```bash
# Em um servidor Ubuntu (Hetzner, DigitalOcean, etc)
docker run -d \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  -e N8N_BASIC_AUTH_ACTIVE=true \
  -e N8N_BASIC_AUTH_USER=admin \
  -e N8N_BASIC_AUTH_PASSWORD=SenhaForte123! \
  -e WEBHOOK_URL=https://n8n.seudominio.com/ \
  n8nio/n8n:latest

# Configurar Nginx reverse proxy + SSL (Certbot)
```

### **Passo 3.2: Configurar Credenciais**

No N8N, vá em **Credentials** e adicione:

**1. PostgreSQL**
- Host: Seu Supabase URL
- Database: `postgres`
- User: `postgres`
- Password: Senha do Supabase
- SSL: `require`

**2. Airtable OAuth2**
- Access Token: Token criado no passo 2.4

**3. OpenAI / Anthropic**
- API Key: Sua chave da API

**4. Google Drive OAuth2**
- Siga wizard de autenticação

**5. Gmail OAuth2** (se usar)
- Siga wizard

**6. SMTP** (para alertas)
- Host: smtp.gmail.com (ou outro)
- Port: 587
- User/Pass: Suas credenciais

### **Passo 3.3: Importar Workflows**

1. **Sync PostgreSQL ↔ Airtable**
   ```
   - Abra /workflows/sync-postgres-airtable.json
   - Substitua {{POSTGRES_CREDENTIAL_ID}} pelo ID real
   - Substitua {{AIRTABLE_CREDENTIAL_ID}} pelo ID real
   - Substitua {{AIRTABLE_BASE_ID}} pela Base ID real
   - Importe no N8N
   ```

2. **Invoice Extractor** (já existe)
   - Validar se está funcionando
   - Atualizar para salvar direto no PostgreSQL

3. **Sofia Assistente** (já existe)
   - Validar conexão com PostgreSQL
   - Adicionar novas ferramentas

### **Passo 3.4: Ativar Webhooks**

1. Ative o workflow **Sync PostgreSQL ↔ Airtable**
2. Copie as URLs dos webhooks:
   ```
   PostgreSQL → Airtable:
   https://n8n.seudominio.com/webhook/postgres-to-airtable

   Airtable → PostgreSQL:
   https://n8n.seudominio.com/webhook/airtable-to-postgres
   ```

3. Configure no PostgreSQL (via Supabase Webhooks):
   - Settings > Database > Webhooks
   - Criar webhook para tabela `documentos`
   - URL: webhook do N8N
   - Events: INSERT, UPDATE

4. Já configurou no Airtable (passo 2.3)

---

## 🧪 FASE 4: TESTES (1 hora)

### **Teste 1: PostgreSQL → Airtable**

```sql
-- No Supabase SQL Editor
INSERT INTO luna_financeiro.documentos (
  tipo, status, numero_documento, data_emissao,
  data_vencimento, valor_bruto, descricao
) VALUES (
  'contas_pagar', 'pendente', 'TEST-001',
  CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days',
  1500.00, 'Teste de sincronização PG → Airtable'
);
```

**Validar:**
- Aguarde 5-10 segundos
- Verifique no Airtable se o registro apareceu
- Confira se `ID PostgreSQL` está preenchido

### **Teste 2: Airtable → PostgreSQL**

1. No Airtable, edite o registro criado
2. Mude o Status para "Aprovado"
3. Adicione uma observação

**Validar:**
```sql
-- No Supabase
SELECT * FROM luna_financeiro.documentos
WHERE numero_documento = 'TEST-001';

-- Deve mostrar Status = 'aprovado' e observação atualizada
```

**Verificar audit log:**
```sql
SELECT * FROM luna_financeiro.transacoes
WHERE documento_id = (
  SELECT id FROM luna_financeiro.documentos
  WHERE numero_documento = 'TEST-001'
)
ORDER BY created_at DESC;

-- Deve mostrar 2 registros: INSERT e SYNC_FROM_AIRTABLE
```

### **Teste 3: Invoice Extractor**

1. Pegue uma fatura de teste (PDF)
2. Faça upload no Google Drive (pasta monitorada)
3. Aguarde processamento (30s - 1min)

**Validar:**
- Dados extraídos no PostgreSQL
- Registro sincronizado no Airtable
- Arquivo anexado no Airtable

### **Teste 4: Chat com Luna**

(Se já tem WhatsApp configurado)

```
Você: Luna, quantos documentos pendentes temos?
Luna: [Consulta PostgreSQL e responde]

Você: Qual o total a pagar este mês?
Luna: [Calcula e responde]
```

---

## 📊 FASE 5: MIGRAÇÃO DE DADOS EXISTENTES (2-4 horas)

### **Passo 5.1: Exportar Dados Atuais**

Se você já tem dados em outro sistema:

1. Exporte para CSV
2. Mapeie colunas para o schema PostgreSQL
3. Use SQL ou ferramenta de import

### **Passo 5.2: Preparar CSV**

Exemplo de CSV para importação:

```csv
tipo,status,numero_documento,data_emissao,data_vencimento,valor_bruto,descricao
contas_pagar,pendente,NF-001,2025-01-15,2025-02-15,2500.00,Fornecedor ABC
contas_receber,recebido,REC-001,2025-01-10,2025-01-10,5000.00,Cliente XYZ
```

### **Passo 5.3: Importar via Supabase**

```sql
-- 1. Criar tabela temporária
CREATE TEMP TABLE import_temp (
  tipo TEXT,
  status TEXT,
  numero_documento TEXT,
  data_emissao DATE,
  data_vencimento DATE,
  valor_bruto DECIMAL,
  descricao TEXT
);

-- 2. Importar CSV (via Supabase UI ou pgAdmin)
-- Use o botão "Import data" no Supabase

-- 3. Transferir para tabela final
INSERT INTO luna_financeiro.documentos (
  tipo, status, numero_documento, data_emissao,
  data_vencimento, valor_bruto, descricao, created_by
)
SELECT
  tipo::luna_financeiro.tipo_documento,
  status::luna_financeiro.status_documento,
  numero_documento,
  data_emissao,
  data_vencimento,
  valor_bruto,
  descricao,
  'importacao_inicial'
FROM import_temp;

-- 4. Validar
SELECT COUNT(*) FROM luna_financeiro.documentos
WHERE created_by = 'importacao_inicial';
```

### **Passo 5.4: Sincronizar para Airtable**

```
1. Execute o workflow de sincronização manualmente
2. Ou aguarde a sincronização diária (3h)
3. Valide no Airtable
```

---

## 👥 FASE 6: CONFIGURAÇÃO DE USUÁRIOS (30 min)

### **Passo 6.1: Configurar Aprovadores**

```sql
-- Adicionar configurações de aprovação
INSERT INTO luna_financeiro.config_aprovacao
  (valor_minimo, valor_maximo, aprovador_email, cargo, ordem)
VALUES
  (0, 1000, 'automatico@mottivme.com', 'Automático', 1),
  (1000, 5000, 'gerente@mottivme.com', 'Gerente Financeiro', 2),
  (5000, NULL, 'ceo@mottivme.com', 'CEO', 3);
```

### **Passo 6.2: Permissões Airtable**

1. Share da base para equipe
2. Configurar permissões:
   - **Admin**: Você (full access)
   - **Editor**: Time financeiro (edit records)
   - **Viewer**: Outros (comment only)

### **Passo 6.3: Configurar Alertas**

```sql
-- Emails que receberão alertas
UPDATE luna_financeiro.categorias
SET observacoes = jsonb_build_object(
  'alerta_email', 'financeiro@mottivme.com'
)
WHERE nome = 'Aluguel';
```

---

## 📱 FASE 7: INTEGRAÇÃO WHATSAPP (Opcional, 2 horas)

### **Passo 7.1: Instalar Evolution API**

```bash
# Se self-hosted
git clone https://github.com/EvolutionAPI/evolution-api.git
cd evolution-api
docker-compose up -d
```

### **Passo 7.2: Conectar WhatsApp**

1. Acesse Evolution API
2. Crie instância
3. Escaneie QR Code
4. Obtenha API Key

### **Passo 7.3: Configurar N8N**

- Adicionar credencial Evolution API
- Criar webhook para mensagens
- Conectar com Luna Agent

---

## 🎓 FASE 8: TREINAMENTO DA EQUIPE (1 dia)

### **Documentação para Usuários:**

Crie um guia simples:

**Para o Time Financeiro:**
```
1. Como acessar o Airtable
2. Como adicionar novo documento manualmente
3. Como aprovar pagamentos
4. Como consultar relatórios
5. Como interpretar alertas
```

**Para Aprovadores:**
```
1. Como receber alertas por email
2. Como aprovar/rejeitar pelo Airtable
3. Como ver histórico de aprovações
```

**Para Luna (Chat):**
```
Comandos úteis:
- "Luna, quanto temos a pagar esta semana?"
- "Luna, qual o saldo previsto para mês que vem?"
- "Luna, quem são nossos maiores fornecedores?"
- "Luna, tem algum pagamento atrasado?"
```

---

## ✅ CHECKLIST FINAL

Antes de ir para produção:

### **Segurança:**
- [ ] Senhas fortes em todos sistemas
- [ ] 2FA ativado (Supabase, Airtable, N8N)
- [ ] Backup automático configurado
- [ ] SSL/HTTPS em todos endpoints

### **Funcionalidade:**
- [ ] Sincronização PG → AT funcionando
- [ ] Sincronização AT → PG funcionando
- [ ] Sync diário agendado (3h)
- [ ] Invoice Extractor processando
- [ ] Luna respondendo no WhatsApp
- [ ] Alertas sendo enviados

### **Dados:**
- [ ] Categorias pré-cadastradas
- [ ] Fornecedores/Clientes importados
- [ ] Centros de custo criados
- [ ] Histórico migrado (se houver)

### **Monitoramento:**
- [ ] Email de divergências configurado
- [ ] Uptime Kuma monitorando
- [ ] Logs funcionando

### **Documentação:**
- [ ] Guia do usuário criado
- [ ] Contatos de suporte definidos
- [ ] Processos documentados

---

## 🆘 TROUBLESHOOTING

### **Problema: Sincronização não funciona**

```
1. Verificar logs do N8N
2. Testar webhooks manualmente (Postman)
3. Validar credenciais
4. Conferir IDs das bases/tabelas
```

### **Problema: OCR com baixa precisão**

```
1. Melhorar qualidade da imagem
2. Aumentar DPI do scan
3. Ajustar prompt do LLM
4. Considerar pré-processamento de imagem
```

### **Problema: Performance lenta**

```
1. Verificar índices do PostgreSQL
2. Limpar cache Redis
3. Otimizar queries (EXPLAIN ANALYZE)
4. Considerar upgrade de plano
```

---

## 📞 PRÓXIMOS PASSOS

Após implementação:

**Semana 1:**
- Monitorar de perto
- Ajustar prompts da Luna
- Refinar categorias
- Treinar equipe

**Mês 1:**
- Coletar feedback
- Ajustar workflows
- Adicionar automações
- Otimizar performance

**Trimestre 1:**
- Implementar melhorias sugeridas
- Adicionar novos recursos
- Escalar para outros departamentos

---

## 🎯 SUPORTE

**Dúvidas sobre:**
- PostgreSQL/Supabase: docs.supabase.com
- Airtable: support.airtable.com
- N8N: community.n8n.io
- Este projeto: [Criar issue no GitHub]

**Contato:**
- Email: suporte@mottivme.com.br
- WhatsApp: [número]

---

**Boa implementação! 🚀**
