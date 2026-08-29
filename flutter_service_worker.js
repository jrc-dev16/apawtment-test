'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "71ec41cddf34c42119f310ef03cf191c",
"assets/AssetManifest.bin.json": "51f50c2a669c20a937970a6871ed6917",
"assets/AssetManifest.json": "b0bbbab67244164b499567d5f08bce2c",
"assets/assets/env": "f8ba930fc3f5113f9f30109bdd59d7d7",
"assets/assets/fonts/Montserrat-Bold.ttf": "c300fff4e4ae0ca994c58ac9f6639b19",
"assets/assets/fonts/Montserrat-Regular.ttf": "203d753a80557746c23ce95191fbf013",
"assets/assets/fonts/OdorMeanChey-Regular.ttf": "641f4d47e7c8763fd307055cc14e369e",
"assets/assets/icons/accountmngmnt.png": "a4e375dc508605792cccd763f06a8774",
"assets/assets/icons/activitylogsicon.png": "06a00c5ea6c619314aaba04c351d56e0",
"assets/assets/icons/adoptedpets.png": "8f835f6fa420dd88e173451ff681ebae",
"assets/assets/icons/adoptions.png": "ee82135a07ae92b8d9e58a03941f064c",
"assets/assets/icons/apawtmenticon.png": "22af82e2b262c349910d2012d48e3514",
"assets/assets/icons/appointment.png": "89c8ebfa8bb592c9ed3f33e07ffb888e",
"assets/assets/icons/approval.png": "15f4cf2638886531a968b956efcde7e8",
"assets/assets/icons/cats.png": "9f1a4aac6666317faf4fde473932b720",
"assets/assets/icons/chatsicon.png": "b2c12a392ba85552bd86898dcc1b7a4d",
"assets/assets/icons/dashboardicon.png": "684286ebced633e576836a66b762f29d",
"assets/assets/icons/disabilities.png": "d9286d86a22b3c40ff4738c54b0872be",
"assets/assets/icons/dogs.png": "244619e6662e44293e3792e46a394ff6",
"assets/assets/icons/donationicon.png": "e9b75e7f0bd18ee55bf16f09daac3921",
"assets/assets/icons/events.png": "cc8ccdd6da45665abddff637b557617d",
"assets/assets/icons/medications.png": "25420217b347af2edfda775ea940ec10",
"assets/assets/icons/petadoptions.png": "ab3c94cf8eb5de2b2ed77f0d68454169",
"assets/assets/icons/petmedication.png": "83dd0b9968beb652601c9eb398a42270",
"assets/assets/icons/petprofiles.png": "f7b3ae7f476b73ab3b31574939be6ee2",
"assets/assets/icons/petsicon.png": "5ee16750df988c93a8ba739e83ea1177",
"assets/assets/icons/reportsicon.png": "323ebec2c26cc5fa929bb01193f95015",
"assets/assets/icons/shelterprofiles.png": "19d301d8c76f04e256c6357dfe65ce9d",
"assets/assets/icons/shelterprojects.png": "4b008d28b0fbeb5af50010de4a5ac8c5",
"assets/assets/images/adminlogo.png": "5f0e16f9da0401fe01663d4d8da9180b",
"assets/assets/images/adoption.png": "7547ad93145e50456b2c0010e8818876",
"assets/assets/images/apawtmentdblogo.png": "5f0e16f9da0401fe01663d4d8da9180b",
"assets/assets/images/apawtmentlight.png": "5f0e16f9da0401fe01663d4d8da9180b",
"assets/assets/images/apawtmentlogo.png": "5f0e16f9da0401fe01663d4d8da9180b",
"assets/assets/images/apawtmentpetlogo.png": "5f0e16f9da0401fe01663d4d8da9180b",
"assets/assets/images/cats.png": "f5c37155d9dc48b1d6ca1ebba102bff3",
"assets/assets/images/dogs.png": "9e163d1e332f863cb7777b899d249da2",
"assets/assets/images/medication.png": "bbfc6a0c0a6ddb31ad2393abb468b25c",
"assets/assets/images/paws.png": "e32e71073f407108280c9914beac7374",
"assets/assets/images/profile.png": "3871c9ebe8fdd5a6c782e5d5a3aaea66",
"assets/assets/images/readytoadopt.png": "d1609dd44a9399f263b90819315e2c96",
"assets/assets/images/undermed.png": "9eb7e5dfd17f9a224d8b03e77ad41813",
"assets/assets/images/vaccination.png": "5e43ac3a01f248744ec0397b41205da0",
"assets/FontManifest.json": "234de1d57fe39f6e51e61a131bf1d4cc",
"assets/fonts/MaterialIcons-Regular.otf": "86bc7b941cad3b93ebfb7c72caf25920",
"assets/NOTICES": "9317f4ab3e546d6cc83601722de7c00b",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/flutter_inappwebview/assets/t_rex_runner/t-rex.css": "5a8d0222407e388155d7d1395a75d5b9",
"assets/packages/flutter_inappwebview/assets/t_rex_runner/t-rex.html": "16911fcc170c8af1c5457940bd0bf055",
"assets/packages/flutter_inappwebview_web/assets/web/web_support.js": "509ae636cfdd93e49b5a6eaf0f06d79f",
"assets/packages/flutter_map/lib/assets/flutter_map_logo.png": "208d63cc917af9713fc9572bd5c09362",
"assets/packages/google_places_flutter/images/location.json": "afa33acf2c340246c901718f4efdfccf",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206",
"favicon.png": "22af82e2b262c349910d2012d48e3514",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"flutter_bootstrap.js": "25163f5aca143860a544366604b5d420",
"icons/Icon-192.png": "22af82e2b262c349910d2012d48e3514",
"icons/Icon-512.png": "22af82e2b262c349910d2012d48e3514",
"icons/Icon-maskable-192.png": "22af82e2b262c349910d2012d48e3514",
"icons/Icon-maskable-512.png": "22af82e2b262c349910d2012d48e3514",
"index.html": "135efb893dfb9a62c02110d43443ce6f",
"/": "135efb893dfb9a62c02110d43443ce6f",
"main.dart.js": "e86089babbb82f949ea746589ce9a6ab",
"manifest.json": "0db4130fa213fc931db7243b67aeaf93",
"version.json": "82654d75d09b669ca74ed82cd93a6caa"};
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
