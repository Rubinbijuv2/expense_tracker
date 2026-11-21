/// Sample SMS for the developer Test SMS screen.
///
/// Copied from test/fixtures/sample_sms.txt and sample_sms_v2.txt (the app
/// can't read files from test/). test/sms_parser_test.dart checks they stay
/// identical, so if you add a line to a fixture, add it here too.
class SampleSms {
  final String label; // shown in the "Load sample" dropdown
  final String sender;
  final String body;

  const SampleSms(this.label, this.sender, this.body);
}

const List<SampleSms> sampleSmsList = [
  SampleSms(
    'HDFC UPI · Swiggy ₹450',
    'AX-HDFCBK',
    'Rs.450.00 debited from A/c XX1234 on 20-11-26 to VPA swiggy@axisbank (UPI Ref No 632412345678). Not you? Call 18002586161',
  ),
  SampleSms(
    'SBI UPI · Uber ₹120',
    'VM-SBIUPI',
    'Dear UPI user A/C X5678 debited by 120.0 on date 20Nov26 trf to UBER INDIA Refno 432198765432. If not u? call 1800111109 -SBI',
  ),
  SampleSms(
    'ICICI · Amazon Pay ₹1,299',
    'JD-ICICIB',
    'ICICI Bank Acct XX901 debited for Rs 1,299.00 on 19-Nov-26; AMAZON PAY credited. UPI:632498761234. Call 18002662 for dispute.',
  ),
  SampleSms(
    'Axis card · Flipkart ₹2,500',
    'AD-AXISBK',
    'INR 2,500.00 spent on AXIS Bank Card XX4321 on 18-11-26 at FLIPKART. Avl Lmt: INR 47,500.00',
  ),
  SampleSms(
    'Kotak UPI · Rapido ₹80',
    'BZ-KOTAKB',
    'Sent Rs.80.00 from Kotak Bank AC X3344 to rapido@ybl on 20-11-26.UPI Ref 632455551111. Not you, https://kotak.com/fraud',
  ),
  SampleSms(
    'HDFC ATM withdrawal ₹2,000',
    'VK-HDFCBK',
    'Rs 2000.00 withdrawn at ATM from A/c XX1234 on 17-11-26. Avl bal Rs 8,450.20',
  ),
  SampleSms(
    'SBI NEFT salary ₹15,000 (income)',
    'AX-SBIINB',
    'Your A/c XX5678 is credited with INR 15,000.00 on 01-11-26 by NEFT from ABC PVT LTD. -SBI',
  ),
  SampleSms(
    'Paytm · Jio recharge ₹199',
    'JM-PAYTMB',
    'Rs.199 paid to Jio Prepaid from Paytm Payments Bank a/c 918XXX. UPI Ref 632400001234',
  ),
  SampleSms(
    'ICICI UPI from Rahul ₹649 (income)',
    'VM-ICICIB',
    'Dear Customer, Rs.649.00 received in your account XX901 from rahul@okhdfcbank on 15-11-26. UPI Ref 632477778888',
  ),
  // --- These must be ignored ---
  SampleSms(
    'IGNORE · OTP',
    'AX-HDFCBK',
    '482913 is the OTP for your transaction of Rs.450.00 at SWIGGY. Valid for 5 mins. Do not share.',
  ),
  SampleSms(
    'IGNORE · Cashback offer',
    'VM-AMAZON',
    'Get 10% cashback on orders above Rs.999! Shop now on Amazon.',
  ),
  SampleSms(
    'IGNORE · Card statement',
    'AD-AXISBK',
    'Your credit card statement is generated. Total due Rs 12,450.00, due on 05-12-26.',
  ),
  SampleSms(
    'IGNORE · Future debit (SIP)',
    'JD-ICICIB',
    'Rs 5,000 will be debited from your A/c XX901 on 25-11-26 for SIP.',
  ),
  SampleSms(
    'IGNORE · Personal number',
    '9876543210',
    'Bro I sent you Rs 500 for the movie tickets',
  ),
];

/// Version 2 samples, copied from test/fixtures/sample_sms_v2.txt (kind
/// labels, receipts, refunds, self transfers, a Bank + Receipt pair).
/// test/sms_parser_test.dart checks the two stay identical.
const List<SampleSms> sampleSmsV2List = [
  SampleSms(
    'v2 Bank · Swiggy ₹450',
    'JD-HDFCBK-S',
    'Rs.450.00 debited from A/c XX1234 on 20-11-26 to VPA swiggy@axisbank (UPI Ref No 632412345678). Not you? Call 18002586161',
  ),
  SampleSms(
    'v2 Bank · Amazon Pay ₹1,299',
    'JD-ICICIB-T',
    'ICICI Bank Acct XX901 debited for Rs 1,299.00 on 19-Nov-26; AMAZON PAY credited. UPI:632498761234. Call 18002662 for dispute.',
  ),
  SampleSms(
    'v2 Bank · Hp Petrol Pump ₹1,500',
    'AD-HDFCBK-S',
    'INR 1,500.00 spent on HDFC Bank Card XX4321 at HP PETROL PUMP on 18-11-26. Avl Lmt: INR 48,500.00',
  ),
  SampleSms(
    'v2 Bank · Paytmfastag ₹300',
    'AX-HDFCBK-S',
    'Rs.300.00 debited from A/c XX1234 on 19-11-26 to VPA paytmfastag@paytm UPI Ref No 632400009999',
  ),
  SampleSms(
    'v2 Bank · Gst Payment ₹2,000',
    'VM-SBIINB-S',
    'Rs 2,000.00 debited from A/c XX5678 towards GST PAYMENT via NEFT on 20-11-26. Ref No 88776655 -SBI',
  ),
  SampleSms(
    'v2 Bank · Abc Pvt Ltd ₹15,000 (income)',
    'AX-SBIINB-T',
    'Your A/c XX5678 is credited with INR 15,000.00 on 01-11-26 by NEFT from ABC PVT LTD. -SBI',
  ),
  SampleSms(
    'v2 Bank · Infosys Ltd ₹32,000 (income)',
    'VM-HDFCBK-S',
    'Rs.32,000.00 credited to your A/c XX1234 on 01-11-26 by NEFT from INFOSYS LTD. Info: SAL NOV26. Avl bal Rs 40,210.55',
  ),
  SampleSms(
    'v2 Bank · Rahul ₹649 (income)',
    'VM-ICICIB-S',
    'Dear Customer, Rs.649.00 received in your account XX901 from rahul@okhdfcbank on 15-11-26. UPI Ref 632477778888',
  ),
  SampleSms(
    'v2 Bank · Cash deposit ₹5,000 (income)',
    'AX-CANBNK-S',
    'Rs 5,000.00 deposited in your A/c XX7788 on 20-11-26 by cash at branch. -Canara Bank',
  ),
  SampleSms(
    'v2 Bank · Flipkart refund ₹499 (income)',
    'JD-ICICIB-S',
    'Refund of Rs 499.00 from FLIPKART credited to your Acct XX901 on 18-11-26. Ref No 6324000111',
  ),
  SampleSms(
    'v2 Bank · Cashback ₹25 (income)',
    'AX-AXISBK-S',
    'Cashback of Rs 25.00 credited to your A/c XX4321 for your Diwali offer UPI payment. Avl bal Rs 1,200.00',
  ),
  SampleSms(
    'v2 Receipt · Harithamithram ₹50',
    'VM-HMTRAM-S',
    'Your payment of Rs.50.00 for Harithamithram is received. Receipt No HM12345. Thank you.',
  ),
  SampleSms(
    'v2 Receipt · Vaahan ₹120',
    'AD-VAAHAN-S',
    'Payment received for Vehicle KL07AB1234 PUC fee Rs 120.00. Transaction ID VH998877. Thank you, Team Vaahan',
  ),
  SampleSms(
    'v2 Receipt · Itdcpc ₹1,000',
    'VM-ITDCPC-G',
    'Payment of Rs 1,000.00 received for Challan No 2811260045 towards Income Tax. Receipt No ITD45678.',
  ),
  SampleSms(
    'v2 Receipt · Tnebpy ₹640',
    'BZ-TNEBPY-S',
    'Rs.640.00 paid successfully for electricity bill via UPI. Receipt No EB556677.',
  ),
  SampleSms(
    'v2 Check this · Dmart ₹1,234.50',
    'BZ-DMARTS-S',
    'Thank you for shopping at DMart. You paid Rs 1,234.50. Visit again!',
  ),
  SampleSms(
    'v2 Self transfer (word SELF) ₹1,000',
    'VM-HDFCBK-S',
    'Rs.1,000.00 debited from A/c XX1234 on 20-11-26 trf to SELF. UPI Ref No 632400007777',
  ),
  SampleSms(
    'v2 Self transfer to XX5678 ₹5,000 (add 5678 in My accounts)',
    'AX-HDFCBK-S',
    'Rs.5,000.00 sent from A/c XX1234 to A/c XX5678 via IMPS on 20-11-26. Ref No 445566',
  ),
  SampleSms(
    'v2 Bank · Parivahan ₹120 (pairs with Vaahan receipt)',
    'JD-SBIUPI-S',
    'Rs.120.00 debited from A/c XX1234 on 20-11-26 to VPA parivahan.pay@sbi UPI Ref No 632400001200',
  ),
  SampleSms(
    'v2 IGNORE · promo sender (-P)',
    'AX-SWIGGY-P',
    'Rs.100 credited to your Swiggy Money wallet! Order now and save.',
  ),
  SampleSms(
    'v2 IGNORE · reward points',
    'AX-HDFCBK-S',
    'You have earned 150 reward points on your purchase of Rs 1,500 at Croma. Redeem now.',
  ),
  SampleSms(
    'v2 IGNORE · bill due reminder',
    'VM-AIRTEL-S',
    'Your Airtel bill of Rs 499.00 is due on 25-11-26. Pay now to avoid late fee.',
  ),
  SampleSms(
    'v2 IGNORE · refund processing',
    'JD-SBICRD-S',
    'Your refund of Rs 899 has been processed and will reach your account in 5-7 days.',
  ),
  SampleSms(
    'v2 IGNORE · ITR e-verified',
    'AX-ITDEFL-G',
    'Your ITR for AY 2026-27 has been successfully e-verified. Refund of Rs 2,300 if any will be credited.',
  ),
  SampleSms(
    'v2 IGNORE · wallet voucher',
    'VM-PAYTMB-S',
    'Rs.100 voucher credited to your Paytm wallet. Use it before 30-11-26.',
  ),
  SampleSms(
    'v2 IGNORE · cashback offer',
    'AD-FLPKRT-S',
    'Get Rs 200 cashback on your next order! TnC apply.',
  ),
  SampleSms(
    'v2 IGNORE · SIP intimation',
    'AX-HDFCBK-S',
    'Transaction intimation: Rs 5,000 debited from A/c XX1234 for SIP was requested.',
  ),
  SampleSms(
    'v2 IGNORE · personal number',
    '9876543210',
    'Received Rs 500 from Arun',
  ),
];
