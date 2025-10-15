/*
 * FarmTech Solutions - Sistema de Irrigação Inteligente
 * Projeto: Fase 2 - Dispositivo IoT para Agricultura Digital
 * 
 * Descrição: Sistema automatizado que monitora:
 * - Nutrientes NPK (simulados por botões)
 * - pH do solo (simulado por sensor LDR)
 * - Umidade do solo (sensor DHT22)
 * - Controla irrigação via relé
 * 
 * Componentes:
 * - 3 Botões (N, P, K)
 * - 1 Sensor LDR (pH)
 * - 1 Sensor DHT22 (Umidade)
 * - 1 Relé (Bomba de irrigação)
 * - 1 LED (Indicador de irrigação)
 */

#include <DHT.h>

// Definição dos pinos
#define PIN_BUTTON_N 2      // Botão Nitrogênio
#define PIN_BUTTON_P 4      // Botão Fósforo
#define PIN_BUTTON_K 5      // Botão Potássio
#define PIN_LDR 34          // Sensor LDR (pH simulado)
#define PIN_DHT 15          // Sensor DHT22 (umidade)
#define PIN_RELAY 18        // Relé da bomba
#define PIN_LED 19          // LED indicador

// Configuração do DHT22
#define DHT_TYPE DHT22
DHT dht(PIN_DHT, DHT_TYPE);

// Variáveis de estado dos sensores
bool nitrogen_level = false;
bool phosphorus_level = false;
bool potassium_level = false;
float ph_value = 7.0;
float soil_humidity = 50.0;
bool irrigation_active = false;

// Parâmetros de irrigação para cultura (Tomate como exemplo)
const float MIN_HUMIDITY = 60.0;    // Umidade mínima necessária (%)
const float MAX_HUMIDITY = 80.0;    // Umidade máxima desejada (%)
const float IDEAL_PH_MIN = 6.0;     // pH mínimo ideal para tomate
const float IDEAL_PH_MAX = 6.8;     // pH máximo ideal para tomate

// Variáveis de temporização
unsigned long last_reading = 0;
const unsigned long READING_INTERVAL = 2000; // Leitura a cada 2 segundos

// Variáveis para entrada serial (integração com Python)
String serial_input = "";
bool rain_forecast = false;

void setup() {
  Serial.begin(115200);
  
  // Configuração dos pinos
  pinMode(PIN_BUTTON_N, INPUT_PULLUP);
  pinMode(PIN_BUTTON_P, INPUT_PULLUP);
  pinMode(PIN_BUTTON_K, INPUT_PULLUP);
  pinMode(PIN_RELAY, OUTPUT);
  pinMode(PIN_LED, OUTPUT);
  
  // Inicialização do DHT22
  dht.begin();
  
  // Estado inicial
  digitalWrite(PIN_RELAY, LOW);
  digitalWrite(PIN_LED, LOW);
  
  Serial.println("=== FarmTech Solutions - Sistema de Irrigação Inteligente ===");
  Serial.println("Sistema iniciado com sucesso!");
  Serial.println("Monitorando sensores...");
  Serial.println();
  
  // Cabeçalho para dados tabulados
  Serial.println("Tempo\tN\tP\tK\tpH\tUmidade(%)\tIrrigação\tStatus");
  Serial.println("---------------------------------------------------------------");
}

void loop() {
  unsigned long current_time = millis();
  
  // Verificar entrada serial para dados meteorológicos
  checkSerialInput();
  
  // Leitura dos sensores a cada intervalo definido
  if (current_time - last_reading >= READING_INTERVAL) {
    readSensors();
    bool should_irrigate = evaluateIrrigation();
    controlIrrigation(should_irrigate);
    printSensorData();
    
    last_reading = current_time;
  }
  
  delay(100);
}

void readSensors() {
  // Leitura dos botões NPK (lógica invertida devido ao INPUT_PULLUP)
  nitrogen_level = !digitalRead(PIN_BUTTON_N);
  phosphorus_level = !digitalRead(PIN_BUTTON_P);
  potassium_level = !digitalRead(PIN_BUTTON_K);
  
  // Leitura do LDR para simular pH
  int ldr_reading = analogRead(PIN_LDR);
  // Conversão para escala de pH (0-14)
  ph_value = map(ldr_reading, 0, 4095, 0, 1400) / 100.0;
  
  // Leitura da umidade do DHT22
  float humidity = dht.readHumidity();
  if (!isnan(humidity)) {
    soil_humidity = humidity;
  }
}

bool evaluateIrrigation() {
  // Lógica de decisão para irrigação baseada em múltiplos fatores
  
  // 1. Verificar previsão de chuva (se disponível)
  if (rain_forecast) {
    Serial.print("\t[CHUVA PREVISTA - Irrigação suspensa]");
    return false;
  }
  
  // 2. Verificar umidade do solo
  if (soil_humidity >= MAX_HUMIDITY) {
    Serial.print("\t[Umidade alta - Não precisa irrigar]");
    return false;
  }
  
  // 3. Verificar se umidade está abaixo do mínimo
  bool low_humidity = soil_humidity < MIN_HUMIDITY;
  
  // 4. Verificar pH adequado
  bool ph_ok = (ph_value >= IDEAL_PH_MIN && ph_value <= IDEAL_PH_MAX);
  
  // 5. Verificar nutrientes (pelo menos 2 dos 3 devem estar presentes)
  int nutrient_count = 0;
  if (nitrogen_level) nutrient_count++;
  if (phosphorus_level) nutrient_count++;
  if (potassium_level) nutrient_count++;
  bool nutrients_ok = nutrient_count >= 2;
  
  // Decisão final: irrigar se umidade baixa E (pH adequado OU nutrientes adequados)
  bool should_irrigate = low_humidity && (ph_ok || nutrients_ok);
  
  // Log da decisão
  if (should_irrigate) {
    Serial.print("\t[IRRIGANDO - Condições favoráveis]");
  } else if (!low_humidity) {
    Serial.print("\t[Umidade adequada]");
  } else if (!ph_ok && !nutrients_ok) {
    Serial.print("\t[pH ou nutrientes inadequados]");
  }
  
  return should_irrigate;
}

void controlIrrigation(bool activate) {
  if (activate != irrigation_active) {
    irrigation_active = activate;
    
    if (irrigation_active) {
      digitalWrite(PIN_RELAY, HIGH);
      digitalWrite(PIN_LED, HIGH);
      Serial.println("\n>>> BOMBA DE IRRIGAÇÃO LIGADA <<<");
    } else {
      digitalWrite(PIN_RELAY, LOW);
      digitalWrite(PIN_LED, LOW);
      Serial.println("\n>>> BOMBA DE IRRIGAÇÃO DESLIGADA <<<");
    }
  }
}

void printSensorData() {
  // Timestamp em segundos
  Serial.print(millis() / 1000);
  Serial.print("\t");
  
  // Status dos nutrientes
  Serial.print(nitrogen_level ? "OK" : "--");
  Serial.print("\t");
  Serial.print(phosphorus_level ? "OK" : "--");
  Serial.print("\t");
  Serial.print(potassium_level ? "OK" : "--");
  Serial.print("\t");
  
  // pH e umidade
  Serial.print(ph_value, 1);
  Serial.print("\t");
  Serial.print(soil_humidity, 1);
  Serial.print("\t\t");
  
  // Status da irrigação
  Serial.print(irrigation_active ? "LIGADA" : "DESL.");
  
  Serial.println();
}

void checkSerialInput() {
  // Verificar se há dados disponíveis na serial
  while (Serial.available() > 0) {
    char received_char = Serial.read();
    
    if (received_char == '\n') {
      // Processar comando recebido
      serial_input.trim();
      
      if (serial_input.startsWith("RAIN:")) {
        // Comando de previsão de chuva: RAIN:1 (chuva) ou RAIN:0 (sem chuva)
        int rain_status = serial_input.substring(5).toInt();
        rain_forecast = (rain_status == 1);
        
        Serial.println();
        Serial.print(">>> Previsão meteorológica atualizada: ");
        Serial.println(rain_forecast ? "CHUVA PREVISTA" : "SEM PREVISÃO DE CHUVA");
        Serial.println();
      }
      
      serial_input = "";
    } else {
      serial_input += received_char;
    }
  }
}

/*
 * INSTRUÇÕES DE USO:
 * 
 * 1. Conectar os componentes conforme o diagrama no Wokwi
 * 2. Os botões N, P, K simulam a presença de nutrientes
 * 3. O LDR simula o sensor de pH (variar a luz para alterar o pH)
 * 4. O DHT22 fornece leitura de umidade
 * 5. O relé controla a bomba de irrigação
 * 6. Enviar comandos via Serial Monitor:
 *    - "RAIN:1" para simular previsão de chuva
 *    - "RAIN:0" para remover previsão de chuva
 * 
 * LÓGICA DE IRRIGAÇÃO:
 * - Irriga quando umidade < 60% E (pH entre 6.0-6.8 OU pelo menos 2 nutrientes presentes)
 * - Não irriga se há previsão de chuva
 * - Não irriga se umidade > 80%
 */