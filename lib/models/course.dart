class Course {
  final String id;
  final String title;
  final String description;
  final String instructorName;
  final String category;
  final String thumbnailUrl;
  final double price;
  final double rating;
  final int studentsCount;
  final int lessonsCount;
  final String durationLabel;
  final List<String> features;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.instructorName,
    required this.category,
    required this.thumbnailUrl,
    required this.price,
    required this.rating,
    required this.studentsCount,
    required this.lessonsCount,
    required this.durationLabel,
    required this.features,
  });

  /// Builds a Course from a Firestore `courses/{courseId}` document.
  /// Matches the collection referenced in the project's data model:
  /// Courses, Lessons, Purchases, Progress, Payments, Sessions, Notifications.
  factory Course.fromMap(String id, Map<String, dynamic> map) {
    return Course(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      instructorName: map['instructorName'] ?? '',
      category: map['category'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      rating: (map['rating'] ?? 0).toDouble(),
      studentsCount: (map['studentsCount'] ?? 0) as int,
      lessonsCount: (map['lessonsCount'] ?? 0) as int,
      durationLabel: map['durationLabel'] ?? '',
      features: List<String>.from(map['features'] ?? const []),
    );
  }
}
