import '../../domain/entities/voice_input_result.dart';
import '../../domain/repositories/voice_input_repository.dart';
import '../datasources/system_voice_input_data_source.dart';

class SystemVoiceInputRepositoryImpl implements VoiceInputRepository {
  final SystemVoiceInputDataSource dataSource;

  SystemVoiceInputRepositoryImpl({
    required this.dataSource,
  });

  @override
  Future<Stream<VoiceInputResult>> startListening() async {
    final stream = await dataSource.startListening();
    return stream.map(
      (event) => VoiceInputResult(
        text: event.$1,
        isFinal: event.$2,
      ),
    );
  }


  @override
  Future<void> cancelListening() {
    return dataSource.cancelListening();
  }

  @override
  void dispose() {
    dataSource.dispose();
  }
}
