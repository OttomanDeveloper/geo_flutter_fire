// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/math.dart';

@immutable
class GeoFirePoint {
  static final MathUtils _util = MathUtils();
  final double latitude, longitude;

  const GeoFirePoint(this.latitude, this.longitude);

  /// return geographical distance between two Co-ordinates
  static double kmDistanceBetween(
      {required Coordinates to, required Coordinates from}) {
    return MathUtils.kmDistance(to, from);
  }

  /// return neighboring geo-hashes of [hash]
  static List<String> neighborsOf({required String hash}) {
    return _util.neighbors(hash);
  }

  /// return hash of [GeoFirePoint]
  String get hash {
    return _util.encode(latitude, longitude, 9);
  }

  /// return all neighbors of [GeoFirePoint]
  List<String> get neighbors {
    return _util.neighbors(hash);
  }

  /// return [GeoPoint] of [GeoFirePoint]
  GeoPoint get geoPoint {
    return GeoPoint(latitude, longitude);
  }

  Coordinates get coords {
    return Coordinates(latitude, longitude);
  }

  /// return distance between [GeoFirePoint] and ([lat], [lng])
  double kmDistance({required double lat, required double lng}) {
    return kmDistanceBetween(from: coords, to: Coordinates(lat, lng));
  }

  get data {
    return {'geopoint': geoPoint, 'geohash': hash};
  }

  /// haversine distance between [GeoFirePoint] and ([lat], [lng])
  haversineDistance({required double lat, required double lng}) {
    return GeoFirePoint.kmDistanceBetween(
      from: coords,
      to: Coordinates(lat, lng),
    );
  }
}

@immutable
class Coordinates {
  final double latitude;
  final double longitude;
  const Coordinates(this.latitude, this.longitude);

  @override
  bool operator ==(covariant Coordinates other) {
    if (identical(this, other)) return true;

    return other.latitude == latitude && other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() =>
      'Coordinates(latitude: $latitude, longitude: $longitude)';
}
