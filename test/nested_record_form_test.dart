import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/table_field.dart';

void main(){
 testWidgets('nested contact dialog fits a narrow screen and returns structured data',(tester)async{
  tester.view.physicalSize=const Size(320,640);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  List<Map<String,dynamic>> rows=[];
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:StatefulBuilder(builder:(context,set)=>DynamicTableField(column:FieldDefinition(key:'phone_nos',label:'Phone Number(s)',type:'table',fields:[FieldDefinition(key:'phone',label:'Phone',type:'phone',isRequired:true)]),value:rows,primaryColor:Colors.green,onChanged:(value)=>set(()=>rows=value))))));
  await tester.tap(find.text('Add'));await tester.pumpAndSettle();expect(tester.takeException(),isNull);
  await tester.enterText(find.byType(TextFormField),'5550100123');await tester.tap(find.widgetWithText(ElevatedButton,'Add'));await tester.pumpAndSettle();expect(rows,[{'phone':'5550100123'}]);expect(tester.takeException(),isNull);
 });
}
