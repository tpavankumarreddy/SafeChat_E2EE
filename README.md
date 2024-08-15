
# SafeChatE2EE - Instant Chat Application with End to End Encryption


The Instant Chat Application is designed to provide secure, real-time messaging with a focus on user privacy and data security. Leveraging end-to-end encryption (E2EE), secure key exchange (X3DH), and modern authentication methods, the app ensures that messages are only readable by the intended recipients. The app supports dynamic theming and is available on Android.



## Features

- **Real-time messaging**: Instant message delivery with real-time updates.
- **End-to-end encryption**: Messages are encrypted on the sender’s device and decrypted on the receiver’s device, ensuring privacy.
- **Secure key exchange**: Utilizes the X3DH protocol and x25519 cryptography for secure key exchange.
- **User authentication**: Includes Google Sign-In, OTP verification, and biometric authentication.
- **Dynamic theming**: Automatically adjusts the app's theme based on user preferences or device settings.
- **No Need for Permissions**: App doesn't ask for any Permissions from users.

- **Platform Support**: Supports Android as of now.
## Architecture

### Overview
The application follows a client-server architecture, with Firebase Firestore as the backend database and Firebase Authentication managing user identities.

### Key Components
- **Client**: Built with Flutter, handles the user interface, message encryption/decryption, and interactions with Firebase services.

- **Server**: Firestore serves as the database for storing messages and user data.

- **Encryption**: The app uses the x25519 algorithm for key exchange and AES-CTR for message encryption.

### Data Flow
- Users send encrypted messages to Firestore.

- Firestore stores the encrypted messages in the appropriate chat room document.

- The recipient’s device retrieves the message, decrypts it using the shared secret key, and displays it.

### Security

- **End-to-End Encryption**: Implemented using the AES-CTR encryption algorithm.

- **Key Management**: Keys are securely exchanged using the X3DH protocol and stored locally on the device.

- **Additional Measures**: Biometric authentication and OTP verification add extra layers of security.

### Technologies Used
- Languages: Dart, Kotlin
- Frameworks: Flutter
- Libraries: x25519, cryptography, AES-CTR
- Firebase Services: Firestore, Firebase Authentication, Firebase Cloud Functions
## Support

For support or inquiries, please reach out to safechat.e2ee@gmail.com.


