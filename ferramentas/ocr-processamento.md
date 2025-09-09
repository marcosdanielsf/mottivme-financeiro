# Ferramentas OCR e Processamento de Imagens - MottivMe Financeiro

Este documento descreve as ferramentas de OCR (Optical Character Recognition) e processamento de imagens utilizadas no sistema financeiro inteligente da MottivMe.

## Visão Geral

O sistema utiliza tecnologias avançadas de OCR para extrair dados automaticamente de documentos financeiros, incluindo faturas, recibos, notas fiscais e comprovantes de pagamento.

## Ferramentas Disponíveis

### 1. OCR Avançado Financeiro

**Descrição**: Ferramenta especializada em extração de dados de documentos financeiros gerais.

**Configuração N8N**:
```json
{
  "name": "OCR Avançado Financeiro",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://api.ocr-service.com/v1/extract",
    "method": "POST",
    "headers": {
      "Authorization": "Bearer {{$env.OCR_API_KEY}}",
      "Content-Type": "application/json"
    },
    "body": {
      "image": "{{$json.image_base64}}",
      "document_type": "financial",
      "language": "pt-BR",
      "extract_fields": [
        "valor_total",
        "data_vencimento",
        "fornecedor",
        "cnpj_cpf",
        "numero_documento"
      ]
    }
  }
}
```

**Campos Extraídos**:
- Valor total do documento
- Data de vencimento
- Nome do fornecedor/cliente
- CNPJ/CPF
- Número do documento
- Data de emissão
- Descrição dos itens

### 2. OCR Especializado Recebimentos

**Descrição**: Ferramenta otimizada para processamento de comprovantes de recebimento e documentos de entrada.

**Configuração N8N**:
```json
{
  "name": "OCR Especializado Recebimentos",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://api.ocr-service.com/v1/extract-receipt",
    "method": "POST",
    "headers": {
      "Authorization": "Bearer {{$env.OCR_API_KEY}}",
      "Content-Type": "application/json"
    },
    "body": {
      "image": "{{$json.image_base64}}",
      "document_type": "receipt",
      "language": "pt-BR",
      "extract_fields": [
        "valor_recebido",
        "data_recebimento",
        "cliente",
        "forma_pagamento",
        "banco_origem"
      ]
    }
  }
}
```

**Campos Extraídos**:
- Valor recebido
- Data do recebimento
- Nome do cliente
- Forma de pagamento (PIX, TED, DOC, etc.)
- Banco de origem
- Número da transação
- Hora do recebimento

### 3. Validador de Qualidade de Imagem

**Descrição**: Valida a qualidade da imagem antes do processamento OCR.

**Configuração N8N**:
```json
{
  "name": "Validador de Qualidade de Imagem",
  "type": "n8n-nodes-base.function",
  "parameters": {
    "functionCode": "// Validação de qualidade de imagem\nconst image = items[0].json.image_base64;\nconst imageSize = Buffer.from(image, 'base64').length;\nconst minSize = 50000; // 50KB mínimo\nconst maxSize = 10000000; // 10MB máximo\n\nif (imageSize < minSize) {\n  return [{\n    json: {\n      valid: false,\n      error: 'Imagem muito pequena - qualidade insuficiente',\n      size: imageSize\n    }\n  }];\n}\n\nif (imageSize > maxSize) {\n  return [{\n    json: {\n      valid: false,\n      error: 'Imagem muito grande - redimensione antes do upload',\n      size: imageSize\n    }\n  }];\n}\n\nreturn [{\n  json: {\n    valid: true,\n    message: 'Imagem válida para processamento',\n    size: imageSize\n  }\n}];"
  }
}
```

## Fluxo de Processamento

### Etapa 1: Validação de Imagem
1. Verificar tamanho do arquivo
2. Validar formato (JPG, PNG, PDF)
3. Verificar resolução mínima
4. Detectar qualidade da imagem

### Etapa 2: Pré-processamento
1. Correção de rotação automática
2. Ajuste de contraste e brilho
3. Remoção de ruídos
4. Normalização de resolução

### Etapa 3: Extração OCR
1. Aplicar OCR específico por tipo de documento
2. Extrair campos estruturados
3. Validar dados extraídos
4. Aplicar correções automáticas

## Configurações Avançadas

### Parâmetros de OCR
```json
{
  "confidence_threshold": 0.85,
  "language": "pt-BR",
  "dpi": 300,
  "preprocessing": {
    "auto_rotate": true,
    "enhance_contrast": true,
    "remove_noise": true
  },
  "postprocessing": {
    "validate_cpf_cnpj": true,
    "format_currency": true,
    "validate_dates": true
  }
}
```

### Tratamento de Erros

**Erros Comuns e Soluções**:
- **Baixa qualidade**: Solicitar nova imagem
- **Texto ilegível**: Aplicar filtros de melhoria
- **Campos não encontrados**: Usar OCR manual assistido
- **Dados inválidos**: Solicitar validação manual

## Métricas de Performance

### KPIs Monitorados
- **Taxa de sucesso**: > 95%
- **Tempo de processamento**: < 30 segundos
- **Precisão de extração**: > 90%
- **Taxa de erro**: < 5%

### Monitoramento N8N
```json
{
  "name": "Monitor OCR Performance",
  "type": "n8n-nodes-base.cron",
  "parameters": {
    "triggerTimes": {
      "hour": 9,
      "minute": 0
    }
  },
  "nextNode": "Coletar Métricas OCR"
}
```

## Exemplo de Workflow N8N

```json
{
  "name": "Processamento OCR Completo",
  "nodes": [
    {
      "name": "Webhook Receber Documento",
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "path": "processo-documento",
        "httpMethod": "POST"
      }
    },
    {
      "name": "Validar Qualidade",
      "type": "n8n-nodes-base.function"
    },
    {
      "name": "OCR Avançado",
      "type": "n8n-nodes-base.httpRequest"
    },
    {
      "name": "Validar Dados Extraídos",
      "type": "n8n-nodes-base.function"
    },
    {
      "name": "Salvar no Google Sheets",
      "type": "n8n-nodes-base.googleSheets"
    },
    {
      "name": "Notificar Gerente",
      "type": "n8n-nodes-base.emailSend"
    }
  ]
}
```

## Segurança e Compliance

### Proteção de Dados
- Criptografia de imagens em trânsito
- Armazenamento temporário seguro
- Exclusão automática após processamento
- Logs de auditoria completos

### Conformidade LGPD
- Consentimento explícito para processamento
- Direito ao esquecimento implementado
- Minimização de dados coletados
- Relatórios de conformidade automáticos
