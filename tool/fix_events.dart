import 'dart:io';

void main() {
  final packagesDir = Directory(r'c:\Users\Ultimate\StudioProjects\erp_scale_sim\packages');
  if (!packagesDir.existsSync()) {
    print('packages dir does not exist');
    return;
  }

  int count = 0;
  for (final entity in packagesDir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart') && entity.path.contains('events')) {
      final content = entity.readAsStringSync();
      if (content.contains('extends Equatable')) {
        var updated = content.replaceAll(
          "import 'package:equatable/equatable.dart';",
          "import 'package:erp_scale_sim/features/common_feature/presentation/controllers/events/feature_event.dart';",
        );
        updated = updated.replaceAll('extends Equatable', 'extends FeatureEvent');
        entity.writeAsStringSync(updated);
        count++;
        print('Updated ${entity.path}');
      }
    }
  }
  print('Total event files updated: $count');
}
