import 'dart:math';

// Letter-prefixed IDs satisfy the rendezvous server's custom-ID contract.
String generateRandomClientId({Random? random}) {
  final source = random ?? Random.secure();
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return 'k${List.generate(15, (_) => alphabet[source.nextInt(alphabet.length)]).join()}';
}
