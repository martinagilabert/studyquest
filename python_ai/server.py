from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import requests
import json
import re

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class PromptRequest(BaseModel):
    prompt: str

class ExamRequest(BaseModel):
    transcript: str
    custom_prompt: str = ""

@app.post("/ask")
def ask_ai(data: PromptRequest):
    try:
        response = requests.post(
            "http://localhost:11434/api/chat",
            json={
                "model": "llama3.2",
                "messages": [
                    {
                        "role": "system",
                        "content": "Eres un profesor virtual para estudiantes. Explica de forma clara, breve y fácil de entender."
                    },
                    {
                        "role": "user",
                        "content": data.prompt
                    }
                ],
                "stream": False
            }
        )

        response.raise_for_status()
        result = response.json()

        return {
            "response": result["message"]["content"]
        }

    except Exception as e:
        return {"response": f"Error en backend: {str(e)}"}


def extract_json(text):
    text = text.strip()

    # quitar bloques ```json ... ```
    text = re.sub(r"^```json", "", text, flags=re.IGNORECASE).strip()
    text = re.sub(r"^```", "", text).strip()
    text = re.sub(r"```$", "", text).strip()

    # intentar JSON directo
    try:
        return json.loads(text)
    except:
        pass

    # intentar sacar el primer bloque {...} o [...]
    match = re.search(r'(\{.*\}|\[.*\])', text, re.DOTALL)
    if match:
        return json.loads(match.group(1))

    raise ValueError("No se pudo extraer JSON válido de la respuesta del modelo.")


@app.post("/generate_exam")
def generate_exam(data: ExamRequest):
    try:
        system_prompt = """
Eres un generador de exámenes tipo test.
Devuelve SOLO JSON válido.
Nada de markdown.
Nada de texto extra.
Nada de explicación.

Formato exacto:
{
  "questions": [
    {
      "question": "Pregunta aquí",
      "options": ["Opción A", "Opción B", "Opción C", "Opción D"],
      "correctAnswer": "Opción correcta"
    }
  ]
}

Reglas:
- Genera exactamente 5 preguntas.
- Cada pregunta debe tener exactamente 4 opciones.
- correctAnswer debe coincidir exactamente con una de las 4 opciones.
- Basa el examen únicamente en el contenido del chat.
- Si el usuario añade instrucciones extra, síguelas.
"""

        user_prompt = f"""
Contenido del chat:
{data.transcript}

Instrucciones extra del usuario:
{data.custom_prompt if data.custom_prompt.strip() else "Ninguna"}
"""

        response = requests.post(
            "http://localhost:11434/api/chat",
            json={
                "model": "llama3.2",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                "format": "json",
                "stream": False
            }
        )

        response.raise_for_status()
        result = response.json()
        content = result["message"]["content"]

        print("RESPUESTA RAW DEL MODELO:")
        print(content)

        parsed = json.loads(content)
        questions = parsed.get("questions", [])

        valid_questions = []
        for q in questions:
            question = q.get("question")
            options = q.get("options")
            correct = q.get("correctAnswer")

            if (
                isinstance(question, str) and question.strip() and
                isinstance(options, list) and len(options) == 4 and
                all(isinstance(opt, str) for opt in options) and
                isinstance(correct, str) and correct in options
            ):
                valid_questions.append({
                    "question": question,
                    "options": options,
                    "correctAnswer": correct,
                })

        return {"questions": valid_questions}

    except Exception as e:
        return {
            "questions": [],
            "error": str(e)
        }