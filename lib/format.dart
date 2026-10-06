/// Small, dependency-free parsing + formatting helpers.
double? asD(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int asI(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? fallback;
}

String asS(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : <String, dynamic>{};

List<dynamic> asList(dynamic v) => v is List ? v : const [];

String fmtNum(num? v, {int dp = 2}) => v == null ? '—' : v.toStringAsFixed(dp);

String fmtPts(num? v, {int dp = 1}) {
  if (v == null) return '—';
  final s = v.toStringAsFixed(dp);
  return v > 0 ? '+$s' : s;
}

/// Indian digit grouping: 1234567 → 12,34,567
String fmtInr(num? v, {bool sign = false}) {
  if (v == null) return '—';
  final neg = v < 0;
  var digits = v.abs().round().toString();
  if (digits.length > 3) {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    digits = '${parts.join(',')},$last3';
  }
  final prefix = neg ? '−' : (sign && v > 0 ? '+' : '');
  return '$prefix₹$digits';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

DateTime? parseUtc(dynamic iso) {
  if (iso == null) return null;
  return DateTime.tryParse(iso.toString())?.toLocal();
}

String _two(int n) => n.toString().padLeft(2, '0');

String fmtDateTime(dynamic iso) {
  final d = parseUtc(iso);
  if (d == null) return '—';
  return '${d.day} ${_months[d.month - 1]}, ${_two(d.hour)}:${_two(d.minute)}';
}

String fmtDate(dynamic iso) {
  final d = parseUtc(iso);
  if (d == null) return '—';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

String fmtTime(dynamic iso) {
  final d = parseUtc(iso);
  if (d == null) return '—';
  return '${_two(d.hour)}:${_two(d.minute)}';
}

/// "2026-09" → "Sep 2026"
String fmtMonth(String ym) {
  final p = ym.split('-');
  if (p.length != 2) return ym;
  final m = int.tryParse(p[1]) ?? 1;
  return '${_months[(m - 1).clamp(0, 11)]} ${p[0]}';
}

String fmtHold(dynamic entryIso, [dynamic exitIso]) {
  final a = parseUtc(entryIso);
  final b = exitIso == null ? DateTime.now() : parseUtc(exitIso);
  if (a == null || b == null) return '—';
  final m = b.difference(a).inMinutes;
  if (m < 60) return '${m}m';
  return '${m ~/ 60}h ${m % 60}m';
}
