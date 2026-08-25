import '../entities/voice_input_result.dart';

abstract class VoiceInputRepository {
  Future<Stream<VoiceInputResult>> startListening();

  Future<void> cancelListening();

  void dispose();
}
