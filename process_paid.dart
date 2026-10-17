import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

final _aes = AesGcm.with256bits();
final _kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);

const _saltLength = 16;

Future<String> encryptString(String plain, String password) async {
  final rng = Random.secure();
  final saltBytes = List<int>.generate(_saltLength, (_) => rng.nextInt(256));
  final key = await _kdf.deriveKeyFromPassword(
    password: password,
    nonce: saltBytes,
  );
  final box = await _aes.encrypt(utf8.encode(plain), secretKey: key);
  return base64Url.encode([...saltBytes, ...box.concatenation()]);
}

Future<void> encryptFile(String inPath, String password) async {
  final tmp = await Directory.systemTemp.createTemp();
  try {
    final zipPath = File(inPath).absolute.path;
    final list = await Process.run('unzip', ['-Z1', zipPath]);
    if (list.exitCode != 0)
      throw FileSystemException(list.stderr.toString().trim(), inPath);
    final entry = list.stdout
        .toString()
        .split('\n')
        .firstWhere(
          (e) => e == 'data.json' || e.endsWith('/data.json'),
          orElse: () =>
              throw FileSystemException('data.json not found in zip', inPath),
        );

    final unzip = await Process.run('unzip', [
      '-q',
      zipPath,
      entry,
      '-d',
      tmp.path,
    ]);
    if (unzip.exitCode != 0)
      throw FileSystemException(unzip.stderr.toString().trim(), inPath);

    final dataFile = File('${tmp.path}/$entry');
    final text = await dataFile.readAsString();
    jsonDecode(text); // fail early if the input isn't valid JSON
    final token = await encryptString(text, password);
    await dataFile.writeAsString(jsonEncode({'data': token}));

    final zip = await Process.run('zip', [
      '-q',
      zipPath,
      entry,
    ], workingDirectory: tmp.path);
    if (zip.exitCode != 0)
      throw FileSystemException(zip.stderr.toString().trim(), inPath);
  } finally {
    await tmp.delete(recursive: true);
  }
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: process_paid <in.zip>');
    exit(64);
  }
  final password = File('.env').existsSync()
      ? RegExp(
          r'^JSON_PASSWORD=(.+)$',
          multiLine: true,
        ).firstMatch(File('.env').readAsStringSync())?.group(1)?.trim()
      : null;
  if (password == null || password.isEmpty) {
    stderr.writeln('No JSON_PASSWORD environment variable set.');
    exit(64);
  }

  try {
    await encryptFile(args[0], password);
  } on SecretBoxAuthenticationError {
    stderr.writeln('Wrong password or the file was tampered with.');
    exit(1);
  } on FormatException catch (e) {
    stderr.writeln('Invalid input: ${e.message}');
    exit(1);
  } on FileSystemException catch (e) {
    stderr.writeln('File error: ${e.message} (${e.path})');
    exit(1);
  }
}
