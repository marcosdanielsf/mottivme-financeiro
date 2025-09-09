# Integração Google Sheets - MottivMe Financeiro

Este documento descreve as ferramentas de integração com Google Sheets utilizadas no sistema financeiro inteligente da MottivMe para organização e controle de dados financeiros.

## Visão Geral

O sistema utiliza Google Sheets como base de dados principal para organizar informações financeiras extraídas automaticamente dos documentos processados, permitindo controle em tempo real e colaboração da equipe.

## Ferramentas Disponíveis

### 1. Integrador Google Sheets Pagar

**Descrição**: Ferramenta especializada em inserir e atualizar dados de contas a pagar na planilha correspondente.

**Configuração N8N**:
```json
{
  "name": "Integrador Google Sheets Pagar",
  "type": "n8n-nodes-base.googleSheets",
  "parameters": {
    "operation": "append",
    "documentId": "{{$env.SHEETS_CONTAS_PAGAR_ID}}",
    "sheetName": "Contas a Pagar",
    "columns": {
      "mappingMode": "defineBelow",
      "values": {
        "Data": "={{$json.data_documento}}",
        "Fornecedor": "={{$json.fornecedor}}",
        "CNPJ": "={{$json.cnpj}}",
        "Valor": "={{$json.valor_total}}",
        "Vencimento": "={{$json.data_vencimento}}",
        "Status": "Pendente",
        "Categoria": "={{$json.categoria}}",
        "Documento": "={{$json.numero_documento}}"
      }
    }
  }
}
```

### 2. Integrador Google Sheets Receber

**Descrição**: Ferramenta especializada em inserir e atualizar dados de contas a receber na planilha correspondente.

**Configuração N8N**:
```json
{
  "name": "Integrador Google Sheets Receber",
  "type": "n8n-nodes-base.googleSheets",
  "parameters": {
    "operation": "append",
    "documentId": "{{$env.SHEETS_CONTAS_RECEBER_ID}}",
    "sheetName": "Contas a Receber",
    "columns": {
      "mappingMode": "defineBelow",
      "values": {
        "Data": "={{$json.data_recebimento}}",
        "Cliente": "={{$json.cliente}}",
        "CPF_CNPJ": "={{$json.cpf_cnpj}}",
        "Valor": "={{$json.valor_recebido}}",
        "Forma_Pagamento": "={{$json.forma_pagamento}}",
        "Banco": "={{$json.banco_origem}}",
        "Status": "Recebido",
        "Transacao": "={{$json.numero_transacao}}"
      }
    }
  }
}
```

### 3. Atualizador de Totais Automático

**Descrição**: Atualiza automaticamente células de totais e resumos nas planilhas.

**Configuração N8N**:
```json
{
  "name": "Atualizador de Totais Automático",
  "type": "n8n-nodes-base.googleSheets",
  "parameters": {
    "operation": "update",
    "documentId": "{{$json.planilha_id}}",
    "sheetName": "Dashboard",
    "range": "B2:B10",
    "values": [
      ["=SUMIF('Contas a Pagar'!G:G,\"Pendente\",'Contas a Pagar'!D:D)"],
      ["=SUMIF('Contas a Pagar'!G:G,\"Pago\",'Contas a Pagar'!D:D)"],
      ["=SUM('Contas a Receber'!D:D)"],
      ["=B3-B2"],
      ["=COUNTIF('Contas a Pagar'!E:E,\"<\"&TODAY())"],
      ["=COUNTIF('Contas a Receber'!H:H,\"Pendente\")"],
      ["=AVERAGE('Contas a Pagar'!D:D)"],
      ["=AVERAGE('Contas a Receber'!D:D)"]
    ]
  }
}
```

### 4. Gerador de Dashboard Financeiro

**Descrição**: Cria e atualiza dashboard com gráficos e métricas financeiras.

**Configuração N8N**:
```json
{
  "name": "Gerador de Dashboard Financeiro",
  "type": "n8n-nodes-base.function",
  "parameters": {
    "functionCode": "// Gerar dados para dashboard\nconst dados = items[0].json;\n\n// Calcular métricas\nconst totalPagar = dados.contas_pagar.reduce((sum, item) => sum + item.valor, 0);\nconst totalReceber = dados.contas_receber.reduce((sum, item) => sum + item.valor, 0);\nconst saldoLiquido = totalReceber - totalPagar;\n\n// Preparar dados para gráficos\nconst dadosDashboard = {\n  metricas: {\n    total_pagar: totalPagar,\n    total_receber: totalReceber,\n    saldo_liquido: saldoLiquido,\n    data_atualizacao: new Date().toISOString()\n  },\n  graficos: {\n    fluxo_mensal: dados.fluxo_mensal,\n    categorias_gastos: dados.categorias_gastos,\n    formas_recebimento: dados.formas_recebimento\n  }\n};\n\nreturn [{ json: dadosDashboard }];"
  }
}
```

## Estrutura das Planilhas

### Planilha Contas a Pagar

**Colunas**:
- A: Data do Documento
- B: Fornecedor
- C: CNPJ
- D: Valor
- E: Data de Vencimento
- F: Dias para Vencimento (=E2-TODAY())
- G: Status (Pendente/Pago/Vencido)
- H: Categoria
- I: Número do Documento
- J: Observações

**Fórmulas Automáticas**:
```excel
// Coluna F - Dias para vencimento
=E2-TODAY()

// Coluna G - Status automático
=IF(F2<0,"Vencido",IF(F2<=7,"Vence em breve","Pendente"))

// Totais na parte inferior
=SUMIF(G:G,"Pendente",D:D)  // Total pendente
=SUMIF(G:G,"Vencido",D:D)   // Total vencido
=COUNTIF(F:F,"<0")          // Quantidade vencidos
```

### Planilha Contas a Receber

**Colunas**:
- A: Data do Recebimento
- B: Cliente
- C: CPF/CNPJ
- D: Valor
- E: Forma de Pagamento
- F: Banco de Origem
- G: Status
- H: Número da Transação
- I: Observações

**Fórmulas Automáticas**:
```excel
// Totais por forma de pagamento
=SUMIF(E:E,"PIX",D:D)      // Total PIX
=SUMIF(E:E,"TED",D:D)      // Total TED
=SUMIF(E:E,"Dinheiro",D:D) // Total Dinheiro

// Métricas mensais
=SUMIFS(D:D,A:A,">="&DATE(YEAR(TODAY()),MONTH(TODAY()),1),A:A,"<"&DATE(YEAR(TODAY()),MONTH(TODAY())+1,1))
```

### Dashboard Principal

**Seções**:
1. **Resumo Financeiro** (B2:C10)
2. **Gráfico Fluxo de Caixa** (E2:J15)
3. **Top Fornecedores** (B12:C20)
4. **Alertas e Vencimentos** (E17:J25)

## Automações Avançadas

### 1. Backup Automático

**Configuração N8N**:
```json
{
  "name": "Backup Diário Planilhas",
  "type": "n8n-nodes-base.cron",
  "parameters": {
    "triggerTimes": {
      "hour": 23,
      "minute": 0
    }
  },
  "nextNode": "Copiar Planilhas"
}
```

### 2. Alertas Automáticos

**Configuração N8N**:
```json
{
  "name": "Monitor Vencimentos",
  "type": "n8n-nodes-base.cron",
  "parameters": {
    "triggerTimes": {
      "hour": 8,
      "minute": 0
    }
  },
  "nextNode": "Verificar Vencimentos Próximos"
}
```

### 3. Sincronização Automática

**Configuração N8N**:
```json
{
  "name": "Sincronizar Dados",
  "type": "n8n-nodes-base.interval",
  "parameters": {
    "interval": 300000  // 5 minutos
  },
  "nextNode": "Atualizar Totais"
}
```

## Permissões e Segurança

### Configuração de Permissões

**Níveis de Acesso**:
- **Administrador**: Edição completa
- **Gerente Financeiro**: Edição de dados e aprovações
- **Assistente**: Visualização e inserção de dados
- **Consulta**: Apenas visualização

### Configuração Google Sheets API

**Credenciais Necessárias**:
```json
{
  "type": "service_account",
  "project_id": "mottivme-financeiro",
  "private_key_id": "{{$env.GOOGLE_PRIVATE_KEY_ID}}",
  "private_key": "{{$env.GOOGLE_PRIVATE_KEY}}",
  "client_email": "{{$env.GOOGLE_CLIENT_EMAIL}}",
  "client_id": "{{$env.GOOGLE_CLIENT_ID}}",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token"
}
```

**Escopos Necessários**:
- `https://www.googleapis.com/auth/spreadsheets`
- `https://www.googleapis.com/auth/drive.file`

## Monitoramento e Métricas

### KPIs Monitorados
- **Taxa de sincronização**: > 99%
- **Tempo de resposta**: < 5 segundos
- **Precisão de dados**: > 99%
- **Disponibilidade**: > 99.9%

### Alertas Configurados
- Falhas de sincronização
- Vencimentos próximos (7 dias)
- Valores suspeitos (> R$ 10.000)
- Duplicatas detectadas
- Erros de validação

## Exemplo de Workflow Completo

```json
{
  "name": "Processamento Completo Financeiro",
  "nodes": [
    {
      "name": "Trigger Documento",
      "type": "n8n-nodes-base.webhook"
    },
    {
      "name": "OCR Documento",
      "type": "n8n-nodes-base.httpRequest"
    },
    {
      "name": "Validar Dados",
      "type": "n8n-nodes-base.function"
    },
    {
      "name": "Inserir Google Sheets",
      "type": "n8n-nodes-base.googleSheets"
    },
    {
      "name": "Atualizar Dashboard",
      "type": "n8n-nodes-base.googleSheets"
    },
    {
      "name": "Enviar Notificação",
      "type": "n8n-nodes-base.emailSend"
    }
  ]
}
```
