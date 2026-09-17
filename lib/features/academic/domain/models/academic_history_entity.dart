import 'academic_year_entity.dart';
import 'academic_period_entity.dart';

/// Aggregates an academic period with metadata such as its subject count.
class AcademicPeriodWithCount {
  final AcademicPeriodEntity period;
  final int subjectCount;

  const AcademicPeriodWithCount({
    required this.period,
    this.subjectCount = 0,
  });
}

/// Aggregates an academic year with all its associated academic periods.
class AcademicYearWithPeriods {
  final AcademicYearEntity year;
  final List<AcademicPeriodWithCount> periods;

  const AcademicYearWithPeriods({
    required this.year,
    required this.periods,
  });
}
