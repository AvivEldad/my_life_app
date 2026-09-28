// Test-only Firestore doubles exercise failure and retry boundaries.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_todo_app/models/habit_item.dart';
import 'package:my_todo_app/services/gamification_service.dart';

// Buffered transactions allow us to simulate retries and failed commits.
class MemoryStore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  Completer<void>? readGate;
  bool failRead = false;
  bool failCommit = false;
  bool retry = false;
  int commits = 0;
  int directWrites = 0;
  Future<void> tail = Future.value();

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      MemoryCollection(this, path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    final result = tail.then((_) async {
      if (retry) await handler(MemoryTransaction(this));
      final transaction = MemoryTransaction(this);
      final value = await handler(transaction);
      if (failCommit) throw StateError('commit failed');
      for (final entry in transaction.writes.entries) {
        documents.putIfAbsent(entry.key, () => {}).addAll(entry.value);
      }
      commits++;
      return value;
    });
    tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }
}

class MemoryCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final MemoryStore store;
  final String location;
  MemoryCollection(this.store, this.location);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      MemoryDocument(store, '$location/$path');
}

class MemoryDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final MemoryStore store;
  @override
  final String path;
  MemoryDocument(this.store, this.path);
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    expect(options?.source, Source.server);
    if (store.readGate != null) await store.readGate!.future;
    if (store.failRead) throw StateError('read failed');
    return MemorySnapshot(store.documents[path]);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    store.directWrites++;
    store.documents.putIfAbsent(path, () => {}).addAll(data);
  }
}

class MemorySnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? value;
  MemorySnapshot(Map<String, dynamic>? data)
    : value = data == null ? null : Map.of(data);
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
}

class MemoryTransaction extends Fake implements Transaction {
  final MemoryStore store;
  final writes = <String, Map<String, dynamic>>{};
  MemoryTransaction(this.store);
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async => MemorySnapshot(store.documents[ref.path]) as DocumentSnapshot<T>;
  @override
  Transaction update(DocumentReference ref, Map<String, dynamic> data) {
    writes.putIfAbsent(ref.path, () => {}).addAll(data);
    return this;
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) =>
      update(ref, data as Map<String, dynamic>);
}

void main() {
  const statsPath = 'gamification/user_stats';
  late MemoryStore store;
  setUp(() {
    store = MemoryStore();
    store.documents[statsPath] = {
      'currentCoins': 80.0,
      'currentXp': 70,
      'currentLevel': 4,
      'totalXpEarned': 400,
      'unlockedPokemons': [1, 2],
    };
    final now = DateTime.now();
    store.documents['habits/habit'] = HabitItem(
      id: 'habit',
      summary: 'Habit',
      recurrence: HabitRecurrence.daily,
      reminderTime: const TimeOfDay(hour: 9, minute: 0),
      nextDueDate: DateTime(now.year, now.month, now.day - 30, 9),
      currentStreak: 6,
    ).toMap();
  });

  test(
    'penalty waits for startup read, then charges only one missed occurrence',
    () async {
      store.readGate = Completer<void>();
      final service = GamificationService(
        firestore: store,
        refreshCoinReminder: (_) async {},
      );
      final pending = service.processMissedHabit('habit');
      await Future<void>.delayed(Duration.zero);
      expect(store.commits, 0);
      expect(store.directWrites, 0);
      store.readGate!.complete();
      final habit = await pending;
      expect(store.documents[statsPath]!['currentCoins'], 79.5);
      expect(service.currentXp, 68);
      expect(service.currentLevel, 4);
      expect(service.totalXpEarned, 400);
      expect(service.unlockedPokemons, [1, 2]);
      expect(habit!.currentStreak, 0);
      expect(habit.missDeadline.isAfter(DateTime.now()), isTrue);
    },
  );

  test(
    'failed startup read never writes default stats; later retry recovers',
    () async {
      store.failRead = true;
      final service = GamificationService(
        firestore: store,
        refreshCoinReminder: (_) async {},
      );
      await expectLater(service.processMissedHabit('habit'), throwsStateError);
      expect(store.directWrites, 0);
      expect(store.commits, 0);
      expect(store.documents[statsPath]!['currentCoins'], 80);
      store.failRead = false;
      await service.processMissedHabit('habit');
      expect(service.currentCoins, 79.5);
    },
  );

  test(
    'transaction retries and two services do not charge the same miss twice',
    () async {
      store.retry = true;
      final first = GamificationService(
        firestore: store,
        refreshCoinReminder: (_) async {},
      );
      final second = GamificationService(
        firestore: store,
        refreshCoinReminder: (_) async {},
      );
      await Future.wait([
        first.processMissedHabit('habit'),
        second.processMissedHabit('habit'),
        first.processMissedHabit('habit'),
      ]);
      expect(store.documents[statsPath]!['currentCoins'], 79.5);
      expect(store.documents[statsPath]!['currentXp'], 68);
    },
  );

  test(
    'failed transaction commits neither deduction nor occurrence advancement',
    () async {
      store.failCommit = true;
      final before = Map.of(store.documents['habits/habit']!);
      final service = GamificationService(
        firestore: store,
        refreshCoinReminder: (_) async {},
      );
      await expectLater(service.processMissedHabit('habit'), throwsStateError);
      expect(store.documents['habits/habit'], before);
      expect(store.documents[statsPath]!['currentCoins'], 80);
      store.failCommit = false;
      await service.processMissedHabit('habit');
      expect(service.currentCoins, 79.5);
    },
  );
}
