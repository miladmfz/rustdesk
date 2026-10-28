import 'dart:math';
import '../lib/common/random_client_id.dart';

void main() {
  final ids = <String>{};
  for (var i = 0; i < 10000; i++) {
    final id = generateRandomClientId();
    if (!RegExp(r'^[a-zA-Z][\w-]{5,15}$').hasMatch(id)) {
      throw StateError('Generated ID violates the server contract');
    }
    if (!ids.add(id)) throw StateError('Duplicate generated ID');
  }
  final a = generateRandomClientId(random: Random(1));
  final b = generateRandomClientId(random: Random(1));
  if (a != b) throw StateError('Deterministic test source ignored');
  print('PASS: 10000 unique valid IDs and deterministic test source');
}
