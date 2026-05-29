importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
    apiKey: 'AIzaSyB4d-KJheh1bXJxTBSInO4B8dgwVW07gO0',
    appId: '1:33041190550:web:376defc727f41bde963cb7',
    messagingSenderId: '33041190550',
    projectId: 'device-streaming-d7021871',
    authDomain: 'device-streaming-d7021871.firebaseapp.com',
    storageBucket: 'device-streaming-d7021871.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/app/icons/Icon-192.png'
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
