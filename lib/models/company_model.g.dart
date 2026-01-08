// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Company _$CompanyFromJson(Map<String, dynamic> json) => Company(
  id: json['id'] as String,
  name: json['name'] as String,
  folderId: json['folderId'] as String,
  logoUrl: json['logoUrl'] as String?,
  role: json['role'] as String?,
);

Map<String, dynamic> _$CompanyToJson(Company instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'folderId': instance.folderId,
  'logoUrl': instance.logoUrl,
  'role': instance.role,
};
