/// Sample payment app notifications for the developer "Test notification"
/// mode.
///
/// Copied from test/fixtures/sample_notifications.txt (the app can't read
/// files from test/). test/notification_parser_test.dart checks they stay
/// identical, so if you add a line to the fixture, add it here too.
class SampleNotification {
  final String label; // shown in the "Load sample" dropdown
  final String packageName;
  final String title;
  final String text;

  const SampleNotification(this.label, this.packageName, this.title, this.text);
}

const List<SampleNotification> sampleNotificationList = [
  SampleNotification(
    'Google Pay · paid Swiggy ₹450',
    'com.google.android.apps.nbu.paisa.user',
    'Payment successful',
    '₹450 paid to Swiggy',
  ),
  SampleNotification(
    'Google Pay · Rahul paid you ₹500',
    'com.google.android.apps.nbu.paisa.user',
    'Rahul Menon paid you ₹500',
    'Tap to see details',
  ),
  SampleNotification(
    'Google Pay · request ₹200 (ignored)',
    'com.google.android.apps.nbu.paisa.user',
    'Rahul Menon requested ₹200',
    'Tap to pay',
  ),
  SampleNotification(
    'Google Pay · scratch card (ignored)',
    'com.google.android.apps.nbu.paisa.user',
    'You won a scratch card!',
    'Scratch to reveal your reward',
  ),
  SampleNotification(
    'PhonePe · paid Uber ₹120',
    'com.phonepe.app',
    'Paid ₹120 to Uber India',
    'Payment successful. UPI Ref 632412345678',
  ),
  SampleNotification(
    'PhonePe · received ₹1,000',
    'com.phonepe.app',
    'Received ₹1,000 from Anu Joseph',
    'Money credited to your bank account',
  ),
  SampleNotification(
    'PhonePe · payment failed (ignored)',
    'com.phonepe.app',
    'Payment failed',
    '₹300 to Zomato could not be completed',
  ),
  SampleNotification(
    'Paytm · Jio recharge ₹199',
    'net.one97.paytm',
    'Payment of ₹199 to Jio Prepaid successful',
    'Recharge done for 98XXXXXX10',
  ),
  SampleNotification(
    'Paytm · cashback offer (ignored)',
    'net.one97.paytm',
    'Get ₹100 cashback',
    'On your next electricity bill payment',
  ),
  SampleNotification(
    'BHIM · sent ₹80 to rapido@ybl',
    'in.org.npci.upiapp',
    '₹80 sent to rapido@ybl',
    'Transaction successful',
  ),
  SampleNotification(
    'CRED · bill due (ignored)',
    'com.dreamplug.androidapp',
    'Your credit card bill is due',
    'Pay ₹12,450 before 5 Dec',
  ),
  SampleNotification(
    'WhatsApp · not allowed (ignored)',
    'com.whatsapp',
    'Rahul',
    'Sent you ₹500 for the movie',
  ),
];
