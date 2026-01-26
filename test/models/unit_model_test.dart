import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('UnitCategory', () {
    test('fromString returns correct category', () {
      expect(UnitCategory.fromString('MAIN'), UnitCategory.main);
      expect(UnitCategory.fromString('FLOOR'), UnitCategory.floor);
      expect(UnitCategory.fromString('SECTION'), UnitCategory.section);
      expect(UnitCategory.fromString('ROOM'), UnitCategory.room);
      expect(UnitCategory.fromString('ZONE'), UnitCategory.zone);
      expect(UnitCategory.fromString('PRODUCTION'), UnitCategory.production);
      expect(UnitCategory.fromString('STORAGE'), UnitCategory.storage);
      expect(UnitCategory.fromString('SERVICE'), UnitCategory.service);
      expect(UnitCategory.fromString('COMMON'), UnitCategory.common);
      expect(UnitCategory.fromString('TECHNICAL'), UnitCategory.technical);
      expect(UnitCategory.fromString('OUTDOOR'), UnitCategory.outdoor);
      expect(UnitCategory.fromString('CUSTOM'), UnitCategory.custom);
    });

    test('fromString returns null for invalid value', () {
      expect(UnitCategory.fromString('INVALID'), isNull);
      expect(UnitCategory.fromString(null), isNull);
      expect(UnitCategory.fromString(''), isNull);
    });

    test('value returns correct string', () {
      expect(UnitCategory.main.value, 'MAIN');
      expect(UnitCategory.floor.value, 'FLOOR');
      expect(UnitCategory.room.value, 'ROOM');
    });

    test('label returns Turkish label', () {
      expect(UnitCategory.main.label, 'Ana Alan');
      expect(UnitCategory.floor.label, 'Kat');
      expect(UnitCategory.room.label, 'Oda');
    });
  });

  group('UnitType', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'type-123',
        'name': 'Office Room',
        'code': 'office',
        'description': 'Standard office room',
        'category': 'ROOM',
        'is_main_area': false,
        'is_system_type': true,
        'allowed_site_types': ['office', 'commercial'],
        'active': true,
        'created_at': '2024-01-15T10:00:00Z',
      };

      final unitType = UnitType.fromJson(json);

      expect(unitType.id, 'type-123');
      expect(unitType.name, 'Office Room');
      expect(unitType.code, 'office');
      expect(unitType.description, 'Standard office room');
      expect(unitType.category, UnitCategory.room);
      expect(unitType.isMainArea, false);
      expect(unitType.isSystemType, true);
      expect(unitType.allowedSiteTypes, ['office', 'commercial']);
      expect(unitType.active, true);
      expect(unitType.createdAt, isNotNull);
    });

    test('toJson serializes correctly', () {
      final unitType = UnitType(
        id: 'type-123',
        name: 'Office Room',
        code: 'office',
        category: UnitCategory.room,
        isMainArea: false,
        isSystemType: true,
      );

      final json = unitType.toJson();

      expect(json['id'], 'type-123');
      expect(json['name'], 'Office Room');
      expect(json['code'], 'office');
      expect(json['category'], 'ROOM');
      expect(json['is_main_area'], false);
      expect(json['is_system_type'], true);
    });

    test('categoryIcon returns correct icon name', () {
      final mainType = UnitType(
        id: '1',
        name: 'Main',
        category: UnitCategory.main,
      );
      final floorType = UnitType(
        id: '2',
        name: 'Floor',
        category: UnitCategory.floor,
      );
      final roomType = UnitType(
        id: '3',
        name: 'Room',
        category: UnitCategory.room,
      );

      expect(mainType.categoryIcon, 'home');
      expect(floorType.categoryIcon, 'layers');
      expect(roomType.categoryIcon, 'meeting_room');
    });
  });

  group('Unit', () {
    final testUnit = Unit(
      id: 'unit-123',
      name: 'Test Unit',
      code: 'test-unit',
      description: 'A test unit',
      areaSize: 100.5,
      active: true,
      siteId: 'site-123',
      organizationId: 'org-123',
      tenantId: 'tenant-123',
      isMainArea: false,
      isDeletable: true,
    );

    test('fromJson parses correctly', () {
      final json = {
        'id': 'unit-123',
        'name': 'Test Unit',
        'code': 'test-unit',
        'description': 'A test unit',
        'area_size': 100.5,
        'active': true,
        'parent_unit_id': 'parent-123',
        'site_id': 'site-123',
        'organization_id': 'org-123',
        'tenant_id': 'tenant-123',
        'is_main_area': false,
        'is_deletable': true,
        'working_time_active': false,
        'created_at': '2024-01-15T10:00:00Z',
      };

      final unit = Unit.fromJson(json);

      expect(unit.id, 'unit-123');
      expect(unit.name, 'Test Unit');
      expect(unit.code, 'test-unit');
      expect(unit.description, 'A test unit');
      expect(unit.areaSize, 100.5);
      expect(unit.active, true);
      expect(unit.parentUnitId, 'parent-123');
      expect(unit.siteId, 'site-123');
      expect(unit.organizationId, 'org-123');
      expect(unit.tenantId, 'tenant-123');
      expect(unit.isMainArea, false);
      expect(unit.isDeletable, true);
    });

    test('toJson serializes correctly', () {
      final json = testUnit.toJson();

      expect(json['id'], 'unit-123');
      expect(json['name'], 'Test Unit');
      expect(json['code'], 'test-unit');
      expect(json['area_size'], 100.5);
      expect(json['site_id'], 'site-123');
    });

    test('copyWith creates correct copy', () {
      final copy = testUnit.copyWith(
        name: 'Updated Name',
        areaSize: 200.0,
      );

      expect(copy.id, testUnit.id);
      expect(copy.name, 'Updated Name');
      expect(copy.areaSize, 200.0);
      expect(copy.code, testUnit.code);
      expect(copy.siteId, testUnit.siteId);
    });

    test('isRoot returns true when parentUnitId is null', () {
      final rootUnit = Unit(id: '1', name: 'Root', parentUnitId: null);
      final childUnit = Unit(id: '2', name: 'Child', parentUnitId: '1');

      expect(rootUnit.isRoot, true);
      expect(childUnit.isRoot, false);
    });

    test('hasChildren returns correct value', () {
      final unitWithChildren = Unit(
        id: '1',
        name: 'Parent',
        children: [Unit(id: '2', name: 'Child')],
      );
      final unitWithoutChildren = Unit(id: '1', name: 'Alone');

      expect(unitWithChildren.hasChildren, true);
      expect(unitWithoutChildren.hasChildren, false);
    });

    test('areaSizeFormatted returns correct format', () {
      final unitWithArea = Unit(id: '1', name: 'Test', areaSize: 100.5);
      final unitWithWholeArea = Unit(id: '2', name: 'Test', areaSize: 100.0);
      final unitWithoutArea = Unit(id: '3', name: 'Test', areaSize: null);

      expect(unitWithArea.areaSizeFormatted, '100.5 m²');
      expect(unitWithWholeArea.areaSizeFormatted, '100 m²');
      expect(unitWithoutArea.areaSizeFormatted, '-');
    });

    test('totalAreaWithChildren calculates correctly', () {
      final parent = Unit(
        id: '1',
        name: 'Parent',
        areaSize: 100.0,
        children: [
          Unit(id: '2', name: 'Child 1', areaSize: 50.0),
          Unit(id: '3', name: 'Child 2', areaSize: 30.0),
        ],
      );

      expect(parent.totalAreaWithChildren, 180.0);
    });

    test('totalChildCount calculates correctly', () {
      final parent = Unit(
        id: '1',
        name: 'Parent',
        children: [
          Unit(
            id: '2',
            name: 'Child 1',
            children: [
              Unit(id: '4', name: 'Grandchild 1'),
              Unit(id: '5', name: 'Grandchild 2'),
            ],
          ),
          Unit(id: '3', name: 'Child 2'),
        ],
      );

      expect(parent.totalChildCount, 4);
    });

    test('equality works correctly', () {
      final unit1 = Unit(id: 'unit-1', name: 'Test');
      final unit2 = Unit(id: 'unit-1', name: 'Different Name');
      final unit3 = Unit(id: 'unit-2', name: 'Test');

      expect(unit1, equals(unit2)); // Same ID
      expect(unit1, isNot(equals(unit3))); // Different ID
    });

    test('hashCode is based on id', () {
      final unit1 = Unit(id: 'unit-1', name: 'Test');
      final unit2 = Unit(id: 'unit-1', name: 'Different');

      expect(unit1.hashCode, equals(unit2.hashCode));
    });
  });

  group('UnitTree', () {
    test('fromList builds correct tree structure', () {
      final units = [
        Unit(id: '1', name: 'Root 1'),
        Unit(id: '2', name: 'Root 2'),
        Unit(id: '3', name: 'Child 1', parentUnitId: '1'),
        Unit(id: '4', name: 'Child 2', parentUnitId: '1'),
        Unit(id: '5', name: 'Grandchild', parentUnitId: '3'),
      ];

      final tree = UnitTree.fromList(units);

      expect(tree.rootUnits.length, 2);
      expect(tree.totalCount, 5);
    });

    test('findById returns correct unit', () {
      final units = [
        Unit(id: '1', name: 'Root'),
        Unit(id: '2', name: 'Child', parentUnitId: '1'),
      ];

      final tree = UnitTree.fromList(units);

      expect(tree.findById('1')?.name, 'Root');
      expect(tree.findById('2')?.name, 'Child');
      expect(tree.findById('999'), isNull);
    });

    test('findByCategory returns correct units', () {
      final unitType1 = UnitType(
        id: 't1',
        name: 'Floor Type',
        category: UnitCategory.floor,
      );
      final unitType2 = UnitType(
        id: 't2',
        name: 'Room Type',
        category: UnitCategory.room,
      );

      final units = [
        Unit(id: '1', name: 'Floor 1', unitType: unitType1),
        Unit(id: '2', name: 'Room 1', unitType: unitType2),
        Unit(id: '3', name: 'Floor 2', unitType: unitType1),
      ];

      final tree = UnitTree.fromList(units);
      final floors = tree.findByCategory(UnitCategory.floor);

      expect(floors.length, 2);
      expect(floors.every((u) => u.category == UnitCategory.floor), true);
    });

    test('flatten returns all units in depth-first order', () {
      final units = [
        Unit(id: '1', name: 'A'),
        Unit(id: '2', name: 'B', parentUnitId: '1'),
        Unit(id: '3', name: 'C'),
      ];

      final tree = UnitTree.fromList(units);
      final flat = tree.flatten();

      expect(flat.length, 3);
    });

    test('totalArea calculates correctly', () {
      final units = [
        Unit(id: '1', name: 'Root', areaSize: 100.0),
        Unit(id: '2', name: 'Child 1', parentUnitId: '1', areaSize: 50.0),
        Unit(id: '3', name: 'Child 2', parentUnitId: '1', areaSize: 30.0),
      ];

      final tree = UnitTree.fromList(units);

      // Root'un totalAreaWithChildren'ı = 100 + 50 + 30 = 180
      expect(tree.totalArea, 180.0);
    });
  });
}
