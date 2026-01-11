import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'process_wrapper.dart';

/// Production implementation of ProcessWrapper using Dart's Process class.
class ProcessWrapperImpl implements ProcessWrapper {
  @override
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    Duration? timeout,
    String? workingDirectory,
  }) async {
    final process = await Process.start(
      command,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: true,
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);
    process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

    final exitCode = await process.exitCode.timeout(
      timeout ?? Duration(seconds: 30),
    );

    return ProcessResult(
      process.pid,
      exitCode,
      stdoutBuffer.toString(),
      stderrBuffer.toString(),
    );
  }

  @override
  Stream<String> runStreamed(
    String command,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    final controller = StreamController<String>();

    Process.start(
          command,
          arguments,
          workingDirectory: workingDirectory,
          runInShell: true,
        )
        .then((process) {
          process.stdout
              .transform(utf8.decoder)
              .listen(
                (data) => controller.add(data),
                onDone: () => controller.close(),
                onError: (error) => controller.addError(error),
              );

          process.stderr
              .transform(utf8.decoder)
              .listen(
                (data) => controller.add(data),
                onError: (error) => controller.addError(error),
              );
        })
        .catchError((error) {
          controller.addError(error);
        });

    return controller.stream;
  }
}
