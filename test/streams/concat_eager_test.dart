import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

List<Stream<int>> _getStreams() {
  var a = new Stream.fromIterable(const [0, 1, 2]),
      b = new Stream.fromIterable(const [3, 4, 5]);

  return [a, b];
}

List<Stream<int>> _getStreamsIncludingEmpty() {
  var a = new Stream.fromIterable(const [0, 1, 2]),
      b = new Stream.fromIterable(const [3, 4, 5]),
      c = new Observable<int>.empty();

  return [c, a, b];
}

void main() {
  test('rx.Observable.concatEager', () async {
    const expectedOutput = [0, 1, 2, 3, 4, 5];
    var count = 0;

    final observable = new Observable.concatEager(_getStreams());

    observable.listen(expectAsync1((result) {
      // test to see if the combined output matches
      expect(result, expectedOutput[count++]);
    }, count: expectedOutput.length));
  });

  test('rx.Observable.concatEager.single.subscription', () async {
    final observable = new Observable.concatEager(_getStreams());

    observable.listen(null);
    await expectLater(() => observable.listen((_) {}), throwsA(isStateError));
  });

  test('rx.Observable.concatEager.withEmptyStream', () async {
    const expectedOutput = [0, 1, 2, 3, 4, 5];
    var count = 0;

    final observable = new Observable.concatEager(_getStreamsIncludingEmpty());

    observable.listen(expectAsync1((result) {
      // test to see if the combined output matches
      expect(result, expectedOutput[count++]);
    }, count: expectedOutput.length));
  });

  test('rx.Observable.concatEager.withBroadcastStreams', () async {
    const expectedOutput = [1, 2, 3, 4, 99, 98, 97, 96, 999, 998, 997];
    final ctrlA = new StreamController<int>.broadcast(),
        ctrlB = new StreamController<int>.broadcast(),
        ctrlC = new StreamController<int>.broadcast();
    var x = 0, y = 100, z = 1000, count = 0;

    new Timer.periodic(const Duration(milliseconds: 10), (_) {
      ctrlA.add(++x);
      ctrlB.add(--y);

      if (x <= 3) ctrlC.add(--z);

      if (x == 3) ctrlC.close();

      if (x == 4) {
        _.cancel();

        ctrlA.close();
        ctrlB.close();
      }
    });

    final observable =
        new Observable.concatEager([ctrlA.stream, ctrlB.stream, ctrlC.stream]);

    observable.listen(expectAsync1((result) {
      // test to see if the combined output matches
      expect(result, expectedOutput[count++]);
    }, count: expectedOutput.length));
  });

  test('rx.Observable.concatEager.asBroadcastStream', () async {
    final observable =
        new Observable.concatEager(_getStreams()).asBroadcastStream();

    // listen twice on same stream
    observable.listen(null);
    observable.listen(null);
    // code should reach here
    await expectLater(observable.isBroadcast, isTrue);
  });

  test('rx.Observable.concatEager.error.shouldThrowA', () async {
    final observableWithError = new Observable.concatEager(
        _getStreams()..add(new ErrorStream<int>(new Exception())));

    observableWithError.listen(null,
        onError: expectAsync2((Exception e, StackTrace s) {
      expect(e, isException);
    }));
  });

  test('rx.Observable.concatEager.error.shouldThrowB', () {
    expect(() => new Observable<int>.concatEager(null), throwsArgumentError);
  });

  test('rx.Observable.concatEager.error.shouldThrowC', () {
    expect(
        () => new Observable<int>.concatEager(const []), throwsArgumentError);
  });

  test('rx.Observable.concatEager.error.shouldThrowD', () {
    expect(() => new Observable.concatEager([new Observable.just(1), null]),
        throwsArgumentError);
  });

  test('rx.Observable.concatEager.pause.resume', () async {
    final first = new Stream.periodic(const Duration(milliseconds: 10),
            (index) => const [1, 2, 3, 4][index]),
        second = new Stream.periodic(const Duration(milliseconds: 10),
            (index) => const [5, 6, 7, 8][index]),
        last = new Stream.periodic(const Duration(milliseconds: 10),
            (index) => const [9, 10, 11, 12][index]);

    StreamSubscription<num> subscription;
    // ignore: deprecated_member_use
    subscription = new Observable.concatEager([first, second, last])
        .listen(expectAsync1((value) {
      expect(value, 1);

      subscription.cancel();
    }, count: 1));

    subscription
        .pause(new Future<Null>.delayed(const Duration(milliseconds: 80)));
  });
}
