// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A [Future] is used to obtain a value sometime in the future.  Receivers of a
 * [Future] can obtain the value by passing a callback to [then]. For example:
 *
 *     Future<int> future = getFutureFromSomewhere();
 *     future.then((value) {
 *       print("I received the number $value");
 *     });
 *
 * A future may complete by *succeeding* (producing a value) or *failing*
 * (producing an exception, which may be handled with [handleException]).
 * Callbacks passed to [onComplete] will be invoked in either case.
 *
 * When a future completes, the following actions happen in order:
 *
 *   1. if the future suceeded, handlers registered with [then] are called.
 *   2. if the future failed, handlers registered with [handleException] are
 *      called in sequence, until one returns true.
 *   3. handlers registered with [onComplete] are called
 *   4. if the future failed, and at least one handler was registered with
 *      [then], and no handler registered with [handleException] returned
 *      [:true:], then the exception is thrown.
 *
 * Use a [Completer] to create and change the state of a [Future].
 */
interface Future<T> default FutureImpl<T> {

  /** A future whose value is immediately available. */
  Future.immediate(T value);

  /** The value provided. Throws an exception if [hasValue] is false. */
  T get value();

  /**
   * Exception that occurred ([:null:] if no exception occured). This property
   * throws a [FutureNotCompleteException] if it is used before this future is
   * completes.
   */
  Object get exception();

  /**
   * The stack trace object associated with the exception that occurred. This
   * throws a [FutureNotCompleteException] if it is used before the future
   * completes. Returns [:null:] if the future completed successfully or a
   * stack trace wasn't provided with the exception when it occurred.
   */
  Object get stackTrace();

  /**
   * Whether the future is complete (either the value is available or there was
   * an exception).
   */
  bool get isComplete();

  /**
   * Whether the value is available (meaning [isComplete] is true, and there was
   * no exception).
   */
  bool get hasValue();

  /**
   * When this future is complete (either with a value or with an exception),
   * then [complete] is called with the future.
   * If [complete] throws an exception, it is ignored.
   */
  void onComplete(void complete(Future<T> future));

  /**
   * If this future is complete and has a value, then [onValue] is called
   * with the value.
   */
  void then(void onSuccess(T value));

  /**
   * If this future is complete and has an exception, then call [onException].
   *
   * If [onException] returns true, then the exception is considered handled.
   *
   * If [onException] does not return true (or [handleException] was never
   * called), then the exception is not considered handled. In that case, if
   * there were any calls to [then], then the exception will be thrown when the
   * value is set.
   *
   * In most cases it should not be necessary to call [handleException],
   * because the exception associated with this [Future] will propagate
   * naturally if the future's value is being consumed. Only call
   * [handleException] if you need to do some special local exception handling
   * related to this particular Future's value.
   */
  void handleException(bool onException(Object exception));

  /**
   * A future representing [transformation] applied to this future's value.
   *
   * When this future gets a value, [transformation] will be called on the
   * value, and the returned future will receive the result.
   *
   * If an exception occurs (received by this future, or thrown by
   * [transformation]) then the returned future will receive the exception.
   *
   * You must not add exception handlers to [this] future prior to calling
   * transform, and any you add afterwards will not be invoked.
   */
  Future transform(transformation(T value));

   /**
    * A future representing an asynchronous transformation applied to this
    * future's value. [transformation] must return a Future.
    *
    * When this future gets a value, [transformation] will be called on the
    * value. When the resulting future gets a value, the returned future
    * will receive it.
    *
    * If an exception occurs (received by this future, thrown by
    * [transformation], or received by the future returned by [transformation])
    * then the returned future will receive the exception.
    *
    * You must not add exception handlers to [this] future prior to calling
    * chain, and any you add afterwards will not be invoked.
    */
   Future chain(Future transformation(T value));
}


/**
 * A [Completer] is used to produce [Future]s and supply their value when it
 * becomes available.
 *
 * A service that provides values to callers, and wants to return [Future]s can
 * use a [Completer] as follows:
 *
 *   Completer completer = new Completer();
 *   // send future object back to client...
 *   return completer.future;
 *   ...
 *
 *   // later when value is available, call:
 *   completer.complete(value);
 *
 *   // alternatively, if the service cannot produce the value, it
 *   // can provide an exception:
 *   completer.completeException(exception);
 *
 */
interface Completer<T> default CompleterImpl<T> {

  Completer();

  /** The future that will contain the value produced by this completer. */
  Future get future();

  /** Supply a value for [future]. */
  void complete(T value);

  /**
   * Indicate in [future] that an exception occured while trying to produce its
   * value. The argument [exception] should not be [:null:]. A [stackTrace]
   * object can be provided as well to give the user information about where
   * the error occurred. If omitted, it will be [:null:].
   */
  void completeException(Object exception, [Object stackTrace]);
}

/** Thrown when reading a future's properties before it is complete. */
class FutureNotCompleteException implements Exception {
  FutureNotCompleteException() {}
  String toString() => "Exception: future has not been completed";
}

/**
 * Thrown if a completer tries to set the value on a future that is already
 * complete.
 */
class FutureAlreadyCompleteException implements Exception {
  FutureAlreadyCompleteException() {}
  String toString() => "Exception: future already completed";
}


/**
 * [Futures] holds additional utility functions that operate on [Future]s (for
 * example, waiting for a collection of Futures to complete).
 */
class Futures {

  /**
   * Returns a future which will complete once all the futures in a list are
   * complete. If any of the futures in the list completes with an exception,
   * the resulting future also completes with an exception. (The value of the
   * returned future will be a list of all the values that were produced.)
   */
  static Future<List> wait(List<Future> futures) {
    if (futures.isEmpty()) {
      return new Future<List>.immediate(const []);
    }

    Completer completer = new Completer<List>();
    Future<List> result = completer.future;
    int remaining = futures.length;
    List<Object> values = new List(futures.length);

    // As each future completes, put its value into the corresponding
    // position in the list of values.
    for (int i = 0; i < futures.length; i++) {
      // TODO(mattsh) - remove this after bug
      // http://code.google.com/p/dart/issues/detail?id=333 is fixed.
      int pos = i;
      Future future = futures[pos];
      future.then((Object value) {
        values[pos] = value;
        if (--remaining == 0 && !result.isComplete) {
          completer.complete(values);
        }
      });
      future.handleException((exception) {
        if (!result.isComplete) completer.completeException(exception);
        return true;
      });
    }
    return result;
  }
}
