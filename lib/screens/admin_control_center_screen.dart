import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class AdminControlCenterScreen extends StatefulWidget { const AdminControlCenterScreen({super.key}); @override State<AdminControlCenterScreen> createState()=>_AdminControlCenterScreenState(); }
class _AdminControlCenterScreenState extends State<AdminControlCenterScreen> {
  int tab=0;
  final db=FirebaseFirestore.instance;
  final fn=FirebaseFunctions.instanceFor(region:'us-central1');
  Future<void> _ban(String uid) async { final reason=TextEditingController(); int days=7; final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('حظر المستخدم'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:reason,decoration:const InputDecoration(labelText:'سبب الحظر')),const SizedBox(height:10),TextField(decoration:const InputDecoration(labelText:'عدد الأيام'),keyboardType:TextInputType.number,onChanged:(v)=>days=int.tryParse(v)??7)]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('حظر'))])); if(ok!=true||reason.text.trim().isEmpty)return; await fn.httpsCallable('setUserBan').call({'uid':uid,'reason':reason.text.trim(),'days':days}); if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم حظر المستخدم'))); }
  Future<void> _notify() async { final title=TextEditingController(), body=TextEditingController(), image=TextEditingController(), campaign=TextEditingController(), description=TextEditingController(); DateTime when=DateTime.now().add(const Duration(minutes:5)); final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('إشعار مجدول'),content:SingleChildScrollView(child:Column(children:[TextField(controller:title,decoration:const InputDecoration(labelText:'العنوان')),TextField(controller:body,decoration:const InputDecoration(labelText:'الرسالة')),TextField(controller:image,decoration:const InputDecoration(labelText:'رابط الصورة (اختياري)')),TextField(controller:campaign,decoration:const InputDecoration(labelText:'اسم الحملة (اختياري)')),TextField(controller:description,decoration:const InputDecoration(labelText:'الوصف (اختياري)')),const SizedBox(height:8),ListTile(title:Text('وقت الإرسال: ${when.toLocal()}'),trailing:const Icon(Icons.schedule),onTap:()async{final d=await showDatePicker(context:context,initialDate:when,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));if(d==null)return;final t=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(when));if(t!=null)when=DateTime(d.year,d.month,d.day,t.hour,t.minute);})])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('جدولة'))])); if(ok!=true||title.text.trim().isEmpty||body.text.trim().isEmpty)return; await fn.httpsCallable('scheduleNotification').call({'title':title.text.trim(),'body':body.text.trim(),'imageUrl':image.text.trim(),'campaign':campaign.text.trim(),'description':description.text.trim(),'sendAt':when.toUtc().toIso8601String(),'audience':'all'}); if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تمت جدولة الإشعار'))); }
  Future<void> _admin() async { final email=TextEditingController(),password=TextEditingController(),name=TextEditingController(); final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('إضافة حساب أدمن'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم')),TextField(controller:email,decoration:const InputDecoration(labelText:'البريد الإلكتروني')),TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'كلمة المرور'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('إنشاء'))])); if(ok!=true)return; await fn.httpsCallable('createAdminAccount').call({'email':email.text.trim(),'password':password.text,'name':name.text.trim()}); if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم إنشاء حساب الأدمن'))); }
  @override Widget build(BuildContext context){return Scaffold(appBar:AppBar(title:const Text('لوحة التحكم الكاملة')),body:Column(children:[SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[_tab('المحاضرات',0),_tab('مراجعة الكورسات',1),_tab('المفهّمين',2),_tab('المستخدمون',3),_tab('الإشعارات',4),_tab('الأدمن',5)])),Expanded(child:[_meetings(),_courses(),_mufahems(),_users(),_notifications(),_admins()][tab]) ]));}
  Widget _tab(String t,int i)=>Padding(padding:const EdgeInsets.all(6),child:ChoiceChip(label:Text(t),selected:tab==i,onSelected:(_){setState(()=>tab=i);}));
  Widget _meetings()=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:db.collection('istifhams').where('status',whereIn:['paid','completed']).snapshots(),builder:(c,s)=>ListView(children:(s.data?.docs??[]).map((d){final x=d.data();return ListTile(leading:const Icon(Icons.video_call),title:Text((x['title']??'محاضرة').toString()),subtitle:Text('${x['meetingTime']??'غير محدد'}\n${x['mustafhemName']??''} ← ${x['mufhemName']??''}'));}).toList()));
  Widget _courses()=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:db.collection('courses').where('status',isEqualTo:'pending').snapshots(),builder:(c,s)=>ListView(children:(s.data?.docs??[]).map((d)=>ListTile(title:Text((d.data()['title']??'بدون اسم').toString()),subtitle:Text((d.data()['instructorName']??'').toString()),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(icon:const Icon(Icons.check),onPressed:()=>AdminService().reviewCourse(courseId:d.id,decision:'approved')),IconButton(icon:const Icon(Icons.close),onPressed:()async{final r=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('سبب الرفض'),content:TextField(controller:r),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('رفض'))]));if(ok==true&&r.text.trim().isNotEmpty)await AdminService().reviewCourse(courseId:d.id,decision:'rejected',rejectionReason:r.text.trim());})]))).toList()));
  Widget _mufahems()=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
    stream:db.collection('users').where('mode',isEqualTo:'mofahhem').limit(200).snapshots(),
    builder:(c,s)=>ListView(
      children:(s.data?.docs??[]).map((d){
        final x=d.data();
        final verified=x['isVerified']==true;
        return ListTile(
          title:Text((x['name']??x['email']??d.id).toString()),
          subtitle:Text('${x['email']??''}\\n${verified?'موثّق':'غير موثّق'}'),
          trailing:Wrap(children:[
            IconButton(
              icon:Icon(verified?Icons.verified:Icons.verified_outlined),
              onPressed:()=>db.collection('users').doc(d.id).update({
                'isVerified':!verified,
                'verificationStatus':verified?'none':'verified',
              }),
            ),
            IconButton(
              icon:const Icon(Icons.block),
              onPressed:()=>_ban(d.id),
            ),
          ]),
        );
      }).toList(),
    ),
  );
  Widget _users()=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
    stream:db.collection('users').limit(200).snapshots(),
    builder:(c,s)=>ListView(
      children:(s.data?.docs??[]).map((d){
        final x=d.data();
        return ListTile(
          title:Text((x['name']??x['email']??d.id).toString()),
          subtitle:Text('${x['email']??''}\\n${x['status']??'active'}'),
          trailing:IconButton(
            icon:const Icon(Icons.block),
            onPressed:()=>_ban(d.id),
          ),
        );
      }).toList(),
    ),
  );
  Widget _notifications()=>Center(child:FilledButton.icon(onPressed:_notify,icon:const Icon(Icons.notifications_active),label:const Text('إرسال/جدولة إشعار لجميع المستخدمين')));
  Widget _admins()=>Center(child:FilledButton.icon(onPressed:_admin,icon:const Icon(Icons.admin_panel_settings),label:const Text('إضافة حساب أدمن')));
}
