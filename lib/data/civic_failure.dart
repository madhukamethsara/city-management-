/// A safe, actionable message that does not expose server details.
class CivicFailure implements Exception {
  const CivicFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
