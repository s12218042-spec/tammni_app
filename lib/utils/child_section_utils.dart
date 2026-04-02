class ChildSectionResult {
  final int ageInYears;
  final String section;
  final String suggestedGroup;

  const ChildSectionResult({
    required this.ageInYears,
    required this.section,
    required this.suggestedGroup,
  });
}

class ChildSectionUtils {
  static int calculateAgeInYears(DateTime birthDate) {
    final now = DateTime.now();

    int age = now.year - birthDate.year;

    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  static ChildSectionResult resolveSectionAndGroup(DateTime? birthDate) {
    if (birthDate == null) {
      return const ChildSectionResult(
        ageInYears: 0,
        section: 'Nursery',
        suggestedGroup: '',
      );
    }

    final age = calculateAgeInYears(birthDate);

    if (age < 5) {
      return const ChildSectionResult(
        ageInYears: 0,
        section: 'Nursery',
        suggestedGroup: '',
      ).copyWithAge(age);
    }

    if (age == 5) {
      return const ChildSectionResult(
        ageInYears: 0,
        section: 'Kindergarten',
        suggestedGroup: '',
      ).copyWithAge(age);
    }

    return ChildSectionResult(
      ageInYears: age,
      section: 'OutOfRange',
      suggestedGroup: '',
    );
  }

  static String sectionArabicLabel(String section) {
    switch (section) {
      case 'Kindergarten':
        return 'روضة';
      case 'OutOfRange':
        return 'خارج نطاق التطبيق';
      case 'Nursery':
      default:
        return 'حضانة';
    }
  }

  static bool shouldShowGroupField(String section) {
    return section == 'Nursery' || section == 'Kindergarten';
  }
}

extension on ChildSectionResult {
  ChildSectionResult copyWithAge(int age) {
    return ChildSectionResult(
      ageInYears: age,
      section: section,
      suggestedGroup: suggestedGroup,
    );
  }
}