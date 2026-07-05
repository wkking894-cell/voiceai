 var CACHE = 'voiceai-v1';
 var FILES = ['app.html', 'manifest.json', 'icon.svg'];
 
 self.addEventListener('install', function(e) {
   e.waitUntil(
     caches.open(CACHE).then(function(c) {
       return c.addAll(FILES);
     }).then(function() { return self.skipWaiting(); })
   );
 });
 
 self.addEventListener('activate', function(e) {
   e.waitUntil(clients.claim());
 });
 
 self.addEventListener('fetch', function(e) {
   e.respondWith(
     caches.match(e.request).then(function(r) {
       return r || fetch(e.request).then(function(resp) {
         var copy = resp.clone();
         caches.open(CACHE).then(function(c) { c.put(e.request, copy); });
         return resp;
       });
     }).catch(function() {
       return new Response('离线中', { status: 200, statusText: 'OK' });
     })
   );
 });
