# Google Play Billing - Testing Guide

This guide shows you how to test the Google Play billing functions locally and in production.

## Function URLs

All functions are deployed to Firebase Cloud Functions. Here are the endpoints:

- **Health Check**: `https://health-e6nnsvcsrq-uc.a.run.app`
- **Record Subscription**: `https://us-central1-driveerp-1d5d5.cloudfunctions.net/recordPlaySubscription`
- **Refresh Subscription**: `https://us-central1-driveerp-1d5d5.cloudfunctions.net/refreshPlaySubscription`
- **Get Entitlement Status**: `https://us-central1-driveerp-1d5d5.cloudfunctions.net/getEntitlementStatus`
- **RTDN Listener**: Pub/Sub topic `projects/driveerp-1d5d5/topics/driver-erp-google-play-rtdn` (automatic)
- **Apple Webhook**: `https://appleservernotifications-e6nnsvcsrq-uc.a.run.app` (receives POST)

---

## Testing with cURL

### 1. Health Check

```bash
curl -X GET https://health-e6nnsvcsrq-uc.a.run.app
# Expected: 200 OK
```

### 2. Record a Subscription (After Purchase in Play Store)

```bash
curl -X POST \
  https://us-central1-driveerp-1d5d5.cloudfunctions.net/recordPlaySubscription \
  -H "Content-Type: application/json" \
  -d '{
    "uid": "user123",
    "packageName": "com.yourapp.package",
    "subscriptionId": "monthly.subscription",
    "purchaseToken": "YOUR_PURCHASE_TOKEN_HERE",
    "companyId": "company-abc",
    "moduleId": "crm",
    "payerType": "self",
    "payerUid": "user123"
  }'
```

**Response (success):**
```json
{
  "success": true,
  "entitlementId": "user123_crm",
  "expiryTime": "2026-03-17T12:34:56.000Z",
  "autoRenewing": true
}
```

**Response (failure - bad token):**
```
Subscription verification failed (401)
```

### 3. Refresh a Subscription

```bash
curl -X POST \
  https://us-central1-driveerp-1d5d5.cloudfunctions.net/refreshPlaySubscription \
  -H "Content-Type: application/json" \
  -d '{
    "purchaseToken": "YOUR_PURCHASE_TOKEN_HERE"
  }'
```

**Response:**
```json
{
  "success": true,
  "status": "active",
  "expiryTime": "2026-03-17T12:34:56.000Z",
  "autoRenewing": true
}
```

### 4. Check Entitlement Status

```bash
curl -X POST \
  https://us-central1-driveerp-1d5d5.cloudfunctions.net/getEntitlementStatus \
  -H "Content-Type: application/json" \
  -d '{
    "uid": "user123",
    "companyId": "company-abc",
    "moduleId": "crm"
  }'
```

**Response (has access):**
```json
{
  "status": "active",
  "hasAccess": true,
  "renewalDate": "2026-03-17T12:34:56.000Z",
  "autoRenewing": true,
  "payerType": "self",
  "source": "google",
  "lastVerifiedAt": "2026-02-17T10:00:00.000Z"
}
```

**Response (no subscription):**
```json
{
  "status": "none",
  "hasAccess": false
}
```

---

## Testing in Firestore

To see results of your calls:

### 1. View Subscription Records
- Go to [Firebase Console](https://console.firebase.google.com/project/driveerp-1d5d5/firestore)
- Collection: `subscriptions`
- Document ID: `YOUR_PURCHASE_TOKEN_HERE`
- Fields to check: `status`, `autoRenewing`, `expiryTime`, `lastVerifiedAt`

### 2. View Entitlements
- Go to [Firebase Console](https://console.firebase.google.com/project/driveerp-1d5d5/firestore)
- Path: `companies/{companyId}/entitlements/{uid}_{moduleId}`
- Example: `companies/company-abc/entitlements/user123_crm`
- Fields to check: `status`, `hasAccess`, `renewalDate`

### 3. View Billing Events
- Go to [Firebase Console](https://console.firebase.google.com/project/driveerp-1d5d5/firestore)
- Collection: `billingEvents`
- View all logged events (subscription records, refreshes, RTDN messages)

---

## Testing Real Purchases

### From Your App

1. **Complete Play Store purchase** in your app using the Play Billing Library
2. **Call `recordPlaySubscription`** with the returned `purchaseToken` from the purchase flow
3. **Check Firestore** to verify subscription and entitlement were created
4. **Call `getEntitlementStatus`** to confirm user has access

### From Google Play Testing

1. Add test users in [Google Play Console](https://play.google.com/console)
2. Install app on test device and make purchases
3. Purchases will be free but trigger real RTDN messages
4. Monitor function logs and Firestore

---

## Monitoring and Debugging

### View Function Logs

```bash
firebase functions:log --only billing:recordPlaySubscription
firebase functions:log --only billing:refreshPlaySubscription
firebase functions:log --only billing:getEntitlementStatus
firebase functions:log --only billing:googlePlayRtdn
```

### View Specific Logs in Console

1. Go to [Cloud Functions](https://console.cloud.google.com/functions/list?project=driveerp-1d5d5)
2. Click function name (e.g., `recordPlaySubscription`)
3. Go to **Logs** tab
4. Filter by time range

### Check Pub/Sub Messages (RTDN)

```bash
export PATH="/opt/homebrew/share/google-cloud-sdk/bin:$PATH"
gcloud pubsub subscriptions pull driver-erp-google-play-rtdn-sub --project=driveerp-1d5d5 --auto-ack --limit=10
```

---

## Postman Collection (Optional)

You can import these requests into [Postman](https://www.postman.com):

```json
{
  "info": {
    "name": "DriverERP Billing",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Health Check",
      "request": {
        "method": "GET",
        "url": "https://health-e6nnsvcsrq-uc.a.run.app"
      }
    },
    {
      "name": "Record Subscription",
      "request": {
        "method": "POST",
        "url": "https://us-central1-driveerp-1d5d5.cloudfunctions.net/recordPlaySubscription",
        "header": [{"key": "Content-Type", "value": "application/json"}],
        "body": {
          "mode": "raw",
          "raw": "{\"uid\":\"user123\",\"packageName\":\"com.yourapp\",\"subscriptionId\":\"monthly\",\"purchaseToken\":\"token\",\"companyId\":\"company-abc\",\"moduleId\":\"crm\"}"
        }
      }
    }
  ]
}
```

---

## Troubleshooting

### "Subscription verification failed"
- Purchase token is invalid or expired
- Verify token format matches Play Store's output
- Check that `packageName` and `subscriptionId` match your Play Console config

### "Subscription not found" (refresh fails)
- Call `recordPlaySubscription` first to create the subscription record
- Check Firestore to ensure purchase token was saved

### "Missing required fields"
- Review request body - ensure all required fields are present
- Compare with examples above

### No logs appearing
- Check Cloud Functions > Logs tab in Firebase Console
- Ensure function was deployed successfully (check deploy output)
- Wait a few seconds - logs can be delayed

### RTDN not triggering
- Verify topic name: `projects/driveerp-1d5d5/topics/driver-erp-google-play-rtdn`
- Ensure subscription is active in Play Console
- Check Pub/Sub topic has messages (use gcloud CLI)

---

## Integration with App

From your Flutter/Dart app, after Play Store purchase:

```dart
final response = await http.post(
  Uri.parse('https://us-central1-driveerp-1d5d5.cloudfunctions.net/recordPlaySubscription'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'uid': currentUser.id,
    'packageName': 'com.yourapp.package',
    'subscriptionId': purchaseDetails.productID,
    'purchaseToken': purchaseDetails.purchaseToken,
    'companyId': userCompanyId,
    'moduleId': selectedModuleId,
  }),
);

if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
  print('Entitlement created: ${data['entitlementId']}');
} else {
  print('Error: ${response.body}');
}
```

---

## Next Steps

- [ ] Test with real Play Store purchases
- [ ] Integrate `recordPlaySubscription` in app's purchase flow
- [ ] Set up periodic calls to `refreshPlaySubscription` (daily/weekly)
- [ ] Monitor `getEntitlementStatus` before granting module access
- [ ] Set up alerts for RTDN failures in Cloud Monitoring
