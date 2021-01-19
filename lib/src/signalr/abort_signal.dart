/// Represents a signal that can be monitored to determine if a request has been aborted.
abstract class AbortSignal {
  /// Indicates if the request has been aborted.
  bool get aborted;
  set aborted(bool value);

  /// Set this to a handler that will be invoked when the request is aborted.
  void Function()? onabort;
}

class AbortController implements AbortSignal {
  @override
  bool aborted;
  @override
  void Function()? onabort;

  AbortSignal get signal => this;

  AbortController() : aborted = false;

  void abort() {
    if (!aborted) {
      aborted = true;
      onabort?.call();
    }
  }
}
