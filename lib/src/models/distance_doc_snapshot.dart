import 'package:cloud_firestore/cloud_firestore.dart';

class DistanceDocSnapshot<T> {
  final DocumentSnapshot<T> documentSnapshot;
  final double kmDistance;

  DistanceDocSnapshot({
    required this.documentSnapshot,
    required this.kmDistance,
  });

  @override
  bool operator ==(covariant DistanceDocSnapshot<T> other) {
    if (identical(this, other)) return true;

    return other.documentSnapshot == documentSnapshot &&
        other.kmDistance == kmDistance;
  }

  @override
  int get hashCode => documentSnapshot.hashCode ^ kmDistance.hashCode;

  @override
  String toString() =>
      'DistanceDocSnapshot(documentSnapshot: $documentSnapshot, kmDistance: $kmDistance)';
}
