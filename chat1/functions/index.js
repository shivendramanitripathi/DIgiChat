const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotification = functions.firestore
    .document('messages/{groupId1}/{groupId2}/{message}')
    .onCreate((snap, context) => {
        console.log('---------------Start Function---------------------');

        const doc = snap.data();
        console.log(doc);

        const idFrom = doc.idFrom; // Corrected variable name
        const idTo = doc.idTo;
        const contentMessage = doc.content;

        admin
            .firestore()
            .collection('users')
            .where('id', '==', idTo)
            .get()
            .then(querySnapshot => {
                querySnapshot.forEach(userTo => {
                    console.log(`Found user to: ${userTo.data().nickname}`);
                    if (userTo.data().pushToken && userTo.data().chattingWith !== idFrom) {

                        admin
                            .firestore()
                            .collection('users')
                            .where('id', '==', idFrom)
                            .get()
                            .then(querySnapshot2 => {
                                querySnapshot2.forEach(userFrom => {
                                    console.log(`Found user from: ${userFrom.data().nickname}`);
                                    const payload = {
                                        notification: {
                                            title: `You have a message from "${userFrom.data().nickname}"`,
                                            body: contentMessage,
                                            badge: '1',
                                            sound: 'default'
                                        }
                                    };

                                    admin
                                        .messaging()
                                        .sendToDevice(userTo.data().pushToken, payload)
                                        .then(response => {
                                            console.log('Successfully sent message:', response);
                                        })
                                        .catch(error => {
                                            console.error('Error sending message:', error);
                                        });
                                });
                            })
                            .catch(error => {
                                console.error('Error fetching userFrom:', error);
                            });
                    } else {
                        console.log('Cannot find pushToken for target user');
                    }
                });
            })
            .catch(error => {
                console.error('Error fetching userTo:', error);
            });

        return null;
    });
