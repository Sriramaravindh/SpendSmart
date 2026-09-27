'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {".git/COMMIT_EDITMSG": "57cc4e13afe053b9c7cb66dd4f047af1",
".git/config": "77738e44b19c1cfac769302c5f7d6dae",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/HEAD": "5ab7a4355e4c959b0c5c008f202f51ec",
".git/hooks/applypatch-msg.sample": "ce562e08d8098926a3862fc6e7905199",
".git/hooks/commit-msg.sample": "e0b5b08e209fa15f48d796e8976bc42b",
".git/hooks/fsmonitor-watchman.sample": "5c90c1740b0cacecb469934e16fe8cb6",
".git/hooks/post-update.sample": "2b7ea5cee3c49ff53d41e00785eb974c",
".git/hooks/pre-applypatch.sample": "054f9ffb8bfe04a599751cc757226dda",
".git/hooks/pre-commit.sample": "5029bfab85b1c39281aa9697379ea444",
".git/hooks/pre-merge-commit.sample": "39cb268e2a85d436b9eb6f47614c3cbc",
".git/hooks/pre-push.sample": "2c642152299a94e05ea26eae11993b13",
".git/hooks/pre-rebase.sample": "56e45f2bcbc8226d2b4200f7c46371bf",
".git/hooks/pre-receive.sample": "2ad18ec82c20af7b5926ed9cea6aeedd",
".git/hooks/prepare-commit-msg.sample": "2b5c047bdb474555e1787db32b2d2fc5",
".git/hooks/push-to-checkout.sample": "c7ab00c7784efeadad3ae9b228d4b4db",
".git/hooks/sendemail-validate.sample": "4d67df3a8d5c98cb8565c07e42be0b04",
".git/hooks/update.sample": "647ae13c682f7827c22f5fc08a03674e",
".git/index": "7fa228cbd7ec56ffd0f1a76607c8cd7d",
".git/info/exclude": "036208b4a1ab4a235d75c181e685e5a3",
".git/logs/HEAD": "b7c76171e7b674cdc25393ac5d326c6a",
".git/logs/refs/heads/gh-pages": "a90f0c5d5c3055a49d932f717bbebc20",
".git/logs/refs/remotes/origin/gh-pages": "bdbd8c7809ba51617c4bcbe2f2a6bfa1",
".git/objects/03/eaddffb9c0e55fb7b5f9b378d9134d8d75dd37": "87850ce0a3dd72f458581004b58ac0d6",
".git/objects/07/90c53df3e7bbdc538eb0736371fb75de83d98a": "61138542deed96b340882f85abadca66",
".git/objects/08/32d0db2def1613c1c45aa4fe9156a1c6b7d589": "e05df183e5eeaddf39672a2516f9c41d",
".git/objects/09/2bb0e0caa93a83e8f9f54df6ab7db244895d6a": "4f205cc5c47d0d1869c35e38c10570e8",
".git/objects/0e/f6fc92620349cae917a2f108ee5e879cdca440": "8c30248b5b5fcbd0fc5408e8cf2a416f",
".git/objects/11/1471f5b7a37811904273cf08d638f9aacb73a9": "1e94ae29bac065f89af939030f2e1bf1",
".git/objects/11/a1b351a0032a035f9c0ba79210d4e785a2e317": "7e6447d0ffce29dce6649b9bd76bf892",
".git/objects/14/2c6104b910ad4ed2a466248866066c75da010d": "ee378d74187f68e8768f1c830b51caf1",
".git/objects/14/64546b484c654d9ade523f47e91b1eecd0154c": "c1bba8b9f33b0d368f0032fa60f8a834",
".git/objects/16/7548508b1932ba6eca7fe25e014ab8a265b7ce": "9c49c708f80870de12db6e2a11b3c0a5",
".git/objects/18/180a6fd28508f7653ae45a57342ae717cf1ff7": "7f67dbdcf7938d685ae0d8e54444579a",
".git/objects/18/f6dda36a06966811eb8d683fe16b2a2e03d4e3": "581a292082bb90e3bfff23c547f02b2c",
".git/objects/1b/58869be5c44fc9b4a8aa4055e54519daa6da15": "767ae64d122213ed2568a1bf61cfcf7d",
".git/objects/22/cc2c0f0fb7609b8757a8f9ae4925fa39a97429": "bdda689da927b8e8859163a05b7be8d5",
".git/objects/23/821c0507c157cca2cf422a051f3da9b4c55538": "461da70da3bce1637f2343332a872b3e",
".git/objects/23/8b07d6d8322786fc9fc54ff4de70db3c70218d": "9e31910696b2b776ed6068fa3b9ce30f",
".git/objects/2e/2152711b8e4861379279063267b97eeeed75fa": "bc51dfb872749706e10a92dd6e4517de",
".git/objects/30/23a3f9c7585ef608be9cd2e258a060f8b43ead": "8f4ec0defd4f3fea2f1a9f9a90c5ae3d",
".git/objects/32/aa3cae58a7432051fc105cc91fca4d95d1d011": "4f8558ca16d04c4f28116d3292ae263d",
".git/objects/37/2193f2ac974f7793c1e709dbde37bedbbfbeab": "e58a8154a48f684453cea3609678200a",
".git/objects/3a/7525f2996a1138fe67d2a0904bf5d214bfd22c": "ab6f2f6356cba61e57d5c10c2e18739d",
".git/objects/3c/88f6f98805717ba30bcc66def4634e2301058e": "8d9f8fd8cbb6792a741e59fb84f1b1d0",
".git/objects/3f/86df9b4c5d94449c2ecfb3b8a0c3cb9f8ba4c4": "41131da33cb71605f434cf575b3e4d35",
".git/objects/40/0d5b186c9951e294699e64671b9dde52c6f6a0": "f6bd3c7f9b239e8898bace6f9a7446b9",
".git/objects/41/300e443f105d6ea1554a67a3920b591457249b": "d79658de3e8b65c4001c032f840669d5",
".git/objects/41/5c059c8094b888b0159fdedfd4e3cb08a8028e": "86914685ccd40e82a7fe5b70459fb9f7",
".git/objects/44/32cb6c40021775fdae54ba761215e04bd03ad7": "8afe9d7a950b0f4a287ee17099d29dc5",
".git/objects/44/a8b8e41b111fcf913a963e318b98e7f6976886": "5014fdb68f6b941b7c134a717a3a2bc6",
".git/objects/46/4ab5882a2234c39b1a4dbad5feba0954478155": "2e52a767dc04391de7b4d0beb32e7fc4",
".git/objects/46/6ed2a4179ecb194b8f33705e22d19b884f735b": "20441bfc545c7858768321abf3114067",
".git/objects/48/0bbb54038dbe4323a2520b66c32f312c90a7bc": "0c97feb44cc758348f91ff417046410c",
".git/objects/4b/b96b695a37fcfb47180dac430cabc01766b6b4": "6e41ce01b2555aa9c80757a571769db9",
".git/objects/4e/966712511b31c5a823777f2fd7afc054a9bf90": "4bc9907a0867bd5fe07e2098d2069377",
".git/objects/57/4198461d25831e09a0e97119f725582c53b458": "97e3ee29b970be37a8b7a41fb26a8844",
".git/objects/58/1adaabf23fd7ee270b436f2c9ba399d8b18ef6": "f021c41024ccf119f06a20744c191127",
".git/objects/58/9c60b673d92281c95e0e733a1d52d9299d2f79": "9c8356d37d88ef6dcd8defb4986e4c94",
".git/objects/5d/d239bfb4ef7c10d021d1001863cec7b239afca": "2dd7aec3f642314169269608d385ff98",
".git/objects/65/2ad97bc1f6b9064aa2af195a1045e356f6a8a4": "ed56deca039fbfb0680544a86ab4e462",
".git/objects/66/9845fd4173ced01b22c4a6d1e8162c3c49ebf7": "5bf90505287940d6d0e8eb329626a543",
".git/objects/69/dd618354fa4dade8a26e0fd18f5e87dd079236": "8cc17911af57a5f6dc0b9ee255bb1a93",
".git/objects/6b/e909fbf40b23748412f0ea89bf0fae827ed976": "5f118419157d9534688915220cc803f7",
".git/objects/6b/f9f4531d013e6e33cde06e6236da81278e1082": "c3e37b72743fece53f6cedccbe7fc1f8",
".git/objects/6c/66d6e4bd057ccdb87553d8cbbc28befa2e91ee": "812eb8844aa8187a32d7ba24294b38e4",
".git/objects/6e/a92bb14d97b30911c773cca85fe5de6c29753d": "aed1a72442f1ecbb75cd7f14a11d0e9c",
".git/objects/76/0ff6af40e4946e3b2734c0e69a6e186ab4d8f4": "009b8f1268bb6c384d233bd88764e6f8",
".git/objects/77/ce655c65957e6a1f05c566319de2c1151bc521": "93eac6e6d3612532cf19bafaeea0e3d0",
".git/objects/78/fea0aba32d59e80c6f3f08bf35b2e1889f3264": "35cbdc09225a411409f53abfc992bf22",
".git/objects/79/757509aeba68686fbbf1d5da13c9782d76eba8": "6f0d43654f72d4dacf4608254bb52f94",
".git/objects/7a/e192c1edbddd91583c85b8a42c9f01ec19f5e9": "204056544fa60567e08dfdefb94b8b7f",
".git/objects/7c/89cfb776787b8bde9254e9aa498cee72b19ce0": "4f4190b87ea1a5064675236f549f1498",
".git/objects/7e/8271b0a60856e27b7542dfb006b5d915c286fb": "2589672d41edff62ccb9da77026d5a61",
".git/objects/7f/df22e7d7a8b52f75d2762754120bd42ba2cd86": "947a421f7b1a22888350e2a69b31748d",
".git/objects/81/7c8cd350f43021188f84e276fb2708e9b22d87": "cfbb43294d68eb9cd610bd63caab892b",
".git/objects/84/0516208d35dcb4298847ab835e2ef84ada92fa": "36a4a870d8d9c1c623d8e1be329049da",
".git/objects/87/30efdba9286a278461bd44d918ed1bc6bd6f80": "f99915ace01e0ecdb871c2ceac00f5ad",
".git/objects/8c/99266130a89547b4344f47e08aacad473b14e0": "41375232ceba14f47b99f9d83708cb79",
".git/objects/8f/e7af5a3e840b75b70e59c3ffda1b58e84a5a1c": "e3695ae5742d7e56a9c696f82745288d",
".git/objects/90/5c8f9ca50d70ba62aafb10b9b406883f2b4586": "f361b334377f4465f8c5395920f576ef",
".git/objects/90/bcfcf0a77ab618a826db0fd8b0942963b653af": "fc109675cdf1233dd6599a4c3c0a7a69",
".git/objects/92/eab450609b7dc5d076ddf6c8416de8209373e0": "9b3d4cb7f5916a87f36a18b466ea7ac4",
".git/objects/95/1145fce7340ba54d9d68ca039bddd15354ea8e": "0b71b599ef66545aac07c907e8935457",
".git/objects/97/59bedd4fe7d74fab38c83160bb916e806f467c": "dc0549308f9c13a005526a69ed62eb48",
".git/objects/98/57c9b3b0448c92818efc5fda0f206b21914168": "ecbde07c564dabbec0f249821051b8af",
".git/objects/98/a5fa5327cb186c46022ad2b9f23af115455ddb": "c42319778b3c7e1be9ab7ade14c8ca59",
".git/objects/9c/4bd85e5d8e5ee0e6569ae65f289b278d9fcabb": "15641aa88b827c699e699328467d829e",
".git/objects/a0/b54abcc0389c9369088e696f1895994d6fecc8": "7cbf1a7050da7bea5ccd1e7c179ec009",
".git/objects/a2/57cda98cd4202c7d9bf9dec8ed4304b02e86df": "e344cca308c915c876ecbfe3b0ef6611",
".git/objects/a3/1cdf0e5b562fc95f26944539e685c345003dc0": "e1a94950a77ea1d354a070ab27ffab56",
".git/objects/a3/f6d4135f0fc209959b02afdc90ff1f40a96c61": "1bac387fb0e27a39915e8217b706d1c2",
".git/objects/a5/ccee661b940d37999e11885783cd695ba35f35": "0368babfa293d2d7ba2950e62268c310",
".git/objects/ad/4c0ba9842f4de544316a62269732d33f652961": "d2648c4f7ac6a01d24dedabffef3980b",
".git/objects/ad/81b4157c0de03a33f3d0379556b42ea2513c07": "9b76f646bbac0751bab549ba47773b45",
".git/objects/ae/13569accc3c027e9b63f77f43d10876075c943": "87e22aa44dbd7baeab010e2b9f27d928",
".git/objects/af/827332fe6a9639f4e310c0a153b065bfac8d2d": "465c61d2cfe17e48c4ba805669df3f1f",
".git/objects/b1/348258d78465a74c7e37959459175d03af4bc1": "1d99c03ce9a7cb269dd741c93e6cec52",
".git/objects/b1/5ad935a6a00c2433c7fadad53602c1d0324365": "8f96f41fe1f2721c9e97d75caa004410",
".git/objects/b1/b2a4bd86dd0929c91b31e485956972173c8547": "fc78da7d99da8c667e8fcb75bf8dd20e",
".git/objects/b3/19a1d755266bd17ef4f9633bc4f6967097acf1": "1cb2dc1f3eaf41031249356cb3799085",
".git/objects/b3/3d42e328cf8c2d7106f5babef23eba6f8d5da4": "2eeec9cb0f61ed05d686a2357cf7d879",
".git/objects/b4/e66b70d83b592374536a4b92b73cf6c0b53ebe": "d2740cbf6379624fd94102f06cc19a9b",
".git/objects/b8/53de09b863bcbb822396cd6ebf837996f192d2": "2c7298c6b62cfaf9015af3ec768136cd",
".git/objects/ba/0eef95148340e01867c47456a9aee81e458970": "cee89a6f112c3e2a9bb0668ecab95b62",
".git/objects/bc/0acca9e86b56e83727ba34945eecf53c27f91f": "5996f6a20d0eafdd04aa5f9759f69750",
".git/objects/be/71fe4b2c81a6306153abdff0da1745c73e328f": "ef6671b85ff87f39704bf64d8a30d523",
".git/objects/bf/01863ef5c2c3e21d8135d7782701000a4725d9": "0d1b33717422cd31b6e1740c4bc3b1f9",
".git/objects/c0/9a106686d55218a04e45ab58b3fcb0650c19bd": "d0551adf3ad3888353beb2c7a94f45ad",
".git/objects/c2/b3ff685c35ac0afeb006a74bef69e19e0c1427": "c00d06978680e49f2c6e4dd0eded45dd",
".git/objects/ce/e7ea31fb64a5dd46ce491c8ff6aec64da2d22c": "c3426f895bb5859c8a918f315b33acbd",
".git/objects/cf/7f4ce0bb494b4e33e01c1dcaec1e048e617e5a": "0152602c8464628fcd657551515b1d8f",
".git/objects/d0/23371979cf1e985205df19078051c10de0a82d": "700b71074bad7afee32068791dec7442",
".git/objects/d4/07535eaa98708e2798829b3264dfa13d9a3d06": "10dd52e63e1da8aefe6b34d3e802baf3",
".git/objects/d4/3532a2348cc9c26053ddb5802f0e5d4b8abc05": "3dad9b209346b1723bb2cc68e7e42a44",
".git/objects/d5/80ce749ea55b12b92f5db7747290419c975070": "8b0329dbc6565154a5434e6a0f898fdb",
".git/objects/d5/bb50b3c3bc534b51ba035a5e8495ba7af5025b": "81d30e6f235d2cd1960b1a0d917b3043",
".git/objects/d9/8ea1f2eccacc7c6b1431c599130635ef3bad3f": "941d9dd2b561828f249af6d7968ba620",
".git/objects/da/fd65422747502c19b5c74b4230282644d2169c": "d8a62caf99a372ff6c7692e143787ce3",
".git/objects/dd/6598b2c425ef57ea6579b723416431df0cdb71": "506b958c7af376909734f9388ed277bf",
".git/objects/e1/1ad36dbb787e0a61c42b934d7c562b404b38a7": "8c7633a9d0307b673a0c1fa2f6d5b747",
".git/objects/e1/33b468245ebc12d9c0f34cff6184edebfe29f3": "a92ec3e0042e344aa1a9baabb675e8f9",
".git/objects/e2/a325f78ad6d8a9fdd521e5d07a13156b9c90ff": "ebc34001eaefeababef4d68a8ee0d858",
".git/objects/e4/57e2b31cd1e08c0052835b7368d9fa47082777": "1d57f5f139a849be3245e57dcc67cb04",
".git/objects/e5/11b14bcc4f8c9dc4c1020828cfa3d21370e380": "1d84b29db7b71527a2ce97c38c202fe7",
".git/objects/ea/4defd071e994c4a0e7fdda5c5cb58460e04138": "e34c8cba021dc9a05be8406ba604964d",
".git/objects/eb/8c36a125883697ee5f5952b9ec63b987f511d2": "1c84160d90e0a57abebdfd7c7b4d501a",
".git/objects/ee/5d336e3d0546e1d7895997c6c2a8d62e194489": "e002a9c61d75c697bb1a0cca25e9f9b3",
".git/objects/f2/04823a42f2d890f945f70d88b8e2d921c6ae26": "6b47f314ffc35cf6a1ced3208ecc857d",
".git/objects/f6/5f6bcdfc5d6509cfc64b2e43df465ad0ddf7d9": "04b243b2f58a40a863e2400767ec1c3b",
".git/objects/f7/35b9b9157418567e61e5f54b11937db5eeedf8": "acdfc29e84dfcbb6654a4c1a1b2ad6ff",
".git/objects/f8/55e24dccdf4a038372a8c18b4ac9d3ac14ab22": "3f07404df2d911a41746770732c63593",
".git/objects/f9/2a3117671b2b3e9cb1f506a7add61807c0ad90": "a721c3fc0fe016f771957f78d495439d",
".git/objects/fa/7d0130d06af808accc910d2cefcf61637f651a": "b7a995242a67179aed1bf6d96b878187",
".git/refs/heads/gh-pages": "592ec0a5b3c25d9516bba2a4a2cd57b3",
".git/refs/remotes/origin/gh-pages": "592ec0a5b3c25d9516bba2a4a2cd57b3",
"assets/AssetManifest.bin": "693635b5258fe5f1cda720cf224f158c",
"assets/AssetManifest.bin.json": "69a99f98c8b1fb8111c5fb961769fcd8",
"assets/AssetManifest.json": "2efbb41d7877d10aac9d091f58ccd7b9",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "e7069dfd19b331be16bed984668fe080",
"assets/NOTICES": "0aef249d2ed1193dd0eb73e46b672461",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "b93248a553f9e8bc17f1065929d5934b",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "66177750aff65a66cb07bb44b8c6422b",
"canvaskit/canvaskit.js.symbols": "48c83a2ce573d9692e8d970e288d75f7",
"canvaskit/canvaskit.wasm": "1f237a213d7370cf95f443d896176460",
"canvaskit/chromium/canvaskit.js": "671c6b4f8fcc199dcc551c7bb125f239",
"canvaskit/chromium/canvaskit.js.symbols": "a012ed99ccba193cf96bb2643003f6fc",
"canvaskit/chromium/canvaskit.wasm": "b1ac05b29c127d86df4bcfbf50dd902a",
"canvaskit/skwasm.js": "694fda5704053957c2594de355805228",
"canvaskit/skwasm.js.symbols": "262f4827a1317abb59d71d6c587a93e2",
"canvaskit/skwasm.wasm": "9f0c0c02b82a910d12ce0543ec130e60",
"canvaskit/skwasm.worker.js": "89990e8c92bcb123999aa81f7e203b1c",
"favicon.png": "ee611514504b4fb62543148a6f2fcac5",
"flutter.js": "f393d3c16b631f36852323de8e583132",
"flutter_bootstrap.js": "4af831c6c133d55486db509792e292fe",
"icons/Icon-192.png": "33d19855ec8bf7086b3f90a054e2c021",
"icons/Icon-512.png": "46a5000a626fc15443ad3387f95b5707",
"icons/Icon-maskable-192.png": "33d19855ec8bf7086b3f90a054e2c021",
"icons/Icon-maskable-512.png": "46a5000a626fc15443ad3387f95b5707",
"index.html": "dd52bd0b1f716d715961fd0508d87f4c",
"/": "dd52bd0b1f716d715961fd0508d87f4c",
"main.dart.js": "58f6c8f5c61b0777c855ba4e9063d2e2",
"manifest.json": "c37894b233707f6d9da406faa78bc0c7",
"sqflite_sw.js": "25d6d1c279dd66ca05c13400851533ec",
"sqlite3.wasm": "fa7637a49a0e434f2a98f9981856d118",
"version.json": "b454a63529f3901ae1940dce8cba5531"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
