import 'dart:math' as math;

/// Black-Scholes greeks computed on the phone from the IV the server already
/// sends per strike — a straight port of the web app's maths.
const double kRiskFree = 0.065;

double _erf(double x) {
  final sign = x < 0 ? -1.0 : 1.0;
  x = x.abs();
  const a1 = 0.254829592, a2 = -0.284496736, a3 = 1.421413741, a4 = -1.453152027, a5 = 1.061405429, p = 0.3275911;
  final t = 1 / (1 + p * x);
  final y = 1 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-x * x);
  return sign * y;
}

double _cdf(double x) => 0.5 * (1 + _erf(x / math.sqrt2));
double _pdf(double x) => math.exp(-x * x / 2) / math.sqrt(2 * math.pi);

/// Days until 15:30 IST on the expiry date ("YYYY-MM-DD"), floored so expiry day doesn't divide by ~0.
double daysToExpiry(String expiry) {
  final d = DateTime.tryParse(expiry.length == 10 ? '${expiry}T15:30:00+05:30' : expiry);
  if (d == null) return 1;
  return math.max(0.15, d.difference(DateTime.now()).inMinutes / 1440);
}

class Greeks {
  final double delta, gamma, theta;
  const Greeks(this.delta, this.gamma, this.theta);
}

Greeks? blackScholes({required double spot, required double strike, required double ivPct, required bool isCall, required String expiry}) {
  final t = daysToExpiry(expiry) / 365, sig = ivPct / 100;
  if (spot <= 0 || strike <= 0 || sig <= 0 || t <= 0) return null;
  final d1 = (math.log(spot / strike) + (kRiskFree + sig * sig / 2) * t) / (sig * math.sqrt(t));
  final d2 = d1 - sig * math.sqrt(t);
  final pd1 = _pdf(d1);
  final disc = kRiskFree * strike * math.exp(-kRiskFree * t);
  final decay = -(spot * pd1 * sig) / (2 * math.sqrt(t));
  final delta = isCall ? _cdf(d1) : _cdf(d1) - 1;
  final theta = (isCall ? decay - disc * _cdf(d2) : decay + disc * _cdf(-d2)) / 365;
  final gamma = pd1 / (spot * sig * math.sqrt(t));
  return Greeks(delta, gamma, theta);
}
