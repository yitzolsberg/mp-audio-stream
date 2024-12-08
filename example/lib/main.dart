import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mp_audio_stream/mp_audio_stream.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Stream Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Audio Stream Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const sampleRate = 44100;

  late AudioStream audioStream;

  AudioStreamStat stat = AudioStreamStat.empty();

  bool _isPlaying = false;

  void _initStream() {
    print("init stream");
    audioStream = getAudioStream();

    audioStream.init(
        sampleRate: sampleRate,
        channels: 1,
        bufferMilliSec: 600,
        waitingBufferMilliSec: 30);
  }

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    audioStream.uninit();
    _initStream();
  }

  @override
  void dispose() {
    audioStream.uninit();
    super.dispose();
  }

  static List<double> _synthSineWave(
      double freq, int sampleRate, Duration duration) {
    final length = duration.inMilliseconds * sampleRate ~/ 1000;
    final sineWave = List.generate(length,
        (i) => math.sin(2 * math.pi * ((i * freq) % sampleRate) / sampleRate));

    return sineWave;
  }

  void _onPressed() async {
    setState(() => _isPlaying = true);

    // for web, calling `resume()` from user-action is needed
    audioStream.resume();

    const noteDuration = Duration(seconds: 1);

    const balanceAmount = 60 * sampleRate ~/ 1000;

    var lastCount = 0;

    var waves = <double>[];
    for (double noteFreq in [261.626, 293.665, 329.628]) {
      final wavePart = _synthSineWave(noteFreq, sampleRate, noteDuration);
      waves.addAll(wavePart);
    }

    var wave = Float32List.fromList(waves);
    var pos = 0;
    while (pos < wave.length) {
      var amountToSend = math.max(100, balanceAmount - lastCount);
      amountToSend = math.min(amountToSend, wave.length - pos);

      var newLastCount =
          audioStream.push(wave.sublist(pos, pos + amountToSend));
      var usedAmount = lastCount + amountToSend - newLastCount;
      lastCount = newLastCount;
      print(
          "Used: $usedAmount, In buffer: ${lastCount - amountToSend}, sent: $amountToSend");
      setState(() => stat = audioStream.stat());
      pos += amountToSend;
      await Future.delayed(const Duration(milliseconds: 10));
    }

    setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("full: ${stat.full} exhaust:${stat.exhaust}"),
            ElevatedButton(
                onPressed: _isPlaying ? null : _onPressed,
                child: const Text(
                  'generate sine wave',
                ))
          ],
        ),
      ),
    );
  }
}
