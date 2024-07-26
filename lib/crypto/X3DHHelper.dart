import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:convert';
import 'get_prekeybundle.dart';

class X3DHHelper {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final PreKeyBundleRetriever _preKeyBundleRetriever = PreKeyBundleRetriever();

  Future<String> _readFromSecureStorage(String key) async {
    final value = await _secureStorage.read(key: key);
    if (value == null) {
      throw Exception('Key $key not found in secure storage');
    }
    return value;
  }

  Future<Map<String, dynamic>> performX3DHKeyAgreement(String localUid, String remoteEmail, int indexOTPK) async {
    final localIdentityKeyPairPrivate = await _readFromSecureStorage('identityKeyPairPrivate');
    final localIdentityKeyPairPublic = await _readFromSecureStorage('identityKeyPairPublic');
    final localSignedPreKeyPairPrivate = await _readFromSecureStorage('signedPreKeyPairPrivate');
    final localSignedPreKeyPairPublic = await _readFromSecureStorage('signedPreKeyPairPublic');

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
    final remoteKeys = await _preKeyBundleRetriever.getUserPublicKeysByEmail(remoteEmail);

    final remoteIdentityKey = SimplePublicKey(base64Decode(remoteKeys['identityKey']), type: KeyPairType.x25519);
    final remoteSignedPreKey = SimplePublicKey(base64Decode(remoteKeys['signedPreKey']), type: KeyPairType.x25519);

    SimplePublicKey remoteOneTimePreKey;
    final oneTimePrekeys = remoteKeys['oneTimePrekeys'] as List;
    final randomIndex = Random().nextInt(min(oneTimePrekeys.length, 100));

    if (indexOTPK == 0) {

    remoteOneTimePreKey = SimplePublicKey(
      base64Decode(oneTimePrekeys[randomIndex]),
      type: KeyPairType.x25519,
    );
    } else {
      remoteOneTimePreKey = SimplePublicKey(base64Decode(oneTimePrekeys[indexOTPK]), type: KeyPairType.x25519);
    }

    final algorithm = X25519();

    // X3DH Key Agreement
    final sharedSecret1 = await algorithm.sharedSecretKey(
      keyPair: localIdentityKeyPair,
      remotePublicKey: remoteSignedPreKey,
    );
    final sharedSecret2 = await algorithm.sharedSecretKey(
      keyPair: localSignedPreKeyPair,
      remotePublicKey: remoteIdentityKey,
    );
    final sharedSecret3 = await algorithm.sharedSecretKey(
      keyPair: localIdentityKeyPair,
      remotePublicKey: remoteOneTimePreKey,
    );

    // Combine shared secrets
    final sharedSecretBytes1 = await sharedSecret1.extractBytes();
    print("shared secret 1 $sharedSecretBytes1");
    final sharedSecretBytes2 = await sharedSecret2.extractBytes();
    print("shared secret 2 $sharedSecretBytes2");
    final sharedSecretBytes3 = await sharedSecret3.extractBytes();
    print("shared secret 3 $sharedSecretBytes3");

    final combinedSecretBytes = <int>[
      ...sharedSecretBytes1,
      ...sharedSecretBytes2,
      ...sharedSecretBytes3,
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
      'randomIndex': randomIndex
    };
  }

  Future<Map<String, dynamic>> performX3DHKeyAgreementForBob(String localUid, String remoteEmail, int indexOTPK) async {
    final localIdentityKeyPairPrivate = await _readFromSecureStorage('identityKeyPairPrivate');
    final localIdentityKeyPairPublic = await _readFromSecureStorage('identityKeyPairPublic');
    final localSignedPreKeyPairPrivate = await _readFromSecureStorage('signedPreKeyPairPrivate');
    final localSignedPreKeyPairPublic = await _readFromSecureStorage('signedPreKeyPairPublic');

    Future<String?> readFromSecureStoragee(String key) async {
      return await _secureStorage.read(key: key);
    }

    Future<List<SimpleKeyPairData>> retrieveOneTimePreKeys(int count) async {
      List<SimpleKeyPairData> oneTimePreKeys = [];

      for (int i = 0; i < count; i++) {
        String privateKeyKey = 'oneTimePreKeyPairPrivate$i';
        String publicKeyKey = 'oneTimePreKeyPairPublic$i';

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

    final localKeys = await _preKeyBundleRetriever.getUserPublicKeysByEmail(localUid);
    // Fetch remote public keys
    final remoteKeys = await _preKeyBundleRetriever.getUserPublicKeysByEmail(remoteEmail);

    final remoteIdentityKey = SimplePublicKey(base64Decode(remoteKeys['identityKey']), type: KeyPairType.x25519);
    final remoteSignedPreKey = SimplePublicKey(base64Decode(remoteKeys['signedPreKey']), type: KeyPairType.x25519);

    SimplePublicKey localOneTimePreKey;
    final oneTimePrekeys = localKeys['oneTimePrekeys'] as List;

    localOneTimePreKey = SimplePublicKey(base64Decode(oneTimePrekeys[indexOTPK]), type: KeyPairType.x25519);


    final algorithm = X25519();

    // X3DH Key Agreement
    final sharedSecret1 = await algorithm.sharedSecretKey(
      keyPair: localSignedPreKeyPair,
      remotePublicKey: remoteIdentityKey,
    );
    final sharedSecret2 = await algorithm.sharedSecretKey(
      keyPair: localIdentityKeyPair,
      remotePublicKey: remoteSignedPreKey,
    );

    final sharedSecret3 = await algorithm.sharedSecretKey(
      keyPair: oneTimePreKeys[indexOTPK],
      remotePublicKey: remoteIdentityKey,
    );



    // Combine shared secrets
    final sharedSecretBytes1 = await sharedSecret1.extractBytes();
    print("shared secret 1 $sharedSecretBytes1");
    final sharedSecretBytes2 = await sharedSecret2.extractBytes();
    print("shared secret 2 $sharedSecretBytes2");
    final sharedSecretBytes3 = await sharedSecret3.extractBytes();
    print("shared secret 3 $sharedSecretBytes3");

    final combinedSecretBytes = <int>[
      ...sharedSecretBytes1,
      ...sharedSecretBytes2,
      ...sharedSecretBytes3,
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
