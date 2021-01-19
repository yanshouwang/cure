import 'stream.dart';

/// Stream implementation to stream items to the server.
class Subject<T> implements Stream<T> {
  List<StreamSubscriber<T>> observers;
  Future<void> Function()? cancelCallback;

  Subject() : observers = [];

  void next(T item) {
    for (var observer in observers) {
      observer.next(item);
    }
  }

  void error(Object err) {
    for (var observer in observers) {
      observer.error(err);
    }
  }

  void complete() {
    for (var observer in observers) {
      observer.complete();
    }
  }

  @override
  Subscription<T> subscribe(StreamSubscriber<T> observer) {
    observers.add(observer);
    return _SubjectSubscription(this, observer);
  }
}

class _SubjectSubscription<T> implements Subscription<T> {
  final Subject<T> _subject;
  final StreamSubscriber<T> _observer;

  _SubjectSubscription(this._subject, this._observer);

  @override
  void dispose() {
    final index = _subject.observers.indexOf(_observer);
    if (index > -1) {
      _subject.observers.removeAt(index);
    }

    if (_subject.observers.isEmpty && _subject.cancelCallback != null) {
      try {
        _subject.cancelCallback!();
      } catch (_) {}
    }
  }
}
