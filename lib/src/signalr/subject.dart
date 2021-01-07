import 'stream.dart';
import 'utils.dart';

/// Stream implementation to stream items to the server.
class Subject<T> implements StreamResult<T> {
  List<StreamSubscriber<T>> observers;
  Future<void> Function() cancelCallback;

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
    return SubjectSubscription(this, observer);
  }
}
