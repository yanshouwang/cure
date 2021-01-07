import 'package:cure/core.dart';

import 'retry_policy.dart';

// 0, 2, 10, 30 second delays before reconnect attempts.
const DEFAULT_RETRY_DELAYS_IN_MILLISECONDS = [0, 2000, 10000, 30000, null];

class DefaultReconnectPolicy implements RetryPolicy {
  final List<int> _retryDelays;

  DefaultReconnectPolicy([List<int> retryDelays])
      : _retryDelays = retryDelays != null
            ? retryDelays.merge([null])
            : DEFAULT_RETRY_DELAYS_IN_MILLISECONDS;

  @override
  int nextRetryDelayInMilliseconds(RetryContext retryContext) {
    return _retryDelays[retryContext.previousRetryCount];
  }
}
