importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyBrgDB_v4WbyBHwSkVA9WIpPdDFGqt5Bnk",
  authDomain: "tracking-tots.firebaseapp.com",
  projectId: "tracking-tots",
  storageBucket: "tracking-tots.firebasestorage.app",
  messagingSenderId: "1089758434564",
  appId: "1:1089758434564:web:a55826cf93dbcc2c392c51",
  measurementId: "G-WQ8RY8NBCR"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png' // customize this!
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
