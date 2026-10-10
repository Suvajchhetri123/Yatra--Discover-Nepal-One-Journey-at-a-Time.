import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yatra/services/yatra_local_database.dart';

void main() {
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late YatraLocalDatabase database;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'yatra_local_database_test_',
    );

    database = YatraLocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: p.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await database.close();

    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('stores and reads active catalog records', () async {
    await database.replaceCatalog(
      LocalCatalogKind.place,
      const <LocalCatalogRecord>[
        LocalCatalogRecord(
          kind: LocalCatalogKind.place,
          id: 'ilam-tea-garden',
          payload: <String, dynamic>{'name': 'Tea Garden', 'location': 'Ilam'},
          active: true,
        ),
      ],
    );

    final records = await database.readCatalog(LocalCatalogKind.place);

    expect(records, hasLength(1));
    expect(records.single.id, 'ilam-tea-garden');
    expect(records.single.payload['name'], 'Tea Garden');
    expect(records.single.payload['location'], 'Ilam');
    expect(records.single.active, isTrue);
  });

  test('inactive records are hidden unless explicitly requested', () async {
    await database.replaceCatalog(
      LocalCatalogKind.route,
      const <LocalCatalogRecord>[
        LocalCatalogRecord(
          kind: LocalCatalogKind.route,
          id: 'active-route',
          payload: <String, dynamic>{'destination': 'Ilam'},
          active: true,
        ),
        LocalCatalogRecord(
          kind: LocalCatalogKind.route,
          id: 'inactive-route',
          payload: <String, dynamic>{'destination': 'Mustang'},
          active: false,
        ),
      ],
    );

    final active = await database.readCatalog(LocalCatalogKind.route);

    final all = await database.readCatalog(
      LocalCatalogKind.route,
      includeInactive: true,
    );

    expect(active.map((record) => record.id), <String>['active-route']);

    expect(all, hasLength(2));
  });

  test('replacement removes stale records for that catalog only', () async {
    await database.replaceSnapshot(
      <LocalCatalogKind, Iterable<LocalCatalogRecord>>{
        LocalCatalogKind.place: const <LocalCatalogRecord>[
          LocalCatalogRecord(
            kind: LocalCatalogKind.place,
            id: 'old-place',
            payload: <String, dynamic>{'name': 'Old Place'},
            active: true,
          ),
        ],
        LocalCatalogKind.package: const <LocalCatalogRecord>[
          LocalCatalogRecord(
            kind: LocalCatalogKind.package,
            id: 'package-1',
            payload: <String, dynamic>{'title': 'Package One'},
            active: true,
          ),
        ],
      },
    );

    await database.replaceCatalog(
      LocalCatalogKind.place,
      const <LocalCatalogRecord>[
        LocalCatalogRecord(
          kind: LocalCatalogKind.place,
          id: 'new-place',
          payload: <String, dynamic>{'name': 'New Place'},
          active: true,
        ),
      ],
    );

    final places = await database.readCatalog(LocalCatalogKind.place);

    final packages = await database.readCatalog(LocalCatalogKind.package);

    expect(places.map((record) => record.id), <String>['new-place']);

    expect(packages.map((record) => record.id), <String>['package-1']);
  });

  test('snapshot replacement supports places packages and routes', () async {
    await database.replaceSnapshot(
      <LocalCatalogKind, Iterable<LocalCatalogRecord>>{
        LocalCatalogKind.place: const <LocalCatalogRecord>[
          LocalCatalogRecord(
            kind: LocalCatalogKind.place,
            id: 'place-1',
            payload: <String, dynamic>{'name': 'Place One'},
            active: true,
          ),
        ],
        LocalCatalogKind.package: const <LocalCatalogRecord>[
          LocalCatalogRecord(
            kind: LocalCatalogKind.package,
            id: 'package-1',
            payload: <String, dynamic>{'title': 'Package One'},
            active: true,
          ),
        ],
        LocalCatalogKind.route: const <LocalCatalogRecord>[
          LocalCatalogRecord(
            kind: LocalCatalogKind.route,
            id: 'route-1',
            payload: <String, dynamic>{'from': 'Kathmandu', 'to': 'Birtamod'},
            active: true,
          ),
        ],
      },
    );

    expect(await database.readCatalog(LocalCatalogKind.place), hasLength(1));

    expect(await database.readCatalog(LocalCatalogKind.package), hasLength(1));

    expect(await database.readCatalog(LocalCatalogKind.route), hasLength(1));
  });

  test('sync metadata survives normal database reads', () async {
    const timestamp = '2026-10-10T14:30:00.000Z';

    await database.writeMetadata('lastSuccessfulCatalogSyncUtc', timestamp);

    expect(
      await database.readMetadata('lastSuccessfulCatalogSyncUtc'),
      timestamp,
    );
  });

  test('rejects a record written under the wrong catalog kind', () async {
    await expectLater(
      database
          .replaceCatalog(LocalCatalogKind.place, const <LocalCatalogRecord>[
            LocalCatalogRecord(
              kind: LocalCatalogKind.route,
              id: 'wrong-kind',
              payload: <String, dynamic>{},
              active: true,
            ),
          ]),
      throwsArgumentError,
    );
  });
}
