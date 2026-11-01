// Service worker · Materia Prima La Vaca Original
// Permite instalar la app y abrirla aunque falle el internet (los datos siempre vienen de Supabase).
const CACHE = 'mp-v1';
const SHELL = ['./', './index.html', './manifest.webmanifest', './icon-192.png', './icon-512.png', './icon-maskable-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== location.origin) return; // Supabase y librerías: siempre directo a internet
  // Primero internet (para recibir siempre la última versión); si no hay conexión, la copia guardada
  e.respondWith(
    fetch(e.request).then(r => { const copy = r.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); return r })
      .catch(() => caches.match(e.request).then(r => r || caches.match('./index.html')))
  );
});
