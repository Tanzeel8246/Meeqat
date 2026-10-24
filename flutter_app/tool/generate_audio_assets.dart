// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

Uint8List generateWav(List<double> freqs, double durationSec) {
  const int sampleRate = 22050;
  final int numSamples = (sampleRate * durationSec).toInt();
  final ByteData data = ByteData(44 + numSamples * 2);

  // RIFF header
  data.setUint8(0, 0x52); // R
  data.setUint8(1, 0x49); // I
  data.setUint8(2, 0x46); // F
  data.setUint8(3, 0x46); // F
  data.setUint32(4, 36 + numSamples * 2, Endian.little);
  data.setUint8(8, 0x57);  // W
  data.setUint8(9, 0x41);  // A
  data.setUint8(10, 0x56); // V
  data.setUint8(11, 0x45); // E

  // fmt chunk
  data.setUint8(12, 0x66); // f
  data.setUint8(13, 0x6D); // m
  data.setUint8(14, 0x74); // t
  data.setUint8(15, 0x20); // ' '
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);  // PCM
  data.setUint16(22, 1, Endian.little);  // Mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);

  // data chunk
  data.setUint8(36, 0x64); // d
  data.setUint8(37, 0x61); // a
  data.setUint8(38, 0x74); // t
  data.setUint8(39, 0x61); // a
  data.setUint32(40, numSamples * 2, Endian.little);

  for (int i = 0; i < numSamples; i++) {
    double t = i / sampleRate;
    double progress = i / numSamples;
    double envelope = math.sin(math.pi * progress);
    double sample = 0;
    for (double f in freqs) {
      sample += math.sin(2 * math.pi * f * t);
    }
    sample = (sample / freqs.length) * envelope;
    int pcm = (sample * 28000).clamp(-32768, 32767).toInt();
    data.setInt16(44 + i * 2, pcm, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  final outDir = Directory('assets/audio');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final tones = {
    'makkah': [440.0, 554.37, 659.25, 880.0],       // Maqam Hijaz
    'madinah': [523.25, 659.25, 783.99, 1046.5],    // Maqam Rast
    'aqsa': [392.0, 493.88, 587.33, 783.99],        // Maqam Bayati
    'cairo': [466.16, 587.33, 698.46, 932.33],      // Maqam Saba
    'istanbul': [349.23, 440.0, 523.25, 698.46],    // Maqam Ussak
  };

  for (var entry in tones.entries) {
    final wavBytes = generateWav(entry.value, 4.5);
    final file = File('assets/audio/${entry.key}.wav');
    file.writeAsBytesSync(wavBytes);
    print('Generated: ${file.path} (${wavBytes.length} bytes)');
  }
}
