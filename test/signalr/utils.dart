import 'dart:async';

Future<void> delayUntilAsync(int timeoutInMilliseconds,
    [bool Function()? condition]) {
  final completer = Completer<void>();
  var timeWait = 0;
  final duration = Duration(milliseconds: 10);
  Timer.periodic(duration, (timer) {
    timeWait += 10;
    if (condition != null) {
      if (condition()) {
        completer.complete();
        timer.cancel();
      } else if (timeoutInMilliseconds <= timeWait) {
        final error = Exception('Timed out waiting for condition');
        completer.completeError(error);
        timer.cancel();
      }
    } else if (timeoutInMilliseconds <= timeWait) {
      completer.complete();
      timer.cancel();
    }
  });
  return completer.future;
}

class SyncPoint {
  final Completer<void> _atSyncPoint;
  final Completer<void> _continueFromSyncPoint;

  SyncPoint()
      : _atSyncPoint = Completer<void>(),
        _continueFromSyncPoint = Completer<void>();

  Future<void> waitForSyncPointAsync() {
    return _atSyncPoint.future;
  }

  void $continue() {
    _continueFromSyncPoint.complete();
  }

  Future<void> waitToContinueAsync() {
    _atSyncPoint.complete();
    return _continueFromSyncPoint.future;
  }
}
