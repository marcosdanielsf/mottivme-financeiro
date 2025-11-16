# 📊 Estrutura do Airtable - Luna Financeiro

## Visão Geral

O Airtable serve como **interface visual amigável** para a equipe, enquanto o PostgreSQL é a **fonte da verdade**. A sincronização é bidirecional e automática via N8N.

---

## 🗂️ BASE: Luna Financeiro

### **Tabela 1: 💰 Documentos Financeiros**

**Campos:**

| Campo | Tipo | Descrição | Sincronizado |
|-------|------|-----------|--------------|
| **ID PostgreSQL** | Single line text | UUID do PostgreSQL | ✅ Read-only |
| **Tipo** | Single select | Contas a Pagar / Contas a Receber | ✅ |
| **Status** | Single select | Pendente / Aprovado / Pago / Vencido / etc | ✅ |
| **Nº Documento** | Single line text | Número do documento | ✅ |
| **Nº NF** | Single line text | Número da nota fiscal | ✅ |
| **Data Emissão** | Date | Data de emissão | ✅ |
| **Data Vencimento** | Date | Data de vencimento | ✅ |
| **Data Pagamento** | Date | Data do pagamento efetivo | ✅ |
| **Valor Bruto** | Currency (R$) | Valor original | ✅ |
| **Desconto** | Currency (R$) | Valor de desconto | ✅ |
| **Juros** | Currency (R$) | Juros aplicados | ✅ |
| **Multa** | Currency (R$) | Multa aplicada | ✅ |
| **Valor Líquido** | Formula | `{Valor Bruto} - {Desconto} + {Juros} + {Multa}` | ✅ Auto-calc |
| **Fornecedor/Cliente** | Link to "Entidades" | Relacionamento | ✅ |
| **Categoria** | Link to "Categorias" | Relacionamento | ✅ |
| **Centro de Custo** | Link to "Centros de Custo" | Relacionamento | ✅ |
| **Descrição** | Long text | Descrição detalhada | ✅ |
| **Observações** | Long text | Notas adicionais | ✅ |
| **Forma Pagamento** | Single select | PIX / TED / Boleto / etc | ✅ |
| **Arquivo** | Attachment | PDF/imagem do documento | ✅ |
| **Conciliado** | Checkbox | Conciliado com banco? | ✅ |
| **Aprovado Por** | Single line text | Quem aprovou | ✅ |
| **Criado em** | Created time | Auto | ✅ Read-only |
| **Atualizado em** | Last modified time | Auto | ✅ Read-only |
| **Dias para Vencimento** | Formula | `DATETIME_DIFF({Data Vencimento}, TODAY(), 'days')` | Auto-calc |
| **Alerta Vencimento** | Formula | Cores condicionais | Auto-calc |

**Opções de Status:**
- 🟡 Pendente
- 🔵 Aprovado
- 🟢 Pago / Recebido
- 🔴 Vencido
- ⚫ Cancelado
- 🟣 Rejeitado

**Views (Visões):**

1. **📋 Todos os Documentos** (Grid)
   - Todos os registros

2. **⏰ Vencendo Esta Semana** (Grid)
   - Filtro: Status = Pendente ou Aprovado
   - Filtro: Data Vencimento entre Hoje e +7 dias
   - Ordenar: Data Vencimento (crescente)

3. **🚨 Vencidos** (Kanban por Status)
   - Filtro: Status = Vencido
   - Cor vermelha

4. **💳 Contas a Pagar** (Grid)
   - Filtro: Tipo = Contas a Pagar
   - Agrupado por: Status

5. **💰 Contas a Receber** (Grid)
   - Filtro: Tipo = Contas a Receber
   - Agrupado por: Status

6. **📊 Resumo Mensal** (Calendar)
   - Por Data Vencimento
   - Cores por Tipo

7. **✅ Aguardando Aprovação** (Grid)
   - Filtro: Status = Pendente
   - Filtro: Valor Líquido > 1000
   - Ordenar: Valor Líquido (decrescente)

8. **📈 Dashboard** (Grid com totalizadores)
   - Mostrar totais por tipo
   - Gráficos de barra

---

### **Tabela 2: 👥 Entidades (Fornecedores/Clientes)**

**Campos:**

| Campo | Tipo | Descrição | Sincronizado |
|-------|------|-----------|--------------|
| **ID PostgreSQL** | Single line text | UUID do PostgreSQL | ✅ Read-only |
| **Tipo** | Single select | Fornecedor / Cliente | ✅ |
| **Nome** | Single line text | Nome completo | ✅ |
| **Nome Fantasia** | Single line text | Nome fantasia | ✅ |
| **CNPJ/CPF** | Single line text | Com máscara | ✅ |
| **Email** | Email | Email principal | ✅ |
| **Telefone** | Phone | Telefone | ✅ |
| **WhatsApp** | Phone | WhatsApp | ✅ |
| **Endereço Completo** | Long text | Endereço | ✅ |
| **Dados Bancários** | Long text | Banco, agência, conta | ✅ |
| **Chave PIX** | Single line text | Chave PIX | ✅ |
| **Score** | Number | 0-100 (avaliação) | ✅ |
| **Ativo** | Checkbox | Ativo no sistema | ✅ |
| **Observações** | Long text | Notas | ✅ |
| **Documentos** | Link to "Documentos" | Relacionamento reverso | Auto |
| **Total Transacionado** | Rollup | Soma dos documentos | Auto-calc |
| **Última Transação** | Rollup | MAX(data) dos documentos | Auto-calc |

**Views:**

1. **📋 Todos** (Grid)
2. **🏢 Fornecedores Ativos** (filtro: Tipo=Fornecedor, Ativo=true)
3. **👤 Clientes Ativos** (filtro: Tipo=Cliente, Ativo=true)
4. **⭐ Top Fornecedores** (ordenado por Total Transacionado)
5. **⭐ Top Clientes** (ordenado por Total Transacionado)

---

### **Tabela 3: 🏷️ Categorias**

**Campos:**

| Campo | Tipo | Descrição | Sincronizado |
|-------|------|-----------|--------------|
| **ID PostgreSQL** | Single line text | UUID | ✅ Read-only |
| **Nome** | Single line text | Nome da categoria | ✅ |
| **Descrição** | Long text | Descrição | ✅ |
| **Tipo** | Single select | Pagar / Receber | ✅ |
| **Cor** | Single line text | Hex color | ✅ |
| **Ícone** | Single line text | Emoji ou nome ícone | ✅ |
| **Orçamento Mensal** | Currency | Budget mensal | ✅ |
| **Documentos** | Link to "Documentos" | Relacionamento reverso | Auto |
| **Total Gasto/Receita** | Rollup | Soma dos documentos | Auto-calc |

**Views:**

1. **📋 Todas** (Grid)
2. **💸 Despesas** (filtro: Tipo=Pagar)
3. **💰 Receitas** (filtro: Tipo=Receber)
4. **📊 Budget vs Real** (com barra de progresso)

---

### **Tabela 4: 🎯 Centros de Custo**

**Campos:**

| Campo | Tipo | Descrição | Sincronizado |
|-------|------|-----------|--------------|
| **ID PostgreSQL** | Single line text | UUID | ✅ Read-only |
| **Código** | Single line text | Código único | ✅ |
| **Nome** | Single line text | Nome | ✅ |
| **Descrição** | Long text | Descrição | ✅ |
| **Departamento** | Single select | Departamento | ✅ |
| **Responsável** | Single line text | Nome do responsável | ✅ |
| **Orçamento Mensal** | Currency | Budget | ✅ |
| **Ativo** | Checkbox | Ativo | ✅ |
| **Documentos** | Link to "Documentos" | Relacionamento reverso | Auto |
| **Total Alocado** | Rollup | Soma dos documentos | Auto-calc |

**Views:**

1. **📋 Todos** (Grid)
2. **✅ Ativos** (filtro: Ativo=true)
3. **📊 Por Departamento** (agrupado por Departamento)

---

### **Tabela 5: 🔔 Alertas**

**Campos:**

| Campo | Tipo | Descrição | Sincronizado |
|-------|------|-----------|--------------|
| **ID PostgreSQL** | Single line text | UUID | ✅ Read-only |
| **Documento** | Link to "Documentos" | Documento relacionado | ✅ |
| **Tipo** | Single select | Vencimento / Anomalia / etc | ✅ |
| **Severidade** | Single select | Info / Warning / Critical | ✅ |
| **Título** | Single line text | Título do alerta | ✅ |
| **Mensagem** | Long text | Mensagem completa | ✅ |
| **Destinatário Email** | Email | Email | ✅ |
| **Enviado** | Checkbox | Foi enviado? | ✅ |
| **Lido** | Checkbox | Foi lido? | ✅ |
| **Data Criação** | Date | Data | ✅ |

**Views:**

1. **🚨 Não Lidos** (filtro: Lido=false)
2. **❗ Críticos** (filtro: Severidade=Critical)
3. **📋 Todos** (Grid)

---

### **Tabela 6: 🏦 Conciliação Bancária**

**Campos:**

| Campo | Tipo | Descrição | Sincronizado |
|-------|------|-----------|--------------|
| **ID PostgreSQL** | Single line text | UUID | ✅ Read-only |
| **Data Transação** | Date | Data | ✅ |
| **Descrição Banco** | Long text | Descrição do extrato | ✅ |
| **Valor** | Currency | Valor | ✅ |
| **Tipo** | Single select | Débito / Crédito | ✅ |
| **Banco** | Single line text | Nome do banco | ✅ |
| **Documento** | Link to "Documentos" | Match encontrado | ✅ |
| **Match Automático** | Checkbox | Feito automaticamente? | ✅ |
| **Confiança Match** | Percent | 0-100% | ✅ |
| **Conciliado** | Checkbox | Conciliado? | ✅ |
| **Conciliado Por** | Single line text | Usuário | ✅ |

**Views:**

1. **⏳ Pendentes** (filtro: Conciliado=false)
2. **✅ Conciliados** (filtro: Conciliado=true)
3. **🤖 Match Automático** (filtro: Match Automático=true)

---

## 🎨 Automações do Airtable

### **Automação 1: Alerta de Vencimento**
```
Trigger: Diariamente às 8h
Condição: Data Vencimento = Hoje + 3 dias E Status = Pendente
Ação: Enviar email para responsável
```

### **Automação 2: Webhook para N8N (Sincronização)**
```
Trigger: Quando registro é criado ou atualizado
Ação: Webhook POST para N8N
  URL: https://n8n.seudominio.com/webhook/airtable-sync
  Payload: {record_id, fields}
```

### **Automação 3: Marcar como Vencido**
```
Trigger: Diariamente às 0h
Condição: Data Vencimento < Hoje E Status = Pendente
Ação: Atualizar campo Status = Vencido
```

---

## 🔄 Sincronização com PostgreSQL

### **Fluxo de Dados:**

```
┌─────────────────┐           ┌─────────────────┐
│   POSTGRESQL    │◄─────────►│    AIRTABLE     │
│ (Source Truth)  │  N8N Sync │  (Interface)    │
└─────────────────┘           └─────────────────┘
```

**PostgreSQL → Airtable:**
- Trigger: PostgreSQL webhook (INSERT/UPDATE)
- Frequência: Tempo real
- Ação: Cria ou atualiza no Airtable

**Airtable → PostgreSQL:**
- Trigger: Airtable webhook (mudança manual)
- Frequência: Tempo real
- Ação: Valida e atualiza PostgreSQL

**Sincronização Full:**
- Schedule: Diariamente às 3h da manhã
- Compara ambos sistemas
- Corrige inconsistências

---

## 📝 Permissões Airtable

### **Roles:**

1. **Admin**
   - Acesso completo
   - Pode editar estrutura

2. **Financeiro**
   - Editar todos registros
   - Não pode alterar estrutura

3. **Visualizador**
   - Apenas visualizar
   - Pode comentar

4. **Aprovador**
   - Editar Status e Aprovações
   - Ver todos os dados

---

## 🚀 Próximos Passos

1. Criar a base no Airtable usando esta estrutura
2. Configurar as views
3. Configurar automações Airtable
4. Configurar webhooks
5. Implementar workflow N8N de sincronização
6. Testar sincronização bidirecional
7. Migrar dados existentes
8. Treinar equipe

---

## 📌 Notas Importantes

- **NUNCA deletar** o campo "ID PostgreSQL" - é a chave de sincronização
- Mudanças na estrutura devem ser feitas em AMBOS os sistemas
- Campos calculados (Rollup, Formula) são APENAS no Airtable
- PostgreSQL é sempre a fonte da verdade em caso de conflito
- Backup diário automático do PostgreSQL
