import 'package:process_run/process_run.dart';

Future<void> main() async {
  final pythonScript = 'python_ai/voice_assistant.py';

  print("Ejecutando Python...");

  final result = await runExecutableArguments(
    'python',
    [pythonScript],
    workingDirectory: '.',
  );

  if (result.exitCode != 0) {
    print("Error al ejecutar Python: ${result.stderr}");
  } else {
    print("Salida de Python:");
    print(result.stdout);
  }
}
