import 'package:equatable/equatable.dart';

/// اقتراح مكان (للبحث التلقائي)
/// 
/// يستخدم في Autocomplete للأماكن
class PlaceSuggestion extends Equatable {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;
  final List<String>? types;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
    this.types,
  });

  @override
  List<Object?> get props => [
        placeId,
        description,
        mainText,
        secondaryText,
        types,
      ];

  PlaceSuggestion copyWith({
    String? placeId,
    String? description,
    String? mainText,
    String? secondaryText,
    List<String>? types,
  }) {
    return PlaceSuggestion(
      placeId: placeId ?? this.placeId,
      description: description ?? this.description,
      mainText: mainText ?? this.mainText,
      secondaryText: secondaryText ?? this.secondaryText,
      types: types ?? this.types,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'description': description,
      'mainText': mainText,
      'secondaryText': secondaryText,
      'types': types,
    };
  }

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: json['placeId'] as String,
      description: json['description'] as String,
      mainText: json['mainText'] as String?,
      secondaryText: json['secondaryText'] as String?,
      types: (json['types'] as List<dynamic>?)?.cast<String>(),
    );
  }

  @override
  String toString() {
    return 'PlaceSuggestion(placeId: $placeId, description: $description)';
  }
}
