"""
FarmTech Solutions - Integração com API Meteorológica
Sistema de previsão do tempo para otimização da irrigação

Este módulo integra dados meteorológicos da OpenWeatherMap
para ajustar automaticamente o sistema de irrigação.
"""

import requests
import json
import time
import serial
import logging
from datetime import datetime, timedelta
from typing import Dict, Optional, Tuple

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('weather_integration.log'),
        logging.StreamHandler()
    ]
)

class WeatherIntegration:
    """
    Classe para integração com API meteorológica e controle do ESP32
    """
    
    def __init__(self, api_key: str, lat: float, lon: float, serial_port: str = None):
        """
        Inicializa a integração meteorológica
        
        Args:
            api_key: Chave da API OpenWeatherMap
            lat: Latitude da fazenda
            lon: Longitude da fazenda
            serial_port: Porta serial do ESP32 (ex: 'COM3' no Windows)
        """
        self.api_key = api_key
        self.lat = lat
        self.lon = lon
        self.base_url = "https://api.openweathermap.org/data/2.5"
        self.serial_connection = None
        
        # Tentar conectar ao ESP32 via serial
        if serial_port:
            try:
                self.serial_connection = serial.Serial(serial_port, 115200, timeout=1)
                logging.info(f"Conectado ao ESP32 na porta {serial_port}")
            except Exception as e:
                logging.warning(f"Não foi possível conectar à porta serial: {e}")
                logging.info("Modo simulação: dados serão exibidos apenas no console")
    
    def get_current_weather(self) -> Optional[Dict]:
        """
        Obtém dados meteorológicos atuais
        
        Returns:
            Dicionário com dados do tempo atual ou None se falhar
        """
        url = f"{self.base_url}/weather"
        params = {
            'lat': self.lat,
            'lon': self.lon,
            'appid': self.api_key,
            'units': 'metric',
            'lang': 'pt'
        }
        
        try:
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            logging.error(f"Erro ao obter clima atual: {e}")
            return None
    
    def get_forecast(self) -> Optional[Dict]:
        """
        Obtém previsão meteorológica para os próximos dias
        
        Returns:
            Dicionário com previsão ou None se falhar
        """
        url = f"{self.base_url}/forecast"
        params = {
            'lat': self.lat,
            'lon': self.lon,
            'appid': self.api_key,
            'units': 'metric',
            'lang': 'pt'
        }
        
        try:
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            logging.error(f"Erro ao obter previsão: {e}")
            return None
    
    def analyze_rain_probability(self, hours_ahead: int = 6) -> Tuple[bool, float]:
        """
        Analisa probabilidade de chuva nas próximas horas
        
        Args:
            hours_ahead: Número de horas para analisar
            
        Returns:
            Tupla (vai_chover, probabilidade_mm)
        """
        forecast = self.get_forecast()
        if not forecast:
            return False, 0.0
        
        current_time = datetime.now()
        cutoff_time = current_time + timedelta(hours=hours_ahead)
        
        total_rain = 0.0
        rain_periods = 0
        
        for item in forecast['list']:
            forecast_time = datetime.fromtimestamp(item['dt'])
            
            if forecast_time <= cutoff_time:
                # Verificar se há previsão de chuva
                if 'rain' in item:
                    if '3h' in item['rain']:
                        total_rain += item['rain']['3h']
                        rain_periods += 1
                
                # Verificar condições meteorológicas
                weather_id = item['weather'][0]['id']
                if 200 <= weather_id <= 599:  # Códigos de chuva/tempestade
                    rain_periods += 1
        
        # Considerar chuva significativa se > 2mm nas próximas horas
        will_rain = total_rain > 2.0 or rain_periods > 0
        
        return will_rain, total_rain
    
    def send_rain_status_to_esp32(self, rain_forecast: bool):
        """
        Envia status de chuva para o ESP32
        
        Args:
            rain_forecast: True se há previsão de chuva
        """
        command = f"RAIN:{1 if rain_forecast else 0}\n"
        
        if self.serial_connection and self.serial_connection.is_open:
            try:
                self.serial_connection.write(command.encode())
                logging.info(f"Comando enviado ao ESP32: {command.strip()}")
            except Exception as e:
                logging.error(f"Erro ao enviar comando ao ESP32: {e}")
        else:
            logging.info(f"[SIMULAÇÃO] Comando para ESP32: {command.strip()}")
    
    def get_weather_summary(self) -> Dict:
        """
        Gera resumo completo das condições meteorológicas
        
        Returns:
            Dicionário com resumo do clima
        """
        current = self.get_current_weather()
        if not current:
            return {}
        
        will_rain, rain_amount = self.analyze_rain_probability()
        
        summary = {
            'timestamp': datetime.now().isoformat(),
            'location': f"{current['name']}, {current['sys']['country']}",
            'current_conditions': {
                'temperature': current['main']['temp'],
                'humidity': current['main']['humidity'],
                'description': current['weather'][0]['description'],
                'wind_speed': current['wind']['speed'],
                'pressure': current['main']['pressure']
            },
            'rain_forecast': {
                'will_rain': will_rain,
                'amount_mm': rain_amount,
                'recommendation': 'Suspender irrigação' if will_rain else 'Irrigação normal'
            }
        }
        
        return summary
    
    def monitor_weather(self, check_interval: int = 1800):
        """
        Monitora condições meteorológicas continuamente
        
        Args:
            check_interval: Intervalo entre verificações em segundos (padrão: 30 min)
        """
        logging.info("Iniciando monitoramento meteorológico...")
        logging.info(f"Verificações a cada {check_interval/60:.1f} minutos")
        
        while True:
            try:
                # Obter resumo do tempo
                summary = self.get_weather_summary()
                
                if summary:
                    # Exibir informações
                    current = summary['current_conditions']
                    rain_info = summary['rain_forecast']
                    
                    logging.info("=== RESUMO METEOROLÓGICO ===")
                    logging.info(f"Local: {summary['location']}")
                    logging.info(f"Temperatura: {current['temperature']:.1f}°C")
                    logging.info(f"Umidade: {current['humidity']}%")
                    logging.info(f"Condições: {current['description']}")
                    logging.info(f"Previsão de chuva: {'SIM' if rain_info['will_rain'] else 'NÃO'}")
                    
                    if rain_info['will_rain']:
                        logging.info(f"Quantidade prevista: {rain_info['amount_mm']:.1f}mm")
                        logging.info(f"Recomendação: {rain_info['recommendation']}")
                    
                    # Enviar status para ESP32
                    self.send_rain_status_to_esp32(rain_info['will_rain'])
                
                # Aguardar próxima verificação
                logging.info(f"Próxima verificação em {check_interval/60:.1f} minutos")
                time.sleep(check_interval)
                
            except KeyboardInterrupt:
                logging.info("Monitoramento interrompido pelo usuário")
                break
            except Exception as e:
                logging.error(f"Erro no monitoramento: {e}")
                time.sleep(60)  # Aguardar 1 minuto antes de tentar novamente


def main():
    """
    Função principal para execução do sistema
    """
    # Configurações (SUBSTITUIR PELOS DADOS REAIS)
    API_KEY = "SUA_CHAVE_API_OPENWEATHER"  # Obter em: https://openweathermap.org/api
    
    # Coordenadas de exemplo (São Paulo - Região Metropolitana)
    LATITUDE = -23.5505
    LONGITUDE = -46.6333
    
    # Porta serial do ESP32 (ajustar conforme necessário)
    SERIAL_PORT = "COM3"  # Windows: COM3, Linux: /dev/ttyUSB0
    
    if API_KEY == "SUA_CHAVE_API_OPENWEATHER":
        print("⚠️  ATENÇÃO: Configure sua chave da API OpenWeatherMap!")
        print("1. Acesse: https://openweathermap.org/api")
        print("2. Crie uma conta gratuita")
        print("3. Substitua 'SUA_CHAVE_API_OPENWEATHER' pela sua chave")
        print("4. Ajuste as coordenadas da sua fazenda")
        return
    
    # Inicializar sistema
    weather_system = WeatherIntegration(
        api_key=API_KEY,
        lat=LATITUDE,
        lon=LONGITUDE,
        serial_port=SERIAL_PORT
    )
    
    print("🌤️  FarmTech Solutions - Sistema Meteorológico")
    print("=" * 50)
    
    # Exibir resumo inicial
    summary = weather_system.get_weather_summary()
    if summary:
        print("📍 Resumo Inicial:")
        current = summary['current_conditions']
        print(f"   Local: {summary['location']}")
        print(f"   Temperatura: {current['temperature']:.1f}°C")
        print(f"   Umidade: {current['humidity']}%")
        print(f"   Condições: {current['description']}")
        print()
    
    # Iniciar monitoramento
    try:
        weather_system.monitor_weather(check_interval=600)  # 10 minutos para testes
    except KeyboardInterrupt:
        print("\n👋 Sistema finalizado pelo usuário")
    finally:
        if weather_system.serial_connection:
            weather_system.serial_connection.close()


if __name__ == "__main__":
    main()