import os
import requests
import logging
import json
from dotenv import load_dotenv
from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, storage
import openai
from crewai import Agent, LLM, Task, Crew, Process
from crewai_tools import SerperDevTool
import mimetypes
from decouple import config
from openai import OpenAI

load_dotenv()
OpenAI_API_KEY = config('OPENAI_API_KEY')

client = OpenAI(api_key=OpenAI_API_KEY)

openai_api_key = os.getenv("OPENAI_API_KEY")
serp_api_key = os.getenv("SERP_API_KEY")
weather_api_key = os.getenv("OPENWEATHERMAP_API_KEY")

cred = credentials.Certificate("C:/Users/ASUS/Downloads/clothing-gourmet-firebase-adminsdk-fzq64-34b87561dc.json")
firebase_admin.initialize_app(cred, {
    'storageBucket': 'clothing-gourmet.firebasestorage.app'
})

openai.api_key = os.getenv("OPENAI_API_KEY")

if not all([openai_api_key, serp_api_key, weather_api_key]):
    raise EnvironmentError("API anahtarları eksik! Lütfen .env dosyasını kontrol edin.")

app = Flask(__name__)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("app.log"),
        logging.StreamHandler()
    ]
)

def get_weather_data(city_name, api_key):
    base_url = "https://api.openweathermap.org/data/2.5/weather"
    params = {
        "q": city_name,
        "appid": api_key,
        "units": "metric",
        "lang": "tr"
    }
    try:
        response = requests.get(base_url, params=params, timeout=120)
        response.raise_for_status()
        weather_data = response.json()
        return {
            "city": weather_data["name"],
            "temp": weather_data["main"]["temp"],
            "description": weather_data["weather"][0]["description"],
            "humidity": weather_data["main"]["humidity"],
            "wind_speed": weather_data["wind"]["speed"]
        }
    except requests.exceptions.RequestException as e:
        return {"error": f"Hava durumu API hatası: {str(e)}"}

llm = LLM(model="gpt-4o-mini", api_key=openai_api_key, temperature=0.7)
google_search = SerperDevTool(api_key=serp_api_key)

stil_arastirmaci = Agent(
    role="Stil Araştırmacısı",
    goal="Kullanıcının katılacağı etkinlik, toplantı veya herhangi bir yere gitmesi için uygun kıyafet trendlerini ve moda önerilerini araştırmak",
    backstory="Sen deneyimli bir stil araştırmacısın. Kullanıcının etkinlik ve tarz tercihlerini öğrenip, en güncel moda trendlerine göre öneriler hazırlarsın. Google gibi kaynaklardan güncel stil yorumlarını ve hava durumunu dikkate alarak tavsiyeler verirsin.",
    tools=[google_search],
    llm=llm
)

stil_onerisi_yapici = Agent(
    role="Moda Stilisti",
    goal="Stil araştırmacısından gelen bilgiler doğrultusunda cinsiyet, hava durumu ve katılacağı ortama uygun kıyafet önerileri sunmak",
    backstory="Sen uzman bir moda stilistisin. Kullanıcının cinsiyetini, hava durumu koşullarını, giymek istediği bir tarz veya etkinliği dikkate alarak kıyafet ve aksesuar önerileri hazırlarsın.Erkekler için daha maskülen kadınlar için daha tatlı kıyafet önerilerinde bulunursun",
    tools=[],
    llm=llm
)

@app.route('/recommend', methods=['POST'])
def recommend():
    data = request.get_json()
    topic = data.get('topic', '').strip()
    gender = data.get('gender', '').strip()
    location = data.get('location', 'İstanbul').strip()

    if not topic or not gender or not location:
        return jsonify({"error": "Eksik veri: topic, gender veya location gerekli."}), 400

    weather_data = get_weather_data(location, weather_api_key)
    if "error" in weather_data:
        weather_summary = f"Hava durumu alınamadı: {weather_data['error']}"
    else:
        weather_summary = (f"{weather_data['city']} için hava durumu: {weather_data['temp']}°C, "
                           f"{weather_data['description']}, Nem: {weather_data['humidity']}%, "
                           f"Rüzgar Hızı: {weather_data['wind_speed']} m/s.")

    stil_arastirma_gorevi = Task(
        description=f"Etkinlik: {topic}, Cinsiyet: {gender}, Hava Durumu: {weather_summary}",
        expected_output="Kullanıcıya uygun stil önerileri.",
        agent=stil_arastirmaci
    )

    stil_onerisi_gorevi = Task(
        description=f"Stil araştırmasından gelen bilgiler ile cinsiyet, hava durumu ve etkinlik bazlı kıyafet önerileri oluştur.",
        expected_output="Moda stilisti tarafından önerilen kıyafetler.",
        agent=stil_onerisi_yapici
    )

    crew = Crew(
        agents=[stil_arastirmaci, stil_onerisi_yapici],
        tasks=[stil_arastirma_gorevi, stil_onerisi_gorevi],
        process=Process.sequential,
        verbose=True
    )

    try:
        result = crew.kickoff(inputs={"topic": topic, "gender": gender, "location": location})
        result_str = str(result)
        return jsonify({"final_answer": result_str}), 200

    except Exception as e:
        logging.error(f"Beklenmeyen bir hata: {str(e)}")
        return jsonify({"error": f"Beklenmeyen bir hata: {str(e)}"}), 500

@app.route('/upload_image', methods=['POST'])
def upload_image():
    data = request.form
    gender = data.get('gender', '').strip()
    location = data.get('location', 'İstanbul').strip()
    image_file = request.files.get('image')

    if not image_file or not gender or not location:
        return jsonify({"error": "Eksik veri: image, gender veya location gerekli."}), 400

    try:
        content_type, _ = mimetypes.guess_type(image_file.filename)
        if not content_type:
            content_type = "application/octet-stream"

        bucket = storage.bucket()
        blob = bucket.blob(f"images/{image_file.filename}")
        blob.upload_from_file(image_file, content_type=content_type)
        blob.make_public()
        image_url = blob.public_url
        logging.info(f"Oluşturulan resim URL'si: {image_url}")

        analysis_result = get_image_description(image_url, "en")
        return jsonify({"image_analysis": analysis_result}), 200

    except Exception as e:
        logging.error(f"Resim yükleme hatası: {str(e)}")
        return jsonify({"error": f"Resim yükleme hatası: {str(e)}"}), 500


# OpenAI ile resim analizi yapma fonksiyonu
def get_image_description(image_url, lang, user_data=None, location="İstanbul"):
    try:
        if location:
            weather_data = get_weather_data(location, weather_api_key)
            if "error" in weather_data:
                weather_summary = f"Hava durumu alınamadı: {weather_data['error']}"
            else:
                weather_summary = (f"{weather_data['city']} için hava durumu: {weather_data['temp']}°C, "
                                   f"{weather_data['description']}, Nem: {weather_data['humidity']}%, "
                                   f"Rüzgar Hızı: {weather_data['wind_speed']} m/s.")
        else:
            weather_summary = "Hava durumu bilgisi mevcut değil."

        response = client.chat.completions.create(
            model="gpt-4o-mini",  
            messages=[
                {
                    "role": "system",
                    "content": f"Sen bir kıyafet uyumluluk analistisin ve resimdeki kıyafeti analiz et ve hangi kıyafetlerle uyumlu olduğunu söyle. "
                               f"Ayrıca hava durumu: {weather_summary} bilgilerini göz önünde bulundur."
                },
                {
                    "role": "user",
                    "content": [
                        {
                           "type": "text", 
                           "text": "Resimdeki kıyafeti analiz et ve Şu anki hava durumu bilgisini de göz önünde bulundur. Hangi erkek kıyafetleriyle uyumlu olduğunu söyle ve kısaca nedenini belirt."
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": image_url,
                            }
                        }
                    ],
                }
            ],
            max_tokens=1000,
        )
        
        response_text = response.choices[0].message.content
        print("\n=== OpenAI API Response ===", flush=True)
        print(f"get_image_description: Received response from OpenAI: {response_text[:200]}...", flush=True)
        return response_text

    except Exception as e:
        logging.error(f"OpenAI analizi sırasında hata: {str(e)}")
        return "Resim analizi yapılırken bir hata oluştu."





if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000, debug=True)
