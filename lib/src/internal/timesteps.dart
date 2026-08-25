enum TimeSteps {
  s1(Duration(seconds: 1), 'HH:mm:ss'),
  s5(Duration(seconds: 5), 'HH:mm:ss'),
  s15(Duration(seconds: 15), 'HH:mm:ss'),
  s30(Duration(seconds: 30), 'HH:mm:ss'),
  m1(Duration(minutes: 1), 'HH:mm'),
  m5(Duration(minutes: 5), 'HH:mm'),
  m15(Duration(minutes: 15), 'HH:mm'),
  m30(Duration(minutes: 30), 'HH:mm'),
  h1(Duration(hours: 1), 'HH:mm'),
  h2(Duration(hours: 2), 'HH:mm'),
  h4(Duration(hours: 4), 'HH:mm'),
  h6(Duration(hours: 6), 'HH:mm'),
  h12(Duration(hours: 12), 'HH:mm'),
  d1(Duration(days: 1), 'dd/MM'),
  d2(Duration(days: 2), 'dd/MM'),
  d4(Duration(days: 4), 'dd/MM'),
  d6(Duration(days: 6), 'dd/MM'),
  d10(Duration(days: 10), 'dd/MM'),
  mo1(Duration(days: 30), 'MMM yyyy'),
  mo2(Duration(days: 60), 'MMM yyyy'),
  mo3(Duration(days: 180), 'MMM yyyy'),
  y1(Duration(days: 365), 'yyyy'),
  y2(Duration(days: 365 * 2), 'yyyy'),
  y6(Duration(days: 365 * 5), 'yyyy'),
  y10(Duration(days: 365 * 10), 'yyyy'),
  y25(Duration(days: 365 * 25), 'yyyy');

  final Duration duration;
  final String format;

  const TimeSteps(this.duration, this.format);
}
