import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../services/firestore_service.dart';
import '../services/video_service.dart';
import '../models/lesson.dart';
import '../theme/app_theme.dart';

class LessonPlayerScreen extends StatefulWidget {
  final String courseId;
  final String lessonId;
  const LessonPlayerScreen({super.key, required this.courseId, required this.lessonId});
  @override State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  final _firestore = FirestoreService();
  final _videoService = VideoService();
  VideoPlayerController? _controller;
  Timer? _progressTimer;
  Timer? _urlRefreshTimer;
  bool _loading = true, _fullscreen = false;
  String? _error;
  double _speed = 1.0;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    _progressTimer?.cancel(); _urlRefreshTimer?.cancel();
    final old = _controller; _controller = null; await old?.dispose();
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final signed = await _videoService.getSignedVideoUrl(courseId: widget.courseId, lessonId: widget.lessonId);
      final savedSeconds = await _firestore.getLessonProgressSeconds(_uid, widget.courseId, widget.lessonId);
      final controller = VideoPlayerController.networkUrl(Uri.parse(signed.url));
      await controller.initialize();
      if (savedSeconds > 0 && savedSeconds < controller.value.duration.inSeconds) await controller.seekTo(Duration(seconds: savedSeconds));
      await controller.setPlaybackSpeed(_speed); await controller.play();
      if (!mounted) { await controller.dispose(); return; }
      setState(() { _controller = controller; _loading = false; });
      final refreshIn = signed.expiresAt.difference(DateTime.now()) - const Duration(seconds: 30);
      _urlRefreshTimer = Timer(refreshIn.isNegative ? const Duration(seconds: 5) : refreshIn, _load);
      _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().contains('permission-denied') ? 'هذا الكورس غير مشترى على هذا الحساب.' : 'تعذر تحميل الفيديو. حاول مرة أخرى.'; _loading = false; });
    }
  }
  Future<void> _saveProgress({bool completed = false}) async { final c=_controller; if(c==null||!c.value.isInitialized)return; await _firestore.saveLessonProgress(uid:_uid,courseId:widget.courseId,lessonId:widget.lessonId,positionSeconds:c.value.position.inSeconds,durationSeconds:c.value.duration.inSeconds,completed:completed); }
  Future<void> _seek(int seconds) async { final c=_controller; if(c==null)return; final target=c.value.position+Duration(seconds:seconds); final max=c.value.duration; await c.seekTo(target<Duration.zero?Duration.zero:(target>max?max:target)); }
  Future<void> _setSpeed(double speed) async { _speed=speed; await _controller?.setPlaybackSpeed(speed); if(mounted)setState((){}); }
  Future<void> _toggleFullscreen() async { _fullscreen=!_fullscreen; if(_fullscreen){ await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft,DeviceOrientation.landscapeRight]); await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); } else { await SystemChrome.setPreferredOrientations(DeviceOrientation.values); await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); } if(mounted)setState((){}); }
  @override void dispose(){ _saveProgress(); _progressTimer?.cancel(); _urlRefreshTimer?.cancel(); _controller?.dispose(); SystemChrome.setPreferredOrientations(DeviceOrientation.values); SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); super.dispose(); }

  @override Widget build(BuildContext context){
    final c=_controller;
    return Scaffold(backgroundColor:AppColors.ink, body:SafeArea(child:Column(children:[
      AspectRatio(aspectRatio:_fullscreen?16/9:16/9, child:Stack(alignment:Alignment.center,children:[
        Container(color:Colors.black),
        if(_loading)const CircularProgressIndicator(color:AppColors.gold),
        if(_error!=null)Padding(padding:const EdgeInsets.all(20),child:Text(_error!,style:const TextStyle(color:Colors.white),textAlign:TextAlign.center)),
        if(c!=null&&c.value.isInitialized)GestureDetector(onTap:()=>c.value.isPlaying?c.pause():c.play(),child:AspectRatio(aspectRatio:c.value.aspectRatio,child:VideoPlayer(c))),
        Positioned(top:6,right:6,child:IconButton(icon:const Icon(Icons.arrow_forward,color:Colors.white),onPressed:()=>context.pop())),
        if(c!=null&&c.value.isInitialized)Positioned(bottom:4,left:4,right:4,child:VideoProgressIndicator(c,allowScrubbing:true,colors:const VideoProgressColors(playedColor:AppColors.gold,bufferedColor:Colors.white24))),
      ])),
      if(!_fullscreen)Expanded(child:StreamBuilder<List<Lesson>>(stream:_firestore.watchLessons(widget.courseId),builder:(context,snap){final lessons=snap.data??[]; Lesson? current; for(final l in lessons){if(l.id==widget.lessonId)current=l;} return ListView(padding:const EdgeInsets.fromLTRB(14,8,14,24),children:[
        if(c!=null&&c.value.isInitialized)Wrap(alignment:WrapAlignment.center,spacing:6,children:[
          IconButton(tooltip:'تأخير 10 ثوانٍ',onPressed:()=>_seek(-10),icon:const Icon(Icons.replay_10,color:Colors.white)),
          IconButton(onPressed:()=>c.value.isPlaying?c.pause():c.play(),icon:Icon(c.value.isPlaying?Icons.pause_circle:Icons.play_circle,color:AppColors.gold,size:34)),
          IconButton(tooltip:'تقديم 10 ثوانٍ',onPressed:()=>_seek(10),icon:const Icon(Icons.forward_10,color:Colors.white)),
          IconButton(tooltip:'السرعة',onPressed:()=>showModalBottomSheet(context:context,backgroundColor:AppColors.ink,builder:(_)=>_SpeedSheet(current:_speed,onPick:_setSpeed)),icon:const Icon(Icons.speed,color:Colors.white)),
          IconButton(tooltip:'الجودة',onPressed:()=>showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('جودة المشاهدة'),content:const Text('جودة الفيديو الحالية هي الجودة التي يرسلها مصدر الفيديو. يمكن إضافة نسخ 360p/480p/720p/1080p للكورس لتفعيل التبديل بينها.'),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('حسنًا'))])),icon:const Icon(Icons.high_quality_outlined,color:Colors.white)),
          IconButton(tooltip:'تكبير الشاشة',onPressed:_toggleFullscreen,icon:const Icon(Icons.fullscreen,color:Colors.white)),
        ]),
        if(current!=null) ...[Text(current.title,style:const TextStyle(color:AppColors.paper,fontSize:17,fontWeight:FontWeight.w700)),const SizedBox(height:4),Text('الدرس ${current.order} من ${lessons.length}',style:const TextStyle(color:Color(0xFF8FA0A8),fontSize:12)),const SizedBox(height:18)],
        const Text('حلقات الكورس',style:TextStyle(color:AppColors.paper,fontWeight:FontWeight.w700)),
        ...lessons.map((l)=>ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(radius:14,backgroundColor:l.id==widget.lessonId?AppColors.gold:Colors.white12,child:Text('${l.order}',style:TextStyle(fontSize:11,color:l.id==widget.lessonId?AppColors.ink:Colors.white70))),title:Text(l.title,style:const TextStyle(color:AppColors.paper,fontSize:13)),subtitle:Text(l.durationLabel,style:const TextStyle(color:Color(0xFF8FA0A8),fontSize:11)),onTap:()=>context.pushReplacement('/course/${widget.courseId}/lesson/${l.id}'))),
      ];})),
    ])));
  }
}
class _SpeedSheet extends StatelessWidget { final double current; final Future<void> Function(double) onPick; const _SpeedSheet({required this.current,required this.onPick}); @override Widget build(BuildContext context)=>ListView(shrinkWrap:true,padding:const EdgeInsets.all(18),children:[const Text('سرعة التشغيل',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.bold)),...([0.5,0.75,1.0,1.25,1.5,2.0].map((s)=>ListTile(title:Text('${s}x',style:const TextStyle(color:Colors.white)),trailing:current==s?const Icon(Icons.check,color:AppColors.gold):null,onTap:()async{await onPick(s);if(context.mounted)Navigator.pop(context);}))) ]); }
