import 'package:cloud_functions/cloud_functions.dart';

class PurchaseService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<double> purchaseCourse(String courseId) async {
    final callable = _functions.httpsCallable('purchaseCourse');
    try {
      final result =
          await callable.call<Map<String, dynamic>>({'courseId': courseId});
      return (result.data['amountPaid'] as num?)?.toDouble() ?? 0;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        throw Exception(
            'خدمة الشراء غير منشورة على Firebase (purchaseCourse).');
      }
      if (e.code == 'unauthenticated') {
        throw Exception('يجب تسجيل الدخول قبل شراء الكورس.');
      }
      if (e.code == 'failed-precondition') {
        throw Exception(e.message ?? 'الكورس غير متاح للشراء حاليًا.');
      }
      if (e.code == 'permission-denied') {
        throw Exception(e.message ?? 'ليس لديك صلاحية لإتمام عملية الشراء.');
      }
      throw Exception(e.message ?? 'تعذر إتمام الشراء.');
    }
  }
}
