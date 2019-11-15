// Copyright (c) 2015, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:built_collection/built_collection.dart';
import 'package:built_value/serializer.dart';

class BuiltSortedListSerializer implements StructuredSerializer<BuiltSortedList> {
  final bool structured = true;
  @override
  final Iterable<Type> types =
  BuiltSortedList<Type>(null, [BuiltSortedList, BuiltSortedList<Object>(null).runtimeType]);
  @override
  final String wireName = 'sortedList';

  @override
  Iterable serialize(Serializers serializers, BuiltSortedList builtSortedList,
      {FullType specifiedType = FullType.unspecified}) {
    var isUnderspecified =
        specifiedType.isUnspecified || specifiedType.parameters.isEmpty;
    if (!isUnderspecified) serializers.expectBuilder(specifiedType);

    var elementType = specifiedType.parameters.isEmpty
        ? FullType.unspecified
        : specifiedType.parameters[0];

    return builtSortedList
        .map((item) => serializers.serialize(item, specifiedType: elementType));
  }

  @override
  BuiltSortedList deserialize(Serializers serializers, Iterable serialized,
      {FullType specifiedType = FullType.unspecified}) {
    var isUnderspecified =
        specifiedType.isUnspecified || specifiedType.parameters.isEmpty;

    var elementType = specifiedType.parameters.isEmpty
        ? FullType.unspecified
        : specifiedType.parameters[0];

    SortedListBuilder result = isUnderspecified
        ? SortedListBuilder<Object>()
        : serializers.newBuilder(specifiedType) as SortedListBuilder;

    result.replace(serialized.map(
            (item) => serializers.deserialize(item, specifiedType: elementType)));
    return result.build();
  }
}
