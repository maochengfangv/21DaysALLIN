import 'package:bloc/bloc.dart';

// ========== 事件（Event）：用户意图 ==========
sealed class CounterEvent {}

final class Increment extends CounterEvent {}

final class Decrement extends CounterEvent {}

// ========== 状态（State）：UI 可观察的数据 ==========
class CounterState {
  const CounterState(this.count);
  final int count;
}

// ========== Bloc：事件 → 状态 的转换引擎 ==========
class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(const CounterState(0)) {
    on<Increment>((event, emit) => emit(CounterState(state.count + 1)));
    on<Decrement>((event, emit) => emit(CounterState(state.count - 1)));
  }
}
