import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class ScrollActivityNotifier {

final ValueNotifier<bool> isScrolling = ValueNotifier<bool>(false);
final Duration idleDebounce;
  Timer? _idleTimer;
ScrollActivityNotifier({
  this.idleDebounce = const Duration(milliseconds: 180),
  });

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _setScrolling(true);
       return false;
    } 
    
     if (notification is ScrollUpdateNotification) {
      _setScrolling(true);
      return false;
    }

    if (notification is ScrollEndNotification) {
       _scheduleIdle();
       return false;
    }

    if (notification is UserScrollNotification) {
     if(notification.direction == ScrollDirection.idle){
        _scheduleIdle();
      } else {
        _setScrolling(true);
      }
      return false;
    
    }
    return false;
  }

  void _setScrolling(bool value) {
    _idleTimer?.cancel();
    _idleTimer = null;
    if (isScrolling.value != value) {
      isScrolling.value = value;
    }
  }

  void _scheduleIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleDebounce, () {
      if (isScrolling.value) {
        isScrolling.value = false;
      }
    });
  }

void dispose() {
    _idleTimer?.cancel();
    _idleTimer = null;
    isScrolling.dispose();
  }
}