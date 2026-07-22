import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_life_list/models/life_list_entry.dart';
import 'package:the_life_list/services/life_list_service.dart';

LifeListEntry _entry({
  required String speciesCode,
  required String comName,
  required DateTime dateAdded,
}) {
  return LifeListEntry(
    speciesCode: speciesCode,
    comName: comName,
    sciName: 'Sci $comName',
    count: 1,
    locName: 'Test Loc',
    lat: 41.0,
    lng: -73.0,
    dateSeen: dateAdded,
    dateAdded: dateAdded,
  );
}

void main() {
  late LifeListService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = LifeListService();
  });

  test('getAll on empty storage returns []', () async {
    expect(await service.getAll(), isEmpty);
  });

  test('add then getAll returns the entry', () async {
    final entry = _entry(
      speciesCode: 'amecro',
      comName: 'American Crow',
      dateAdded: DateTime.utc(2026, 1, 1),
    );
    await service.add(entry);

    final all = await service.getAll();
    expect(all, hasLength(1));
    expect(all.single.speciesCode, 'amecro');
    expect(all.single.comName, 'American Crow');
  });

  test('adding the same speciesCode twice replaces rather than duplicates',
      () async {
    await service.add(_entry(
      speciesCode: 'amecro',
      comName: 'American Crow',
      dateAdded: DateTime.utc(2026, 1, 1),
    ));
    await service.add(_entry(
      speciesCode: 'amecro',
      comName: 'American Crow (updated)',
      dateAdded: DateTime.utc(2026, 2, 1),
    ));

    final all = await service.getAll();
    expect(all, hasLength(1));
    expect(all.single.comName, 'American Crow (updated)');
  });

  test('getAll returns entries sorted by dateAdded descending', () async {
    await service.add(_entry(
      speciesCode: 'oldr',
      comName: 'Older',
      dateAdded: DateTime.utc(2026, 1, 1),
    ));
    await service.add(_entry(
      speciesCode: 'newr',
      comName: 'Newer',
      dateAdded: DateTime.utc(2026, 3, 1),
    ));
    await service.add(_entry(
      speciesCode: 'midr',
      comName: 'Middle',
      dateAdded: DateTime.utc(2026, 2, 1),
    ));

    final all = await service.getAll();
    expect(all.map((e) => e.speciesCode).toList(), ['newr', 'midr', 'oldr']);
  });

  test('remove removes only the matching speciesCode', () async {
    await service.add(_entry(
      speciesCode: 'amecro',
      comName: 'American Crow',
      dateAdded: DateTime.utc(2026, 1, 1),
    ));
    await service.add(_entry(
      speciesCode: 'blujay',
      comName: 'Blue Jay',
      dateAdded: DateTime.utc(2026, 1, 2),
    ));

    await service.remove('amecro');

    final all = await service.getAll();
    expect(all, hasLength(1));
    expect(all.single.speciesCode, 'blujay');
  });

  test('isLogged reflects add and remove', () async {
    expect(await service.isLogged('amecro'), isFalse);

    await service.add(_entry(
      speciesCode: 'amecro',
      comName: 'American Crow',
      dateAdded: DateTime.utc(2026, 1, 1),
    ));
    expect(await service.isLogged('amecro'), isTrue);

    await service.remove('amecro');
    expect(await service.isLogged('amecro'), isFalse);
  });
}
