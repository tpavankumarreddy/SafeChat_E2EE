import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class X3DHHelper {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  Future<String> _readFromSecureStorage(String key) async {
    final value = await _secureStorage.read(key: key);
    if (value == null) {
      throw Exception('Key $key not found in secure storage');
    }
    return value;
  }

  Future<Map<String, dynamic>> performX3DHKeyAgreement(String localEmail, String remoteEmail, String identityKeyOfBob, String oneTimePreKeyOfBob, String preKeyOfBob) async {
    final localIdentityKeyPairPrivate = await _readFromSecureStorage('identityKeyPairPrivate$localEmail');
    final localIdentityKeyPairPublic = await _readFromSecureStorage('identityKeyPairPublic$localEmail');
    final localSignedPreKeyPairPrivate = await _readFromSecureStorage('preKeyPairPrivate$localEmail');
    final localSignedPreKeyPairPublic = await _readFromSecureStorage('preKeyPairPublic$localEmail');

    final algorithm = X25519();
    final localEphemeralKeyPair = await algorithm.newKeyPair();
    final ephemeralKeyPrivate = localEphemeralKeyPair.extractPrivateKeyBytes();
    final EphemeralKey = await localEphemeralKeyPair.extractPublicKey();
    await _firestore.collection("pendingMessages")
        .doc("${remoteEmail}_$localEmail")
        .update({
      'EphemeralKey': base64Encode(EphemeralKey.bytes), // Use a string as the key
    });
    print("objectj");
    final localIdentityKeyPair = SimpleKeyPairData(
      base64Decode(localIdentityKeyPairPrivate),
      publicKey: SimplePublicKey(
        base64Decode(localIdentityKeyPairPublic),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );

    final localSignedPreKeyPair = SimpleKeyPairData(
      base64Decode(localSignedPreKeyPairPrivate),
      publicKey: SimplePublicKey(
        base64Decode(localSignedPreKeyPairPublic),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );

    // Fetch remote public keys
    //final remoteKeys = await _preKeyBundleRetriever.getUserPublicKeysByEmail(remoteEmail);

    final remoteIdentityKey = SimplePublicKey(base64Decode(identityKeyOfBob), type: KeyPairType.x25519);
    final remoteSignedPreKey = SimplePublicKey(base64Decode(preKeyOfBob), type: KeyPairType.x25519);
    final remoteOneTimePreKey = SimplePublicKey(base64Decode(oneTimePreKeyOfBob), type: KeyPairType.x25519);


    // X3DH Key Agreement
    final sharedSecret1 = await algorithm.sharedSecretKey(
      keyPair: localEphemeralKeyPair,
      remotePublicKey: remoteIdentityKey,
    );

    final sharedSecret2 = await algorithm.sharedSecretKey(
      keyPair: localIdentityKeyPair,
      remotePublicKey: remoteSignedPreKey,
    );

    final sharedSecret3 = await algorithm.sharedSecretKey(
      keyPair: localEphemeralKeyPair,
      remotePublicKey: remoteSignedPreKey,
    );

    final sharedSecret4 = await algorithm.sharedSecretKey(
      keyPair: localEphemeralKeyPair,
      remotePublicKey: remoteOneTimePreKey,
    );
    final sharedSecretBytes1 = await sharedSecret1.extractBytes();
    print("shared secret 1 $sharedSecretBytes1");
    final sharedSecretBytes2 = await sharedSecret2.extractBytes();
    print("shared secret 2 $sharedSecretBytes2");
    final sharedSecretBytes3 = await sharedSecret3.extractBytes();
    print("shared secret 3 $sharedSecretBytes3");
    final sharedSecretBytes4 = await sharedSecret4.extractBytes();
    print("shared secret 4 $sharedSecretBytes4");

    final combinedSecretBytes = <int>[
      ...sharedSecretBytes1,
      ...sharedSecretBytes2,
      ...sharedSecretBytes3,
      ...sharedSecretBytes4,
    ];


    // final hkdf = Hkdf(
    //   hmac: Hmac.sha256(),
    //   outputLength: 32, // Length of AES-256 key
    // );
    //
    // final derivedKey = await hkdf.deriveKey(
    //   secretKey: SecretKey(combinedSecretBytes),
    //   nonce: Uint8List(0), // Normally, a unique value or salt
    //   info: Uint8List.fromList('X3DH key agreement'.codeUnits), // Optional context info
    // );
    //
    //  return derivedKey;
    // // Use SHA-256 to hash the combined secret
    final sha256 = Sha256();
    final hash = await sha256.hash(combinedSecretBytes);

    // Use the hash as the combined secret key
    final combinedSecret = SecretKey(hash.bytes);

    return {
      'sharedSecret': combinedSecret,
    };
  }

  Future<Map<String, dynamic>> performX3DHKeyAgreementForBob(String localUid, String remoteEmail,Map<String, dynamic> retrieveKeysResponse) async {
    final localIdentityKeyPairPrivate = await _readFromSecureStorage('identityKeyPairPrivate$localUid');
    final localIdentityKeyPairPublic = await _readFromSecureStorage('identityKeyPairPublic$localUid');
    final localSignedPreKeyPairPrivate = await _readFromSecureStorage('preKeyPairPrivate$localUid');
    final localSignedPreKeyPairPublic = await _readFromSecureStorage('preKeyPairPublic$localUid');
    print("object1");
    final aliceIdentityKeyBase64 = retrieveKeysResponse['aliceIdentityKey'];
    print("object2");
    final alicePreKeyBase64 = retrieveKeysResponse['alicePreKey'];
    final aliceIdentityKey = SimplePublicKey(base64Decode(aliceIdentityKeyBase64), type: KeyPairType.x25519);
    final alicePreKey = SimplePublicKey(base64Decode(alicePreKeyBase64), type: KeyPairType.x25519);
    final int indexOTPK = retrieveKeysResponse['index'];
    print("object");
    final aliceEphemeralKeyBase64 = retrieveKeysResponse['EphemeralKey'];
    final aliceEphemeralKey = SimplePublicKey(base64Decode(aliceEphemeralKeyBase64), type: KeyPairType.x25519);
     print(aliceEphemeralKey);
    print("object");

    Future<String?> readFromSecureStoragee(String key) async {
      return await _secureStorage.read(key: key);
    }

    Future<List<SimpleKeyPairData>> retrieveOneTimePreKeys(int count) async {
      List<SimpleKeyPairData> oneTimePreKeys = [];

      for (int i = 0; i < count; i++) {
        String privateKeyKey = 'oneTimePreKeyPairPrivate$localUid$i';
        String publicKeyKey = 'oneTimePreKeyPairPublic$localUid$i';

        final privateKeyValue = await readFromSecureStoragee(privateKeyKey);
        final publicKeyValue = await readFromSecureStoragee(publicKeyKey);

        if (privateKeyValue != null && publicKeyValue != null) {
          oneTimePreKeys.add(
            SimpleKeyPairData(
              base64Decode(privateKeyValue),
              publicKey: SimplePublicKey(
                base64Decode(publicKeyValue),
                type: KeyPairType.x25519,
              ),
              type: KeyPairType.x25519,
            ),
          );
        } else {
          print("Error retrieving key $i");
        }
      }

      return oneTimePreKeys;
    }

    final oneTimePreKeys = await retrieveOneTimePreKeys(100);


    final localIdentityKeyPair = SimpleKeyPairData(
      base64Decode(localIdentityKeyPairPrivate),
      publicKey: SimplePublicKey(
        base64Decode(localIdentityKeyPairPublic),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );

    final localSignedPreKeyPair = SimpleKeyPairData(
      base64Decode(localSignedPreKeyPairPrivate),
      publicKey: SimplePublicKey(
        base64Decode(localSignedPreKeyPairPublic),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );

    //final localKeys = await _preKeyBundleRetriever.getUserPublicKeysByEmail(localUid);
    // Fetch remote public keys
    //final remoteKeys = await _preKeyBundleRetriever.getUserPublicKeysByEmail(remoteEmail);



    final algorithm = X25519();

    // X3DH Key Agreement
    final sharedSecret1 = await algorithm.sharedSecretKey(
      keyPair: localIdentityKeyPair,
      remotePublicKey: aliceEphemeralKey,
    );
    print("shared1");
    final sharedSecret2 = await algorithm.sharedSecretKey(
      keyPair: localSignedPreKeyPair,
      remotePublicKey: aliceIdentityKey,
    );
    print("shared2");

    final sharedSecret3 = await algorithm.sharedSecretKey(
      keyPair: localSignedPreKeyPair,
      remotePublicKey: aliceEphemeralKey,
    );
    print("shared3");

    final sharedSecret4 = await algorithm.sharedSecretKey(
      keyPair: oneTimePreKeys[indexOTPK],
      remotePublicKey: aliceEphemeralKey,
    );
    print("shared4");



    // Combine shared secrets
    final sharedSecretBytes1 = await sharedSecret1.extractBytes();
    print("shared secret 1 $sharedSecretBytes1");
    final sharedSecretBytes2 = await sharedSecret2.extractBytes();
    print("shared secret 2 $sharedSecretBytes2");
    final sharedSecretBytes3 = await sharedSecret3.extractBytes();
    print("shared secret 3 $sharedSecretBytes3");
    final sharedSecretBytes4 = await sharedSecret4.extractBytes();
    print("shared secret 3 $sharedSecretBytes4");

    final combinedSecretBytes = <int>[
      ...sharedSecretBytes1,
      ...sharedSecretBytes2,
      ...sharedSecretBytes3,
      ...sharedSecretBytes4,
    ];

    //print(combinedSecretBytes);

    final sha256 = Sha256();
    final hash = await sha256.hash(combinedSecretBytes);

   // print(hash);
    // Use the hash as the combined secret key
    final combinedSecret = SecretKey(hash.bytes);
    // print("Combined secret bytes length: ${combinedSecretBytes.length}");
    // print("Hash bytes length: ${hash.bytes.length}");
    // print("Hash bytes: ${hash.bytes}");
    return {
      'sharedSecret': combinedSecret,
    };
  }
}
