import subprocess
import sounddevice as sd
import queue
import json
import os
from vosk import Model, KaldiRecognizer
import pyttsx3

# -----------------------------
#    CONFIGURAR MODELOS
# -----------------------------

vosk_model_path = os.path.join(os.path.dirname(__file__), "models/vosk-model-small-es-0.42")
if not os.path.exists(vosk_model_path):
    raise FileNotFoundError(f"No se encontró el modelo en {vosk_model_path}")

model = Model(vosk_model_path)
engine = pyttsx3.init()
engine.setProperty('rate', 170)  # velocidad de voz

# -----------------------------
#   IA LOCAL (Ollama)
# -----------------------------
def ask_llama(prompt):
    try:
        process = subprocess.Popen(
            ["ollama", "run", "llama3.2"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8"
        )

        process.stdin.write(prompt + "\n")
        process.stdin.close()

        respuesta = process.stdout.read()
        return respuesta.strip()
    except Exception as e:
        print("Error al usar Ollama:", e)
        return "Lo siento, no pude generar una respuesta."

# -----------------------------
#   ESCUCHAR MICRÓFONO
# -----------------------------
def listen_voice():
    q = queue.Queue()

    def callback(indata, frames, time, status):
        if status:
            print("Estado del micrófono:", status)
        q.put(bytes(indata))

    recognizer = KaldiRecognizer(model, 16000)

    print("\n[Habla ahora...]")  # Emoji eliminado para Windows CMD
    with sd.RawInputStream(samplerate=16000, blocksize=8000, dtype='int16',
                           channels=1, callback=callback):
        while True:
            data = q.get()
            if recognizer.AcceptWaveform(data):
                text = recognizer.Result()
                text_json = json.loads(text)
                return text_json.get("text", "")

# -----------------------------
#   TTS (hablar la respuesta)
# -----------------------------
def speak(text):
    engine.say(text)
    engine.runAndWait()

# -----------------------------
#   LOOP PRINCIPAL
# -----------------------------
if __name__ == "__main__":
    print("Asistente de voz listo. Di algo!")
    while True:
        try:
            pregunta = listen_voice()
            if not pregunta.strip():
                continue

            print("Tú:", pregunta)

            respuesta = ask_llama(pregunta)
            print("Profesor:", respuesta)

            speak(respuesta)
        except KeyboardInterrupt:
            print("\nSaliendo...")
            break
        except Exception as e:
            print("Ocurrió un error:", e)
