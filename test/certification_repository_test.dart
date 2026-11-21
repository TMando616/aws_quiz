import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aws_quiz/data/certification_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('取得済みの印をつけたり外したりできる', () async {
    final repo = CertificationRepository();
    expect(await repo.load(), isEmpty);

    await repo.set('saa', true);
    await repo.set('clf', true);
    expect((await repo.load()).keys, unorderedEquals(['saa', 'clf']));

    await repo.set('saa', false);
    expect((await repo.load()).keys, ['clf']);
  });
}
