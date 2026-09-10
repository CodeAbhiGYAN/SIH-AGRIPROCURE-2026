class AiService {
  Future<String> answer(String q, {required Map<String, String> context}) async {
    final s = _normalize(q);
    final leave = context['leave'] ?? 'the recommended departure time';
    final centre = context['centre'] ?? 'your assigned centre';
    final date = context['date'] ?? 'your appointment date';
    final slot = context['slot'] ?? 'your appointment slot';
    final queue = context['queue'] ?? '0';
    final verification = context['verification'] ?? 'not available';
    final payment = context['payment'] ?? 'Pending';
    final attendance = context['attendance'] ?? 'pending';
    final status = context['status'] ?? 'not yet available';
    final hindi = context['language'] == 'Hindi';

    if (_match(s, ['hello', 'hi', 'namaste', 'help', 'madad', 'suno', 'assist'])) {
      return hindi
          ? 'नमस्ते! मैं आपके अपॉइंटमेंट, केंद्र, कतार, यात्रा, सत्यापन, उपस्थिति, खरीद और भुगतान से जुड़े सवालों में मदद कर सकता हूँ।'
          : 'Namaste! I can help with your appointment, centre, queue, travel, verification, attendance, procurement and payment questions.';
    }
    if (_match(s, ['leave', 'nikal', 'nikl', 'jana', 'jaana', 'departure', 'kab chal', 'kab nik'])) {
      return hindi
          ? 'आपको $leave निकलने की सलाह दी गई है ताकि आप $centre समय पर पहुंच सकें।'
          : 'You are advised to leave by $leave so you can reach $centre on time.';
    }
    if (_match(s, ['centre', 'center', 'kendr', 'kendra']) && _match(s, ['kaunsa', 'which', 'mera', 'assigned', 'kaha', 'kahaan', 'where'])) {
      return hindi ? 'आपका आवंटित खरीद केंद्र $centre है।' : 'Your assigned procurement centre is $centre.';
    }
    if (_match(s, ['centre', 'center', 'kendr', 'kendra']) && _match(s, ['change', 'badal', 'kyu', 'kyun', 'why'])) {
      return hindi
          ? 'केंद्र इसलिए बदला गया क्योंकि पहले केंद्र पर क्षमता, कतार या संचालन संबंधी समस्या थी। सिस्टम ने उपलब्ध क्षमता और अनुमानित प्रोसेसिंग समय को देखकर दूसरा उपयुक्त केंद्र चुना।'
          : 'Your centre was changed because the previous centre had a capacity, queue or operational issue. The system selected another feasible centre using available capacity and estimated processing time.';
    }
    if (_match(s, ['appointment', 'slot', 'date', 'kab hai', 'kab ka', 'schedule', 'timing'])) {
      return hindi ? 'आपकी अपॉइंटमेंट $date को $slot है और केंद्र $centre है।' : 'Your appointment is on $date in the $slot at $centre.';
    }
    if (_match(s, ['queue', 'line', 'wait', 'waiting', 'kitne log', 'kitna wait', 'meri bari', 'turn'])) {
      return hindi ? 'अभी आपके आगे लगभग $queue किसान हैं। कतार की स्थिति बदलने पर अनुमानित प्रतीक्षा भी अपडेट होगी।' : 'There are about $queue farmers ahead of you. The estimated wait updates as the queue changes.';
    }
    if (_match(s, ['verification', 'verify', 'pending', 'document', 'kyc', 'land record', 'bank verification'])) {
      return hindi ? 'आपकी सत्यापन स्थिति: $verification।' : 'Your verification status is: $verification.';
    }
    if (_match(s, ['attendance', 'present', 'hazri', 'haazri', 'check in', 'checkin', 'upasthiti'])) {
      return hindi
          ? 'आपकी केंद्र उपस्थिति अभी $attendance है। अपॉइंटमेंट वाले दिन Home स्क्रीन से Check-in करके उपस्थिति दर्ज करें।'
          : 'Your centre attendance is currently $attendance. On the appointment day, use Check-in on the Home screen to mark attendance.';
    }
    if (_match(s, ['payment', 'paisa', 'paise', 'payment kab', 'kab milega', 'kab aayega', 'money'])) {
      return hindi ? 'आपका भुगतान स्थिति: $payment।' : 'Your payment status is: $payment.';
    }
    if (_match(s, ['status', 'progress', 'kitna complete', 'procurement status', 'purchase status'])) {
      return hindi ? 'आपकी खरीद यात्रा की वर्तमान स्थिति: $status।' : 'Your current procurement journey status is: $status.';
    }
    if (_match(s, ['crop', 'fasal', 'quantity', 'produce', 'upaj', 'season'])) {
      return hindi ? 'फसल और अनुमानित मात्रा आपकी सत्यापन स्क्रीन के Crop भाग में दर्ज और देखी जा सकती है।' : 'Your crop, season and expected quantity are entered and reviewed in the Crop section of Verification.';
    }
    if (_match(s, ['msp', 'minimum support price', 'support price'])) {
      return hindi ? 'MSP स्क्रीन पर वर्तमान और पिछले वर्ष का समर्थन मूल्य तुलना के साथ उपलब्ध है।' : 'The MSP screen shows the current and previous-year support price comparison.';
    }
    if (_match(s, ['notification', 'sms', 'message', 'msg'])) {
      return hindi ? 'महत्वपूर्ण खरीद अपडेट मोबाइल सिस्टम नोटिफिकेशन के रूप में आते हैं और वे आपके वर्तमान टैब पर भी दिखाई दे सकते हैं।' : 'Important procurement updates are delivered as mobile system notifications and can appear while you are on any farmer tab.';
    }
    if (_match(s, ['travel', 'route', 'distance', 'kitni door', 'road', 'safar'])) {
      return hindi ? 'Travel स्क्रीन पर केंद्र तक रोड रूट, दूरी, अनुमानित समय और सुझाया गया निकलने का समय दिखता है।' : 'The Travel screen shows the road route, distance, estimated travel time and recommended departure time to your centre.';
    }
    if (_match(s, ['check', 'checklist', 'next step', 'agla', 'kya karna'])) {
      return hindi ? 'आपकी अगली कार्रवाई: $status।' : 'Your next action is reflected in your procurement status: $status.';
    }
    if (_match(s, ['bill', 'receipt'])) {
      return hindi ? 'Bill चरण आपकी Procurement Status यात्रा में अपडेट किया जाता है।' : 'The Bill stage is updated in your Procurement Status journey.';
    }
    if (_match(s, ['quality', 'quality check', 'janch', 'gunvatta'])) {
      return hindi ? 'केंद्र पर फसल की गुणवत्ता की आधिकारिक जाँच की जाएगी।' : 'Official crop-quality checking is performed at the procurement centre.';
    }
    if (_match(s, ['weighing', 'weight', 'tol', 'vajan'])) {
      return hindi ? 'Weighing चरण केंद्र पर आपकी उपज का आधिकारिक वजन दर्ज करता है।' : 'The Weighing stage records the official weight of your produce at the centre.';
    }
    if (_match(s, ['procurement', 'purchase', 'khareed', 'kharid'])) {
      return hindi ? 'Procurement चरण में केंद्र आपकी उपज की सरकारी खरीद प्रक्रिया पूरी करता है।' : 'The Procurement stage is where the centre completes the government purchase process for your produce.';
    }
    if (_match(s, ['language', 'bhasha', 'hindi', 'english'])) {
      return hindi ? 'भाषा बदलने के लिए Profile & Settings में Language चुनें।' : 'Change the farmer app language from Profile & Settings → Language.';
    }
    return hindi
        ? 'मैं अपॉइंटमेंट, केंद्र, कतार, यात्रा, सत्यापन, उपस्थिति, खरीद स्थिति, भुगतान, MSP और नोटिफिकेशन से जुड़े सवालों में मदद कर सकता हूँ।'
        : 'I can help with appointment, centre, queue, travel, verification, attendance, procurement status, payment, MSP and notification questions.';
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0900-\u097f\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _match(String value, List<String> terms) => terms.any((term) => value.contains(term));
}
