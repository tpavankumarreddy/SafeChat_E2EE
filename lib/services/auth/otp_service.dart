import 'package:email_otp/email_otp.dart';

class OTPService {

  Future<void> sendOTP(EmailOTP myAuth,String email, String name) async {

    try {

      // var path="/home/pavan9999/AndroidStudioProjects/emailchat/lib/images/safechat.png";
      EmailOTP.setSMTP(
          host: "smtp.gmail.com",
          //auth: true,
          username: "safechat.e2ee@gmail.com",
          password: "ekfm tzhm zrpj pnef",
          secureType: SecureType.tls,
          emailPort: EmailPort.port587
      );

      EmailOTP.config(
          appEmail: "safechat.e2ee@gmail.com",
          appName: "SafeChat",
          //userEmail: email,
          otpLength: 6,
          otpType: OTPType.numeric
      );



      EmailOTP.setTemplate(
          template: '''
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>OTP Email</title>
        <style>
          /* CSS styling */
          p {
          font-size: 16px; /* Specify the desired font size in pixels (px) */
          }
        </style>
      </head>
      <body>
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
            <!-- Image Section -->
            <div style="text-align: center;">
                <img src="https://i.ibb.co/w6gjVK6/safechat.png" alt="Company Logo" style="max-width: 90%;">
            </div>

            <!-- OTP Section -->
            <div style="margin-top: 20px;">
                <h1>Hello, $name</h1>
                
                <h2>Thanks for choosing </h2>
                <h2>{{appName}}</h2>
                <h2>, where your <b>privacy</b> matters!</h2>
                <p>Your One-Time Password (OTP) for verification is:</p>
                <h1 style="text-align: center;"><strong>{{otp}}</strong></h1>
                <p>Please use this OTP to proceed with your registration.</p>
            </div>

            <!-- Footer Section -->
            <div style="margin-top: 20px; text-align: center;">
                <p>This email was sent from {{app_name}}. If you did not request this OTP, please ignore this email.</p>
            </div>
        </div>
      </body>
      </html>

      ''',
      );

     // myAuth.setTemplate(render: template);
  //    myAuth.setTheme(theme: 'default');

  //     String customTemplate = '''
  //   <!DOCTYPE html>
  //   <html lang="en">
  //   <head>
  //     <meta charset="UTF-8">
  //     <meta http-equiv="X-UA-Compatible" content="IE=edge">
  //     <meta name="viewport" content="width=device-width, initial-scale=1.0">
  //     <title>OTP Email</title>
  //   </head>
  //   <body>
  //     <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
  //       <!-- Your custom HTML template goes here -->
  //       <h1>Hello, {{app_name}}!</h1>
  //       <p>Your OTP is: {{otp}}</p>
  //       <p>Please use this OTP to verify your account.</p>
  //     </div>
  //   </body>
  //   </html>
  // ''';

      // Set custom template
     // myAuth.setTemplate(render: customTemplate);

      if (await EmailOTP.sendOTP(email: email) == true) {
        print("OTP has been sent");
      } else {
        print("Oops, OTP send failed");
      }


    } catch (e) {
      print("Network Error: $e");
    }
  }
}
