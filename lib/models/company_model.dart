import 'package:json_annotation/json_annotation.dart';

part 'company_model.g.dart';

@JsonSerializable()
class Company {
  final String id;
  final String name;
  final String folderId;
  final String? userAccessFolderId;
  final String? logoUrl;
  final String? role;

  Company({
    required this.id,
    required this.name,
    required this.folderId,
    this.userAccessFolderId,
    this.logoUrl,
    this.role,
  });

  factory Company.fromJson(Map<String, dynamic> json) => _$CompanyFromJson(json);
  Map<String, dynamic> toJson() => _$CompanyToJson(this);
}
