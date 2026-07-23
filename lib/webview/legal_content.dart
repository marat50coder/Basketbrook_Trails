/// Bundled offline copies of the legal / support pages.
///
/// These guarantee Privacy Policy and Support are always readable, even with
/// no internet connection, and always render as black text on a white
/// background.
class LegalContent {
  LegalContent._();

  static const String _head = '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  html, body { background:#ffffff !important; color:#000000 !important; margin:0; padding:0; }
  body { font-family: -apple-system, Roboto, "Segoe UI", Arial, sans-serif;
         line-height:1.6; padding:22px 20px 40px; font-size:16px; }
  h1 { font-size:26px; margin:0 0 6px; color:#000; }
  h2 { font-size:19px; margin:22px 0 8px; color:#000; }
  p, li { color:#000; }
  a { color:#1a6fd4; word-break:break-all; }
  .eff { color:#444; font-size:14px; margin-bottom:18px; }
  ul { padding-left:20px; }
</style>
</head>
<body>
''';

  static const String _foot = '</body></html>';

  static const String privacyPolicy = '''$_head
<h1>Privacy Policy</h1>
<div class="eff"><strong>Effective Date:</strong> June 2026</div>
<p>Developer ("we", "us", or "our") operates the <strong>Basketbrook Trails</strong> mobile application ("Service"). This Privacy Policy explains how information is collected, used, and protected when you use the Service.</p>
<h2>Information We Collect</h2>
<p>The Service may collect limited technical information necessary for operation and improvement of the application, including:</p>
<ul>
<li>Device type and model</li>
<li>Operating system version</li>
<li>Anonymous usage statistics</li>
<li>Diagnostic and crash information</li>
<li>IP address (when required for security and analytics purposes)</li>
</ul>
<p>We do not intentionally collect sensitive personal information such as financial account details, government-issued identification numbers, or biometric data.</p>
<h2>How We Use Information</h2>
<ul>
<li>Provide and maintain the Service</li>
<li>Improve app functionality and user experience</li>
<li>Monitor application performance and stability</li>
<li>Detect, prevent, and resolve technical issues</li>
<li>Comply with legal obligations</li>
</ul>
<h2>Data Storage and Security</h2>
<p>We take reasonable measures to protect information from unauthorized access, alteration, disclosure, or destruction. However, no method of electronic transmission or storage is completely secure.</p>
<h2>Third-Party Services</h2>
<p>The Service may use third-party providers for analytics, crash reporting, hosting, or other operational purposes. These providers may process information solely to provide services on our behalf.</p>
<h2>Data Retention</h2>
<p>We retain information only for as long as necessary to provide the Service, comply with legal obligations, resolve disputes, and enforce agreements.</p>
<h2>Data Deletion</h2>
<p>Users have the right to request deletion of their personal data. To request deletion of data associated with Basketbrook Trails, please contact us at:</p>
<p><strong>Email:</strong> support@basketbrooktrails.com</p>
<p>If the application stores data only on the user's device, users may permanently delete all stored data by uninstalling the application and clearing the application's local storage.</p>
<h2>Your Rights</h2>
<p>Depending on your location, you may have rights regarding access, correction, deletion, restriction, or portability of your personal data under applicable privacy laws, including the GDPR.</p>
<h2>Children's Privacy</h2>
<p>The Service is not intended for children under the age of 18, and we do not knowingly collect personal information from children.</p>
<h2>Changes to This Privacy Policy</h2>
<p>We may update this Privacy Policy from time to time. Changes become effective when posted on this page. Users are encouraged to review this policy periodically.</p>
<h2>Contact Us</h2>
<p><strong>Developer:</strong> Basketbrook Trails<br>
<strong>Email:</strong> support@basketbrooktrails.com</p>
$_foot''';

  static const String support = '''$_head
<h1>Support</h1>
<p>Welcome to <strong>Basketbrook Trails</strong> support.</p>
<p>If you have a question, found a bug, or want to send feedback, please reach out and we will get back to you as soon as possible.</p>
<h2>Contact</h2>
<p><strong>Email:</strong> support@basketbrooktrails.com</p>
<h2>Frequently Asked</h2>
<ul>
<li><strong>The game does not need internet.</strong> Basketbrook Trails is fully playable offline.</li>
<li><strong>Progress:</strong> your coins, unlocked levels and chickens are saved on your device.</li>
<li><strong>Reset:</strong> you can reset your progress from the in-game Settings screen.</li>
</ul>
<p>Thank you for playing and helping the little chickens deliver their eggs safely!</p>
$_foot''';
}
