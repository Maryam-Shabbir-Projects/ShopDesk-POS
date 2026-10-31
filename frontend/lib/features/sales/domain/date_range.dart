/// Half-open range: [from, to). Has value equality so it can key a provider.
class DateRange {
  const DateRange(this.from, this.to);
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) => other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}
