import 'package:just_audio/just_audio.dart';

void main() {
  final source = ResolvingAudioSource(
    uniqueId: '123',
    provider: (context) async {
      return Uri.parse('http://example.com');
    },
  );
}
