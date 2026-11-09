import 'package:flutter_test/flutter_test.dart';
import 'package:protect_jnu/core/storage/token_store.dart';

void main() {
  const tokens = AuthTokens(accessToken: 'a', refreshToken: 'r', expiresAt: 100);

  test('save then clear updates the in-memory copy', () async {
    final store = TokenStore();
    expect(store.tokens, isNull);
    await store.save(tokens);
    expect(store.accessToken, 'a');
    await store.clear();
    expect(store.tokens, isNull);
  });

  test('tokens never appear in toString or logs', () {
    expect(tokens.toString(), isNot(contains('a,')));
    expect(tokens.toString(), contains('redacted'));
  });

  test('json round trip keeps all three fields', () {
    final back = AuthTokens.fromJson(tokens.toJson());
    expect((back.accessToken, back.refreshToken, back.expiresAt), ('a', 'r', 100));
  });
}
