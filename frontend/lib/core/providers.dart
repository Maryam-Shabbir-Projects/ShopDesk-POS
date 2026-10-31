import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopdesk/core/db/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);
