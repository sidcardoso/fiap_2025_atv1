# Manual do Usuário - Sistema de Irrigação FarmTech Solutions

## 🚀 Guia de Início Rápido

### Pré-requisitos

- Conta no [Wokwi.com](https://wokwi.com) (gratuita)
- Navegador web moderno
- Conhecimentos básicos de Arduino/ESP32

### Primeiros Passos

1. **Acesse o Wokwi**: Abra [wokwi.com](https://wokwi.com) no navegador
2. **Crie projeto**: "New Project" → "ESP32"
3. **Monte o circuito**: Siga o diagrama em `circuit_diagram.md`
4. **Cole o código**: Copie `irrigation_system.ino` para o editor
5. **Execute**: Clique no botão "Play" ▶️

---

## 🎮 Como Usar o Sistema

### Interface Principal: Monitor Serial

Abra o **Monitor Serial** (ícone 💬) com as configurações:
- **Baud Rate**: 115200
- **Line Ending**: Newline

### Interpretando os Dados

O sistema exibe informações em formato tabular:

```
Tempo   N   P   K   pH    Umidade(%)   Irrigação   Status
---------------------------------------------------------------
15      OK  --  OK  6.2   45.0         LIGADA     [IRRIGANDO - Condições favoráveis]
17      OK  OK  OK  6.5   65.0         DESL.      [Umidade adequada]
```

**Legenda:**
- **Tempo**: Segundos desde o início
- **N/P/K**: Status dos nutrientes (OK = presente, -- = ausente)
- **pH**: Valor atual do pH do solo (0-14)
- **Umidade**: Percentual de umidade do solo
- **Irrigação**: Status da bomba (LIGADA/DESL.)
- **Status**: Explicação da decisão tomada

---

## 🎛️ Controles Disponíveis

### Botões Físicos (Sensores NPK)

| Botão | Função | Como Usar |
|-------|--------|-----------|
| **Botão N** | Nitrogênio | Clique para simular presença de nitrogênio |
| **Botão P** | Fósforo | Clique para simular presença de fósforo |
| **Botão K** | Potássio | Clique para simular presença de potássio |

### Sensor LDR (pH do Solo)

- **Como ajustar**: Clique no LDR e arraste o slider
- **Valores baixos** (escuro): pH ácido (< 6.0)
- **Valores médios**: pH ideal (6.0-6.8)  
- **Valores altos** (claro): pH alcalino (> 7.0)

### Comandos via Serial

Digite comandos no campo de entrada do Monitor Serial:

| Comando | Função | Exemplo |
|---------|--------|---------|
| `RAIN:1` | Ativar previsão de chuva | `RAIN:1` + Enter |
| `RAIN:0` | Remover previsão de chuva | `RAIN:0` + Enter |

---

## 🌱 Cenários de Uso Prático

### Cenário 1: Cultivo de Tomate (Configuração Padrão)

**Condições ideais para irrigação:**
- Umidade do solo < 60%
- pH entre 6.0 - 6.8
- Pelo menos 2 nutrientes (NPK) presentes
- Sem previsão de chuva

**Como testar:**
1. Pressione botões N e P (2 nutrientes)
2. Ajuste LDR para pH ~6.5
3. Aguarde DHT22 mostrar umidade < 60%
4. ✅ Sistema deve iniciar irrigação

### Cenário 2: Economia de Água (Previsão de Chuva)

**Como simular:**
1. Configure condições favoráveis (Cenário 1)
2. Digite `RAIN:1` no Monitor Serial
3. ✅ Sistema suspende irrigação automaticamente
4. Digite `RAIN:0` para retomar funcionamento normal

### Cenário 3: Solo com pH Inadequado

**Como testar:**
1. Ajuste LDR para pH alto (> 7.5) - muita luz
2. Pressione apenas 1 botão NPK
3. Umidade < 60%
4. ✅ Sistema NÃO deve irrigar (condições inadequadas)

### Cenário 4: Solo Saturado

**Como testar:**
1. Aguarde ou simule umidade > 80% no DHT22
2. Configure nutrientes e pH ideais
3. ✅ Sistema NÃO irriga (solo já úmido)

---

## 📊 Interpretando Decisões do Sistema

### Mensagens de Status

| Mensagem | Significado | Ação Recomendada |
|----------|-------------|-------------------|
| `[IRRIGANDO - Condições favoráveis]` | ✅ Irrigação ativa | Monitorar consumo de água |
| `[Umidade adequada]` | ℹ️ Solo suficientemente úmido | Aguardar próxima verificação |
| `[CHUVA PREVISTA - Irrigação suspensa]` | 🌧️ Economia por previsão | Aguardar fim da chuva |
| `[pH ou nutrientes inadequados]` | ⚠️ Condições desfavoráveis | Verificar fertilização |
| `[Umidade alta - Não precisa irrigar]` | 💧 Solo saturado | Verificar drenagem |

### Indicadores Visuais

- **LED Ligado** 🟢: Bomba de irrigação ativa
- **LED Desligado** 🔴: Sistema em standby
- **Relé Clicando**: Som indica ativação/desativação

---

## 🔧 Solução de Problemas

### Problemas Comuns

#### DHT22 mostra valores inválidos (nan)
**Sintoma**: Umidade aparece como "nan" no monitor
**Solução**: 
- Aguarde 2-3 segundos após inicialização
- Verifique conexão do pino DATA (GPIO 15)
- Reinicie a simulação se necessário

#### Botões não respondem
**Sintoma**: Status NPK não muda ao clicar
**Solução**:
- Verifique conexões dos botões no Wokwi
- Confirme que GND está conectado
- Teste clicando firmemente nos botões

#### LDR não varia o pH
**Sintoma**: pH permanece constante
**Solução**:
- Clique no componente LDR
- Arraste o slider de luz
- Verifique resistor pull-down (10kΩ)

#### Sistema não irriga nunca
**Sintoma**: Bomba nunca liga
**Solução**:
- Verifique se umidade < 60%
- Configure pelo menos 2 nutrientes OU pH adequado
- Confirme que não há previsão de chuva ativa

#### Monitor Serial não mostra dados
**Sintoma**: Tela em branco
**Solução**:
- Confirme baud rate 115200
- Abra Monitor Serial (ícone 💬)
- Reinicie simulação se necessário

---

## 🎯 Dicas de Uso Avançado

### Simulação Realística

1. **Variar condições**: Alterne entre cenários diferentes
2. **Observar tendências**: Acompanhe como umidade afeta decisões
3. **Testar limites**: Encontre bordas do algoritmo de decisão
4. **Cronometrar**: Observe intervalos de leitura (2 segundos)

### Integração com Python (Opcional)

Se disponível, use o sistema meteorológico:

1. Execute `python_weather/weather_integration.py`
2. Configure API key da OpenWeatherMap
3. Ajuste porta serial no código Python
4. Sistema enviará dados de chuva automaticamente

### Análise Estatística (Opcional)

Para insights avançados:

1. Execute `r_analysis/irrigation_analysis.R` no RStudio
2. Analise gráficos gerados
3. Use modelos preditivos para otimização
4. Aplique insights no sistema real

---

## 📈 Monitoramento de Performance

### Métricas Importantes

- **Taxa de irrigação**: % de tempo irrigando
- **Economia de água**: Irrigações evitadas por chuva
- **Precisão**: Decisões corretas vs incorretas
- **Eficiência**: Resposta rápida a mudanças

### Log de Atividades

O sistema registra automaticamente:
- Timestamp de cada decisão
- Estado de todos os sensores
- Justificativa das decisões
- Ativações/desativações da bomba

---

## 🆘 Suporte Técnico

### Recursos de Ajuda

1. **Documentação completa**: Pasta `docs/`
2. **Código comentado**: Arquivo `irrigation_system.ino`
3. **Exemplos práticos**: Este manual
4. **Comunidade Wokwi**: Fórum oficial

### Reportar Problemas

Se encontrar bugs ou comportamentos inesperados:

1. Anote o cenário exato que causou o problema
2. Copie as mensagens do Monitor Serial
3. Descreva o comportamento esperado vs observado
4. Inclua screenshots se relevante

---

## 📚 Recursos Adicionais

### Links Úteis

- **Wokwi Docs**: https://docs.wokwi.com/
- **ESP32 Reference**: https://docs.espressif.com/
- **DHT Library**: Documentação da biblioteca DHT
- **OpenWeatherMap API**: https://openweathermap.org/api

### Próximos Passos

Após dominar o sistema básico:

1. **Customize**: Ajuste parâmetros para outras culturas
2. **Expanda**: Adicione novos sensores
3. **Integre**: Conecte com sistemas externos
4. **Otimize**: Use análises para melhorar eficiência

---

*Manual desenvolvido pela equipe FarmTech Solutions*
*Versão 1.0 - Outubro 2024*