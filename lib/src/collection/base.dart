import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../models/distance_doc_snapshot.dart';
import '../models/point.dart';
import '../utils/math.dart';
import '../utils/arrays.dart';

class BaseGeoFireCollectionRef<T> {
  final Query<T> _collectionReference;
  late final Stream<QuerySnapshot<T>>? _stream;

  BaseGeoFireCollectionRef(this._collectionReference) {
    _stream = _createStream(_collectionReference).shareReplay(maxSize: 1);
  }

  /// return QuerySnapshot stream
  Stream<QuerySnapshot<T>>? snapshot() {
    return _stream;
  }

  /// return the Document mapped to the [id]
  Stream<List<DocumentSnapshot<T>>> data(String id) {
    return _stream!.map((querySnapshot) {
      querySnapshot.docs.where((documentSnapshot) {
        return documentSnapshot.id == id;
      });
      return querySnapshot.docs;
    });
  }

  /// add a document to collection with [data]
  Future<DocumentReference<T>> add(
    T data,
  ) {
    try {
      final CollectionReference<T> colRef =
          _collectionReference as CollectionReference<T>;
      return colRef.add(data);
    } catch (e) {
      throw Exception(
          'cannot call add on Query, use collection reference instead');
    }
  }

  /// delete document with [id] from the collection
  Future<void> delete(id) {
    try {
      final CollectionReference colRef =
          _collectionReference as CollectionReference;
      return colRef.doc(id).delete();
    } catch (e) {
      throw Exception(
          'cannot call delete on Query, use collection reference instead');
    }
  }

  /// create or update a document with [id], [merge] defines whether the document should overwrite
  Future<void> setDoc(String id, Object? data, {bool merge = false}) {
    try {
      final CollectionReference<Object?> colRef =
          _collectionReference as CollectionReference;
      return colRef.doc(id).set(data, SetOptions(merge: merge));
    } catch (e) {
      throw Exception(
          'cannot call set on Query, use collection reference instead');
    }
  }

  /// set a geo point with [latitude] and [longitude] using [field] as the object key to the document with [id]
  Future<void> setPoint(
    String id,
    String field,
    double latitude,
    double longitude,
  ) {
    try {
      final CollectionReference<Object?> colRef =
          _collectionReference as CollectionReference;
      final GeoFirePoint point = GeoFirePoint(latitude, longitude).data;
      return colRef.doc(id).set({field: point}, SetOptions(merge: true));
    } catch (e) {
      throw Exception(
          'cannot call set on Query, use collection reference instead');
    }
  }

  @protected
  Stream<List<DocumentSnapshot<T>>> protectedWithin({
    required GeoFirePoint center,
    required double radius,
    required String field,
    required GeoPoint? Function(T t) geopointFrom,
    required bool? strictMode,
  }) =>
      protectedWithinWithDistance(
        center: center,
        radius: radius,
        field: field,
        geopointFrom: geopointFrom,
        strictMode: strictMode,
      ).map((List<DistanceDocSnapshot<T>> snapshots) {
        return snapshots.map((snapshot) => snapshot.documentSnapshot).toList();
      });

  /// query firestore documents based on geographic [radius] from geoFirePoint [center]
  /// [field] specifies the name of the key in the document
  @protected
  Stream<List<DistanceDocSnapshot<T>>> protectedWithinWithDistance({
    required GeoFirePoint center,
    required double radius,
    required String field,
    required GeoPoint? Function(T t) geopointFrom,
    required bool? strictMode,
  }) {
    final bool nonNullStrictMode = strictMode ?? false;

    final int precision = MathUtils.setPrecision(radius);
    final String centerHash = center.hash.substring(0, precision);
    final List<String> area = GeoFirePoint.neighborsOf(hash: centerHash)
      ..add(centerHash);

    final Iterable<Stream<List<QueryDocumentSnapshot<T>>>> queries =
        area.map((hash) {
      final Query<T> tempQuery = _queryPoint(hash, field);
      return _createStream(tempQuery).map((querySnapshot) {
        return querySnapshot.docs;
      });
    });

    final Stream<List<QueryDocumentSnapshot<T>>> mergedObservable =
        mergeObservable(queries);

    final Stream<List<DistanceDocSnapshot<T>>> filtered =
        mergedObservable.map((list) {
      final Iterable<DistanceDocSnapshot<T>?> mappedList =
          list.map((documentSnapshot) {
        final T? snapData =
            documentSnapshot.exists ? documentSnapshot.data() : null;

        assert(snapData != null, 'Data in one of the docs is empty');
        if (snapData == null) return null;
        // We will handle it to fail gracefully

        final GeoPoint? geoPoint = geopointFrom(snapData);
        assert(geoPoint != null, 'Couldnt find geopoint from stored data');
        if (geoPoint == null) return null;
        // We will handle it to fail gracefully

        final double kmDistance = center.kmDistance(
          lat: geoPoint.latitude,
          lng: geoPoint.longitude,
        );
        return DistanceDocSnapshot(
          documentSnapshot: documentSnapshot,
          kmDistance: kmDistance,
        );
      });

      final List<DistanceDocSnapshot<T>?> nullableFilteredList =
          nonNullStrictMode
              ? mappedList
                  .where((doc) =>
                          doc != null &&
                          doc.kmDistance <=
                              radius * 1.02 // buffer for edge distances;
                      )
                  .toList()
              : mappedList.toList();
      final List<DistanceDocSnapshot<T>> filteredList =
          nullableFilteredList.whereNotNull().toList();

      filteredList.sort(
        (a, b) => (a.kmDistance * 1000).toInt() - (b.kmDistance * 1000).toInt(),
      );
      return filteredList;
    });
    return filtered.asBroadcastStream();
  }

  Stream<List<QueryDocumentSnapshot<T>>> mergeObservable(
    Iterable<Stream<List<QueryDocumentSnapshot<T>>>> queries,
  ) {
    final Stream<List<QueryDocumentSnapshot<T>>> mergedObservable =
        Rx.combineLatest<List<QueryDocumentSnapshot<T>>,
            List<QueryDocumentSnapshot<T>>>(queries, (originalList) {
      final List<QueryDocumentSnapshot<T>> reducedList =
          <QueryDocumentSnapshot<T>>[];
      for (final t in originalList) {
        reducedList.addAll(t);
      }
      return reducedList;
    });
    return mergedObservable;
  }

  /// INTERNAL FUNCTIONS

  /// construct a query for the [geoHash] and [field]
  Query<T> _queryPoint(String geoHash, String field) {
    final String end = '$geoHash~';
    final Query<T> temp = _collectionReference;
    return temp.orderBy('$field.geohash').startAt([geoHash]).endAt([end]);
  }

  /// create an observable for [ref], [ref] can be [Query] or [CollectionReference]
  Stream<QuerySnapshot<T>> _createStream(Query<T> ref) {
    return ref.snapshots();
  }
}
