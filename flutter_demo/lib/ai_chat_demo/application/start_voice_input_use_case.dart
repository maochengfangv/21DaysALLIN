import '../domain/entities/voice_input_result.dart';
import '../domain/repositories/voice_input_repository.dart';

class StartVoiceInputUseCase {
  StartVoiceInputUseCase(this.repository);

  final VoiceInputRepository repository;

  Future<Stream<VoiceInputResult>> call() {
    return repository.startListening();
  }
}
