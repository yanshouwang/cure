/// Defines the expected type for a receiver of results streamed by the server.
///
/// [T] The type of the items being sent by the server.
abstract class StreamSubscriber<T> {
  /// A boolean that will be set by the [Stream] when the stream is closed.
  bool? closed;

  /// Called by the framework when a new item is available.
  void next(T value);

  /// Called by the framework when an error has occurred.
  ///
  /// After this method is called, no additional methods on the [StreamSubscriber] will be called.
  void error(Object error);

  /// Called by the framework when the end of the stream is reached.
  ///
  /// After this method is called, no additional methods on the [StreamSubscriber] will be called.
  void complete();

  factory StreamSubscriber(
          {void Function(T value)? onnext,
          void Function(dynamic error)? onerror,
          void Function()? oncomplete}) =>
      _StreamSubScriber(onnext, onerror, oncomplete);
}

class _StreamSubScriber<T> implements StreamSubscriber<T> {
  @override
  bool? closed;

  void Function(T value)? onnext;
  void Function(Object error)? onerror;
  void Function()? oncomplete;

  _StreamSubScriber(this.onnext, this.onerror, this.oncomplete);

  @override
  void next(T value) {
    onnext?.call(value);
  }

  @override
  void error(dynamic error) {
    onerror?.call(error);
  }

  @override
  void complete() {
    oncomplete?.call();
  }
}

/// Defines the result of a streaming hub method.
///
/// [T] The type of the items being sent by the server.
abstract class Stream<T> {
  /// Attaches a [StreamSubscriber], which will be invoked when new items are available from the stream.
  ///
  /// [observer] The subscriber to attach.
  ///
  /// Returns a subscription that can be disposed to terminate the stream and stop calling methods on the [StreamSubscriber].
  Subscription<T> subscribe(StreamSubscriber<T> subscriber);
}

/// An interface that allows an [StreamSubscriber] to be disconnected from a stream.
///
/// [T] The type of the items being sent by the server.
abstract class Subscription<T> {
  /// Disconnects the [StreamSubscriber] associated with this subscription from the stream.
  void dispose();
}
