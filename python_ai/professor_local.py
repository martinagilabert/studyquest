import subprocess
import json
# Forzar UTF-8 en la consola
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def preguntar_llama(prompt):
    process = subprocess.Popen(
        ["ollama", "run", "llama3.2"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    # Enviamos el prompt
    process.stdin.write(prompt)
    process.stdin.close()

    # Leemos la respuesta
    respuesta = process.stdout.read()
    return respuesta.strip()

while True:
    pregunta = input("Pregunta al profesor: ")
    respuesta = preguntar_llama(pregunta)
    print("\nProfesor:", respuesta, "\n")
