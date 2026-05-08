import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grow_together/shared/utils/plan_icon_mapper.dart';

void main() {
  setUp(() {
    PlanIconMapper.clearCustomOptions();
  });

  test('removeCustomOption deletes an existing custom icon', () {
    // Arrange: add a custom icon
    final key = PlanIconMapper.addCustomOption(
      label: '考研',
      icon: Icons.star_rounded,
      color: Colors.purple,
      backgroundColor: Colors.purple.shade50,
    );
    expect(PlanIconMapper.customOptions.any((o) => o.key == key), isTrue);

    // Act: remove it
    final removed = PlanIconMapper.removeCustomOption(key);

    // Assert
    expect(removed, isTrue);
    expect(PlanIconMapper.customOptions.any((o) => o.key == key), isFalse);
  });

  test('removeCustomOption returns false for non-existent key', () {
    final removed = PlanIconMapper.removeCustomOption('non_existent_key');
    expect(removed, isFalse);
  });

  test('removeCustomOption does not affect preset icons', () {
    final initialPresets = PlanIconMapper.presetOptions.length;

    PlanIconMapper.removeCustomOption('book');

    expect(PlanIconMapper.presetOptions.length, initialPresets);
    expect(PlanIconMapper.optionOf('book').label, '学习');
  });

  test('addCustomOption generates unique keys after deletion', () {
    final key1 = PlanIconMapper.addCustomOption(
      label: 'A',
      icon: Icons.star_rounded,
      color: Colors.purple,
      backgroundColor: Colors.purple.shade50,
    );
    PlanIconMapper.removeCustomOption(key1);

    final key2 = PlanIconMapper.addCustomOption(
      label: 'B',
      icon: Icons.favorite_rounded,
      color: Colors.red,
      backgroundColor: Colors.red.shade50,
    );

    expect(key1, isNot(key2));
    expect(PlanIconMapper.customOptions.length, 1);
  });
}
