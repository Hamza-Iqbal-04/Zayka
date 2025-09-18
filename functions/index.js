const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.arrivalNotified = onDocumentUpdated("Orders/{orderId}", async (event) => {
  // Get the data from before and after the event
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();

  // Check if arrivedAt was just set to true
  if (!beforeData.arrivedAt && afterData.arrivedAt) {
    const orderId = event.params.orderId;
    const customerId = afterData.customerId; // Assuming customerId is stored in the order

    // Get the user's FCM token from Firestore
    const userDoc = await admin.firestore().collection("Users").doc(customerId).get();

    if (!userDoc.exists) {
      console.log("User document not found for customer:", customerId);
      return null;
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log("No FCM token for user:", customerId);
      return null;
    }

    // Notification content
    const message = {
      notification: {
        title: "Your food is arriving! 🚴‍♂️",
        body: "Rider is near your location. Get ready to receive your order."
      },
      data: {
        type: "arrival",
        orderId: orderId,
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      },
      token: fcmToken,
      android: {
        priority: "high",
        notification: {
        channel_id: "driver_arrival_channel",
        },
      },
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
            alert: {
              title: "Your food is arriving! 🚴‍♂️",
              body: "Rider is near your location. Get ready to receive your order."
            },
            sound: "default"
          }
        }
      }
    };

    // Send the notification
    try {
      await admin.messaging().send(message);
      console.log("Arrival notification sent successfully to:", customerId);
      return { success: true, message: "Notification sent" };
    } catch (error) {
      console.error("Error sending notification:", error);
      return { success: false, error: error.message };
    }
  }

  return null;
});
