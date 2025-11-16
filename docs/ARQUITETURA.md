# 🏗️ ARQUITETURA HÍBRIDA - LUNA FINANCEIRO

## Visão Geral

Sistema financeiro inteligente com arquitetura híbrida PostgreSQL + Airtable, combinando robustez de banco de dados relacional com interface visual amigável.

---

## 🎯 Princípios de Design

1. **PostgreSQL como Fonte da Verdade**
   - Todos os dados críticos armazenados no PostgreSQL
   - Backup automático e auditoria completa
   - Integridade referencial garantida

2. **Airtable como Interface**
   - Visualização amigável para a equipe
   - Edição facilitada com validações
   - Dashboards e relatórios visuais

3. **Sincronização Bidirecional**
   - Tempo real via webhooks
   - Sincronização full diária
   - Resolução de conflitos automática

4. **Auditoria Completa**
   - Todo log imutável no PostgreSQL
   - Rastreabilidade total de mudanças
   - Compliance LGPD

---

## 📐 Diagrama de Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    CAMADA DE APRESENTAÇÃO                    │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │   AIRTABLE   │◄───────►│  WHATSAPP    │                  │
│  │  (Interface) │         │   (Chat)     │                  │
│  └──────┬───────┘         └──────┬───────┘                  │
│         │                        │                           │
└─────────┼────────────────────────┼───────────────────────────┘
          │                        │
          │  Webhooks             │  Evolution API
          ▼                        ▼
┌─────────────────────────────────────────────────────────────┐
│                   CAMADA DE ORQUESTRAÇÃO                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│              ┌────────────────────────────┐                  │
│              │         N8N                │                  │
│              │                            │                  │
│              │  ┌──────────────────────┐  │                  │
│              │  │  Sync PG ↔ Airtable │  │                  │
│              │  └──────────────────────┘  │                  │
│              │                            │                  │
│              │  ┌──────────────────────┐  │                  │
│              │  │  Luna Agent (Sofia)  │  │                  │
│              │  └──────────────────────┘  │                  │
│              │                            │                  │
│              │  ┌──────────────────────┐  │                  │
│              │  │  Invoice Extractor   │  │                  │
│              │  └──────────────────────┘  │                  │
│              │                            │                  │
│              │  ┌──────────────────────┐  │                  │
│              │  │  Conciliação Banc.   │  │                  │
│              │  └──────────────────────┘  │                  │
│              └────────────────────────────┘                  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                           │
                           │  SQL / HTTP
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    CAMADA DE DADOS                           │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────────────────────────────────┐              │
│  │         POSTGRESQL (Supabase)              │              │
│  │                                            │              │
│  │  Schema: luna_financeiro                  │              │
│  │  ├─ documentos                            │              │
│  │  ├─ entidades                             │              │
│  │  ├─ categorias                            │              │
│  │  ├─ centros_custo                         │              │
│  │  ├─ transacoes (audit log)                │              │
│  │  ├─ alertas                               │              │
│  │  ├─ conciliacao_bancaria                  │              │
│  │  └─ config_aprovacao                      │              │
│  │                                            │              │
│  │  + Views, Functions, Triggers             │              │
│  │  + Backup automático                      │              │
│  │  + Point-in-time recovery                 │              │
│  └────────────────────────────────────────────┘              │
│                                                               │
│  ┌────────────────────────────────────────────┐              │
│  │         REDIS (Cache)                      │              │
│  │  - Sessões                                 │              │
│  │  - Cache de queries                        │              │
│  │  - Queue de jobs                           │              │
│  └────────────────────────────────────────────┘              │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                           │
                           │  Backup
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  CAMADA DE INTEGRAÇÃO                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │  Google  │  │ OpenAI/  │  │  Kommo   │  │  Email   │    │
│  │  Drive   │  │ Claude   │  │   CRM    │  │  SMTP    │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                   │
│  │   Open   │  │  Google  │  │  Vision  │                   │
│  │  Finance │  │  Sheets  │  │   OCR    │                   │
│  └──────────┘  └──────────┘  └──────────┘                   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Fluxo de Dados

### **1. Entrada de Documento (Invoice Extractor)**

```
┌─────────────┐
│  Documento  │ (PDF/Imagem)
│   Upload    │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│  Google Drive   │ Trigger: novo arquivo
│   Monitoring    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Extract Text   │ Vision OCR
│   from File     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  LLM Extract    │ GPT-4 / Claude
│    Structured   │ JSON Schema
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Validate &    │ Validações
│    Transform    │ Regras de negócio
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    INSERT       │ PostgreSQL
│  luna_financeiro│ .documentos
│   .documentos   │
└────────┬────────┘
         │
         ▼ (Trigger PostgreSQL)
┌─────────────────┐
│   Webhook to    │ N8N Sync Workflow
│      N8N        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   CREATE/       │ Airtable
│    UPDATE       │ Documentos table
│   Airtable      │
└─────────────────┘
```

### **2. Edição Manual no Airtable**

```
┌─────────────┐
│   Usuário   │ Edita no Airtable
│  edita no   │
│  Airtable   │
└──────┬──────┘
       │
       ▼ (Webhook Airtable)
┌─────────────────┐
│   N8N Sync      │ Workflow ativado
│   Workflow      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Fetch from    │ Buscar dados
│    Airtable     │ atualizados
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Validate &    │ Transformar
│    Transform    │ AT → PG format
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     UPDATE      │ PostgreSQL
│   PostgreSQL    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Audit Log     │ Registrar mudança
│   (transacoes)  │ na tabela audit
└─────────────────┘
```

### **3. Chat com Luna (Sofia)**

```
┌─────────────┐
│   Usuário   │ "Luna, quanto tenho a pagar?"
│   pergunta  │
│  WhatsApp   │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│  Evolution API  │ Webhook to N8N
│  (WhatsApp)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Luna Agent     │ LangChain Agent
│  (LangChain)    │ com memória
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  PostgreSQL     │ Consulta usando
│    Tools        │ 15+ ferramentas
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Resposta      │ Formatada e amigável
│   para usuário  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   WhatsApp      │ Mensagem enviada
│    Message      │
└─────────────────┘
```

---

## 🗄️ Modelo de Dados

### **Entidades Principais:**

```sql
luna_financeiro.documentos (Principal)
├─ id (UUID, PK)
├─ tipo (contas_pagar | contas_receber)
├─ status (pendente | aprovado | pago | vencido | cancelado)
├─ numero_documento
├─ data_vencimento
├─ valor_liquido (calculado)
├─ entidade_id (FK → entidades)
├─ categoria_id (FK → categorias)
├─ centro_custo_id (FK → centros_custo)
├─ airtable_record_id (sincronização)
└─ + 30 campos adicionais

luna_financeiro.entidades (Fornecedores/Clientes)
├─ id (UUID, PK)
├─ tipo (fornecedor | cliente)
├─ nome
├─ cnpj_cpf (UNIQUE)
├─ dados_bancarios
├─ score (0-100)
└─ airtable_record_id

luna_financeiro.transacoes (Audit Log - IMUTÁVEL)
├─ id (UUID, PK)
├─ documento_id (FK)
├─ tipo_operacao (INSERT | UPDATE | DELETE | SYNC | etc)
├─ dados_anteriores (JSONB)
├─ dados_novos (JSONB)
├─ usuario
├─ created_at
└─ observacao
```

### **Relacionamentos:**

```
documentos 1──N entidades (fornecedor/cliente)
documentos 1──N categorias
documentos 1──N centros_custo
documentos 1──N documentos_itens (line items)
documentos 1──N transacoes (audit)
documentos 1──1 conciliacao_bancaria
```

---

## 🔐 Segurança

### **Camadas de Proteção:**

1. **Autenticação**
   - PostgreSQL: Row Level Security (RLS)
   - Airtable: Permissões por usuário
   - N8N: Credenciais encriptadas

2. **Autorização**
   - Aprovação multinível por valor
   - Segregação de funções
   - Audit trail completo

3. **Criptografia**
   - Em trânsito: TLS 1.3
   - Em repouso: AES-256 (Supabase)
   - Backups: Encriptados

4. **Compliance**
   - LGPD: Consentimento + Esquecimento
   - Logs imutáveis (append-only)
   - Backup 7 anos (fiscal)

---

## ⚡ Performance

### **Otimizações:**

1. **Índices Estratégicos**
   ```sql
   - idx_documentos_data_vencimento (B-tree)
   - idx_documentos_status (B-tree)
   - idx_documentos_descricao_fts (GIN, full-text)
   - idx_documentos_vencidos (Partial, WHERE status='pendente')
   ```

2. **Cache**
   - Redis para queries frequentes
   - TTL: 5 minutos
   - Invalidação automática

3. **Sincronização**
   - Webhooks: Tempo real (< 1s)
   - Batch sync: 3h da manhã
   - Apenas deltas (não full)

4. **Queries Otimizadas**
   - Views materializadas para dashboards
   - Paginação em todas listas
   - Limit 100 por padrão

---

## 📊 Monitoramento

### **Métricas Coletadas:**

```yaml
Sistema:
  - Uptime do N8N
  - Latência PostgreSQL
  - Taxa de erro Airtable API
  - Uso de RAM/CPU

Negócio:
  - Documentos processados/dia
  - Taxa de sucesso OCR
  - Tempo médio de aprovação
  - Conciliações automáticas (%)

Sincronização:
  - Divergências detectadas
  - Tempo de sync (P95, P99)
  - Erros de webhook
  - Queue size
```

### **Alertas:**

```
Crítico:
  - PostgreSQL down
  - Divergências > 10
  - Erro de sync > 5 min

Warning:
  - Latência > 3s
  - Queue > 100 itens
  - OCR taxa sucesso < 90%

Info:
  - Sync diário completo
  - Backup criado
  - Vencimentos próximos
```

---

## 🔄 Disaster Recovery

### **Backup Strategy:**

```yaml
PostgreSQL:
  - Full backup: Diário (3h)
  - Incremental: A cada hora
  - Retenção: 30 dias
  - Point-in-time recovery: 7 dias

Airtable:
  - Export JSON: Diário
  - Retenção: 90 dias
  - Armazenamento: Google Drive

N8N Workflows:
  - Export JSON: A cada mudança
  - Versionamento: GitHub
  - Retenção: Ilimitado
```

### **RTO/RPO:**

```
Recovery Time Objective (RTO): 1 hora
Recovery Point Objective (RPO): 15 minutos

Plano de Recuperação:
  1. Restaurar PostgreSQL do backup
  2. Reimportar workflows N8N
  3. Sincronizar full com Airtable
  4. Validar integridade de dados
  5. Testar todos workflows críticos
```

---

## 🚀 Escalabilidade

### **Limites Atuais:**

```yaml
Airtable:
  - Registros: ~50.000 (limite Pro)
  - API calls: 5/segundo
  - Attachments: 20 GB

PostgreSQL (Supabase Pro):
  - Registros: Ilimitado
  - Storage: 8 GB incluído
  - Connections: 60 simultâneas

N8N:
  - Workflows: Ilimitado
  - Execuções: ~10.000/mês (estimate)
```

### **Plano de Crescimento:**

```
Fase 1: 0-10k documentos/ano
  → Setup atual suficiente

Fase 2: 10k-50k documentos/ano
  → Upgrade Supabase ($25 → $99/mês)
  → Considerar Airtable Enterprise

Fase 3: >50k documentos/ano
  → Migrar Airtable → PostgreSQL + Metabase
  → N8N dedicado (VPS maior)
  → Considerar sharding
```

---

## 📚 Stack Completo

```yaml
Infrastructure:
  - Hosting: Hetzner VPS (CPX21)
  - DB: Supabase (PostgreSQL 15)
  - Cache: Upstash Redis
  - Storage: Supabase Storage + Google Drive

Automation:
  - Workflow: N8N (self-hosted)
  - Scheduler: N8N Cron
  - Queue: BullMQ via Redis

AI/ML:
  - LLM: Anthropic Claude 3.5 Sonnet
  - OCR: Google Cloud Vision API
  - Framework: LangChain

Frontend:
  - Interface: Airtable
  - Chat: WhatsApp (Evolution API)
  - Email: Resend.com

Monitoring:
  - Uptime: Uptime Kuma
  - Logs: PostgreSQL + Supabase Logs
  - Metrics: Custom dashboards

DevOps:
  - Version Control: GitHub
  - CI/CD: Manual (export/import N8N)
  - Secrets: Doppler
  - Backup: Supabase + Scripts
```

---

## 🎯 Próximas Evoluções

**Q1 2025:**
- [ ] Conciliação bancária automática (Open Finance)
- [ ] Análises preditivas (ML)
- [ ] Mobile app para aprovações

**Q2 2025:**
- [ ] Dashboard BI (Metabase)
- [ ] Integrações ERP
- [ ] Relatórios fiscais automáticos

**Q3 2025:**
- [ ] Multi-empresa
- [ ] API pública
- [ ] White-label

---

## 📞 Suporte

- **Documentação**: `/docs`
- **Issues**: GitHub Issues
- **Email**: suporte@mottivme.com.br
