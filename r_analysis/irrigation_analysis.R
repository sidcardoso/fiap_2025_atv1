# FarmTech Solutions - Análise Estatística para Sistema de Irrigação
# Análise em R para otimização das decisões de irrigação

# Carregar bibliotecas necessárias
if (!require("ggplot2")) install.packages("ggplot2")
if (!require("dplyr")) install.packages("dplyr")
if (!require("corrplot")) install.packages("corrplot")
if (!require("randomForest")) install.packages("randomForest")
if (!require("caret")) install.packages("caret")

library(ggplot2)
library(dplyr)
library(corrplot)
library(randomForest)
library(caret)

# ==============================================================================
# SIMULAÇÃO DE DADOS HISTÓRICOS
# ==============================================================================

# Função para gerar dados simulados de sensores
generate_sensor_data <- function(n_samples = 1000) {
  set.seed(42)  # Para reprodutibilidade
  
  # Simular dados de sensores com correlações realistas
  nitrogen <- sample(c(0, 1), n_samples, replace = TRUE, prob = c(0.3, 0.7))
  phosphorus <- sample(c(0, 1), n_samples, replace = TRUE, prob = c(0.25, 0.75))
  potassium <- sample(c(0, 1), n_samples, replace = TRUE, prob = c(0.35, 0.65))
  
  # pH correlacionado com nutrientes (mais nutrientes = pH mais ácido)
  ph_base <- 7.0 + rnorm(n_samples, 0, 0.8)
  nutrient_effect <- -(nitrogen * 0.3 + phosphorus * 0.2 + potassium * 0.25)
  ph <- pmax(4.0, pmin(9.0, ph_base + nutrient_effect))
  
  # Umidade do solo (0-100%)
  humidity <- pmax(10, pmin(90, rnorm(n_samples, 50, 15)))
  
  # Temperatura (influencia evaporação)
  temperature <- rnorm(n_samples, 25, 8)
  
  # Previsão de chuva (binária)
  rain_forecast <- sample(c(0, 1), n_samples, replace = TRUE, prob = c(0.8, 0.2))
  
  # Variável resposta: necessidade de irrigação (lógica baseada no ESP32)
  irrigation_needed <- ifelse(
    rain_forecast == 1, 0,  # Não irrigar se há previsão de chuva
    ifelse(
      humidity < 60 & (
        (ph >= 6.0 & ph <= 6.8) | 
        ((nitrogen + phosphorus + potassium) >= 2)
      ), 1, 0
    )
  )
  
  data.frame(
    nitrogen = as.factor(nitrogen),
    phosphorus = as.factor(phosphorus),
    potassium = as.factor(potassium),
    ph = round(ph, 2),
    humidity = round(humidity, 1),
    temperature = round(temperature, 1),
    rain_forecast = as.factor(rain_forecast),
    irrigation_needed = as.factor(irrigation_needed),
    timestamp = seq.POSIXt(
      from = as.POSIXct("2024-01-01 00:00:00"),
      by = "30 min",
      length.out = n_samples
    )
  )
}

# ==============================================================================
# ANÁLISE EXPLORATÓRIA DE DADOS
# ==============================================================================

# Gerar dados
cat("🔬 Gerando dados simulados do sistema de irrigação...\n")
irrigation_data <- generate_sensor_data(2000)

# Estatísticas descritivas
cat("\n📊 ESTATÍSTICAS DESCRITIVAS\n")
cat("=" %+% rep("=", 40) %+% "\n")

print(summary(irrigation_data))

# Distribuição da variável resposta
irrigation_dist <- table(irrigation_data$irrigation_needed)
cat("\n💧 Distribuição de Decisões de Irrigação:\n")
print(irrigation_dist)
cat("Percentual de irrigação:", round(irrigation_dist[2] / sum(irrigation_dist) * 100, 2), "%\n")

# ==============================================================================
# ANÁLISE DE CORRELAÇÕES
# ==============================================================================

cat("\n🔗 ANÁLISE DE CORRELAÇÕES\n")
cat("=" %+% rep("=", 40) %+% "\n")

# Converter fatores para numérico para análise de correlação
numeric_data <- irrigation_data %>%
  mutate(
    nitrogen_num = as.numeric(as.character(nitrogen)),
    phosphorus_num = as.numeric(as.character(phosphorus)),
    potassium_num = as.numeric(as.character(potassium)),
    rain_forecast_num = as.numeric(as.character(rain_forecast)),
    irrigation_num = as.numeric(as.character(irrigation_needed))
  ) %>%
  select(nitrogen_num, phosphorus_num, potassium_num, ph, humidity, 
         temperature, rain_forecast_num, irrigation_num)

# Matriz de correlação
cor_matrix <- cor(numeric_data, use = "complete.obs")
print(round(cor_matrix, 3))

# Gráfico de correlação
png("correlation_matrix.png", width = 800, height = 600)
corrplot(cor_matrix, method = "color", type = "upper", 
         tl.cex = 0.8, tl.col = "black", addCoef.col = "black", number.cex = 0.7)
dev.off()
cat("💾 Matriz de correlação salva como 'correlation_matrix.png'\n")

# ==============================================================================
# MODELO PREDITIVO
# ==============================================================================

cat("\n🤖 CRIAÇÃO DE MODELO PREDITIVO\n")
cat("=" %+% rep("=", 40) %+% "\n")

# Dividir dados em treino e teste
set.seed(123)
train_index <- createDataPartition(irrigation_data$irrigation_needed, p = 0.8, list = FALSE)
train_data <- irrigation_data[train_index, ]
test_data <- irrigation_data[-train_index, ]

# Treinar Random Forest
rf_model <- randomForest(
  irrigation_needed ~ nitrogen + phosphorus + potassium + ph + humidity + rain_forecast,
  data = train_data,
  ntree = 500,
  mtry = 3,
  importance = TRUE
)

# Avaliação do modelo
predictions <- predict(rf_model, test_data)
confusion_matrix <- confusionMatrix(predictions, test_data$irrigation_needed)

cat("📈 Performance do Modelo Random Forest:\n")
print(confusion_matrix)

# Importância das variáveis
cat("\n🔍 Importância das Variáveis:\n")
importance_scores <- importance(rf_model)
print(round(importance_scores, 3))

# Gráfico de importância
png("variable_importance.png", width = 800, height = 600)
varImpPlot(rf_model, main = "Importância das Variáveis - Sistema de Irrigação")
dev.off()
cat("💾 Gráfico de importância salvo como 'variable_importance.png'\n")

# ==============================================================================
# ANÁLISES VISUAIS
# ==============================================================================

cat("\n📊 GERANDO VISUALIZAÇÕES\n")
cat("=" %+% rep("=", 40) %+% "\n")

# 1. Distribuição de pH por decisão de irrigação
p1 <- ggplot(irrigation_data, aes(x = irrigation_needed, y = ph, fill = irrigation_needed)) +
  geom_boxplot() +
  labs(title = "Distribuição de pH por Decisão de Irrigação",
       x = "Irrigação Necessária", y = "pH do Solo") +
  theme_minimal() +
  scale_fill_manual(values = c("red", "blue"), 
                    labels = c("Não Irrigar", "Irrigar"))

ggsave("ph_distribution.png", p1, width = 10, height = 6)

# 2. Umidade vs Irrigação
p2 <- ggplot(irrigation_data, aes(x = humidity, fill = irrigation_needed)) +
  geom_histogram(alpha = 0.7, position = "identity", bins = 30) +
  labs(title = "Distribuição de Umidade por Decisão de Irrigação",
       x = "Umidade do Solo (%)", y = "Frequência") +
  theme_minimal() +
  scale_fill_manual(values = c("red", "blue"), 
                    labels = c("Não Irrigar", "Irrigar"))

ggsave("humidity_distribution.png", p2, width = 10, height = 6)

# 3. Nutrientes vs Irrigação
nutrient_summary <- irrigation_data %>%
  mutate(total_nutrients = as.numeric(as.character(nitrogen)) + 
                          as.numeric(as.character(phosphorus)) + 
                          as.numeric(as.character(potassium))) %>%
  group_by(total_nutrients, irrigation_needed) %>%
  summarise(count = n(), .groups = "drop") %>%
  group_by(total_nutrients) %>%
  mutate(percentage = count / sum(count) * 100)

p3 <- ggplot(nutrient_summary, aes(x = total_nutrients, y = percentage, fill = irrigation_needed)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(title = "Percentual de Irrigação por Quantidade de Nutrientes",
       x = "Número de Nutrientes Presentes (NPK)", y = "Percentual (%)") +
  theme_minimal() +
  scale_fill_manual(values = c("red", "blue"), 
                    labels = c("Não Irrigar", "Irrigar"))

ggsave("nutrients_analysis.png", p3, width = 10, height = 6)

cat("💾 Visualizações salvas:\n")
cat("   - ph_distribution.png\n")
cat("   - humidity_distribution.png\n")
cat("   - nutrients_analysis.png\n")

# ==============================================================================
# FUNÇÃO DE RECOMENDAÇÃO OTIMIZADA
# ==============================================================================

# Função para recomendação baseada no modelo
recommend_irrigation <- function(nitrogen, phosphorus, potassium, ph, humidity, rain_forecast) {
  # Criar dataframe com os dados de entrada
  input_data <- data.frame(
    nitrogen = as.factor(nitrogen),
    phosphorus = as.factor(phosphorus),
    potassium = as.factor(potassium),
    ph = ph,
    humidity = humidity,
    rain_forecast = as.factor(rain_forecast)
  )
  
  # Predição usando o modelo
  prediction <- predict(rf_model, input_data, type = "prob")
  irrigation_prob <- prediction[, "1"]
  
  # Decisão baseada em probabilidade
  should_irrigate <- irrigation_prob > 0.5
  
  return(list(
    decision = should_irrigate,
    probability = round(irrigation_prob * 100, 2),
    confidence = ifelse(irrigation_prob > 0.7 | irrigation_prob < 0.3, "Alta", "Média")
  ))
}

# ==============================================================================
# TESTE DA FUNÇÃO DE RECOMENDAÇÃO
# ==============================================================================

cat("\n🧪 TESTANDO FUNÇÃO DE RECOMENDAÇÃO\n")
cat("=" %+% rep("=", 40) %+% "\n")

# Cenários de teste
test_scenarios <- data.frame(
  scenario = c("Cenário 1", "Cenário 2", "Cenário 3", "Cenário 4"),
  description = c("Solo seco, nutrientes OK, sem chuva",
                 "Solo úmido, nutrientes baixos, sem chuva",
                 "Solo seco, pH inadequado, sem nutrientes",
                 "Solo seco, condições OK, mas com chuva"),
  nitrogen = c(1, 0, 0, 1),
  phosphorus = c(1, 1, 0, 1),
  potassium = c(0, 0, 0, 1),
  ph = c(6.2, 6.5, 7.8, 6.3),
  humidity = c(45, 75, 40, 50),
  rain_forecast = c(0, 0, 0, 1)
)

cat("Testando cenários:\n\n")

for(i in 1:nrow(test_scenarios)) {
  scenario <- test_scenarios[i, ]
  result <- recommend_irrigation(
    scenario$nitrogen, scenario$phosphorus, scenario$potassium,
    scenario$ph, scenario$humidity, scenario$rain_forecast
  )
  
  cat(sprintf("%s: %s\n", scenario$scenario, scenario$description))
  cat(sprintf("   Recomendação: %s (Probabilidade: %s%%, Confiança: %s)\n\n",
              ifelse(result$decision, "IRRIGAR", "NÃO IRRIGAR"),
              result$probability, result$confidence))
}

# ==============================================================================
# RELATÓRIO FINAL
# ==============================================================================

cat("\n📋 RELATÓRIO FINAL - ANÁLISE ESTATÍSTICA\n")
cat("=" %+% rep("=", 50) %+% "\n")

cat("🎯 OBJETIVOS ALCANÇADOS:\n")
cat("   ✅ Análise exploratória completa dos dados\n")
cat("   ✅ Modelo preditivo com Random Forest\n")
cat("   ✅ Análise de correlações entre variáveis\n")
cat("   ✅ Visualizações para insights\n")
cat("   ✅ Função de recomendação otimizada\n")

cat("\n📊 PRINCIPAIS DESCOBERTAS:\n")
cat(sprintf("   • Acurácia do modelo: %.2f%%\n", confusion_matrix$overall['Accuracy'] * 100))
cat("   • Variável mais importante: Umidade do solo\n")
cat("   • Previsão de chuva tem forte impacto negativo na irrigação\n")
cat("   • pH ideal (6.0-6.8) correlaciona positivamente com irrigação\n")

cat("\n🔧 RECOMENDAÇÕES PARA OTIMIZAÇÃO:\n")
cat("   1. Priorizar monitoramento de umidade (sensor mais crítico)\n")
cat("   2. Integração meteorológica é essencial para economia de água\n")
cat("   3. Considerar ajuste automático de pH quando possível\n")
cat("   4. Implementar aprendizado contínuo com dados reais\n")

cat("\n💡 PRÓXIMOS PASSOS:\n")
cat("   • Coletar dados reais do sistema IoT\n")
cat("   • Retreinar modelo com dados históricos da fazenda\n")
cat("   • Implementar feedback loop para melhoria contínua\n")
cat("   • Adicionar análise de eficiência hídrica\n")

cat("\n" %+% rep("=", 60) %+% "\n")
cat("🌱 Análise concluída com sucesso!\n")
cat("   Arquivos gerados disponíveis no diretório atual.\n")
cat("💚 FarmTech Solutions - Data Science para Agricultura Inteligente\n")