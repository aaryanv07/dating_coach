import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MockAuthMethod { apple, google, email }

class MockAuthSession {
  const MockAuthSession({this.method});

  final MockAuthMethod? method;

  bool get isSignedIn => method != null;
}

class MockAuthController extends Notifier<MockAuthSession> {
  @override
  MockAuthSession build() => const MockAuthSession();

  void signIn(MockAuthMethod method) {
    state = MockAuthSession(method: method);
  }

  void signOut() {
    state = const MockAuthSession();
  }
}

final mockAuthProvider = NotifierProvider<MockAuthController, MockAuthSession>(
  MockAuthController.new,
);
