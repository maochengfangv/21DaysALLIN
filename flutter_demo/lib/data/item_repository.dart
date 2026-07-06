import 'dart:async';
import 'dart:ffi';

import 'package:flutter/foundation.dart';

import 'item_model.dart';

class ItemRepository {

  final Duration simulatedDelay;

  const ItemRepository ({
    this.simulatedDelay = const Duration(milliseconds: 350),
  });

  Future<List<ItemModel>> fetchPage({
   required int page,
   required int pageSize,
  }) async {
    await Future.delayed(simulatedDelay);
    final startIndex = page * pageSize;
    final endExclusive = startIndex + pageSize;

    return List<ItemModel>.generate(
      pageSize,
      (index){
         final id = startIndex + index;
        return ItemModel(
        id: id,
        title: 'Item ${id}',
        subtitle: 'Subtitle for #$id · page=$page',
        thumbUrl: 'https://picsum.photos/seed/$id/80/80',
      );
      }, growable: false,
    );
  }
}

class ItemStore extends ChangeNotifier {

  final ItemRepository repository;
  final int pageSize;
  final int totalLimit;

  final List<ItemModel> _items = <ItemModel>[];
  final Map<int, ValueNotifier<bool>> _likeNotifiers = <int, ValueNotifier<bool>>{};

  bool _isLoading = false;
  bool _hasMore = true;
  int _nextPage = 0;


  ItemStore({
    required this.repository,
    this.pageSize = 50,
    this.totalLimit = 20000,
  });

  List<ItemModel> get items => List<ItemModel>.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  ValueNotifier<bool> likeNotifierFor(int itemId) {
    return _likeNotifiers.putIfAbsent(itemId, () => ValueNotifier<bool>(false));
  }

Future<void> loadInitial() async {
    if (_items.isNotEmpty) {
      return;
    }
    await loadNextPage();
  }

  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMore) {
      return;
    }
    
    _isLoading = true;

    notifyListeners();

    try {
      final page = _nextPage;
      final newItems = await repository.fetchPage(page: page, pageSize: pageSize);
      if (newItems.isEmpty){
        _hasMore = false;
      } else {
        _items.addAll(newItems);
        _nextPage++;
        if (_items.length >= totalLimit) {
          _hasMore = false;
        }
      }

    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final notifier in _likeNotifiers.values) {
      notifier.dispose();
    }
    _likeNotifiers.clear();
    super.dispose();
  }
}