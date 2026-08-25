import '../domain/repositories/voice_input_repository.dart';

class CancelVoiceInputUseCase {
  CancelVoiceInputUseCase(this.repository);

  final VoiceInputRepository repository;

  Future<void> call() {
    return repository.cancelListening();
  }
}
