/// Sample SMS for the developer Test SMS screen.
///
/// Copied from test/fixtures/sample_sms.txt (the app can't read files from
/// test/). test/sms_parser_test.dart checks the two stay identical, so if you
/// add a line to the fixture, add it here too.
class SampleSms {
  final String label; // shown in the "Load sample" dropdown
  final String sender;
  final String body;

  const SampleSms(this.label, this.sender, this.body);
}

const List<SampleSms> sampleSmsList = [
  SampleSms('HDFC UPI · Swiggy ₹450', 'AX-HDFCBK',
      'Rs.450.00 debited from A/c XX1234 on 20-11-26 to VPA swiggy@axisbank (UPI Ref No 632412345678). Not you? Call 18002586161'),
  SampleSms('SBI UPI · Uber ₹120', 'VM-SBIUPI',
      'Dear UPI user A/C X5678 debited by 120.0 on date 20Nov26 trf to UBER INDIA Refno 432198765432. If not u? call 1800111109 -SBI'),
  SampleSms('ICICI · Amazon Pay ₹1,299', 'JD-ICICIB',
      'ICICI Bank Acct XX901 debited for Rs 1,299.00 on 19-Nov-26; AMAZON PAY credited. UPI:632498761234. Call 18002662 for dispute.'),
  SampleSms('Axis card · Flipkart ₹2,500', 'AD-AXISBK',
      'INR 2,500.00 spent on AXIS Bank Card XX4321 on 18-11-26 at FLIPKART. Avl Lmt: INR 47,500.00'),
  SampleSms('Kotak UPI · Rapido ₹80', 'BZ-KOTAKB',
      'Sent Rs.80.00 from Kotak Bank AC X3344 to rapido@ybl on 20-11-26.UPI Ref 632455551111. Not you, https://kotak.com/fraud'),
  SampleSms('HDFC ATM withdrawal ₹2,000', 'VK-HDFCBK',
      'Rs 2000.00 withdrawn at ATM from A/c XX1234 on 17-11-26. Avl bal Rs 8,450.20'),
  SampleSms('SBI NEFT salary ₹15,000 (income)', 'AX-SBIINB',
      'Your A/c XX5678 is credited with INR 15,000.00 on 01-11-26 by NEFT from ABC PVT LTD. -SBI'),
  SampleSms('Paytm · Jio recharge ₹199', 'JM-PAYTMB',
      'Rs.199 paid to Jio Prepaid from Paytm Payments Bank a/c 918XXX. UPI Ref 632400001234'),
  SampleSms('ICICI UPI from Rahul ₹649 (income)', 'VM-ICICIB',
      'Dear Customer, Rs.649.00 received in your account XX901 from rahul@okhdfcbank on 15-11-26. UPI Ref 632477778888'),
  // --- These must be ignored ---
  SampleSms('IGNORE · OTP', 'AX-HDFCBK',
      '482913 is the OTP for your transaction of Rs.450.00 at SWIGGY. Valid for 5 mins. Do not share.'),
  SampleSms('IGNORE · Cashback offer', 'VM-AMAZON',
      'Get 10% cashback on orders above Rs.999! Shop now on Amazon.'),
  SampleSms('IGNORE · Card statement', 'AD-AXISBK',
      'Your credit card statement is generated. Total due Rs 12,450.00, due on 05-12-26.'),
  SampleSms('IGNORE · Future debit (SIP)', 'JD-ICICIB',
      'Rs 5,000 will be debited from your A/c XX901 on 25-11-26 for SIP.'),
  SampleSms('IGNORE · Personal number', '9876543210',
      'Bro I sent you Rs 500 for the movie tickets'),
];
