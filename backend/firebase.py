import firebase_admin
from firebase_admin import credentials, firestore, auth

# Function to initialize Firebase
def init_firebase():
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    return db

# Function to verify Firebase ID token
def verify_token(id_token):
    try:
        # Decode the ID token and verify it
        decoded_token = auth.verify_id_token(id_token)
        return decoded_token
    except Exception as e:
        # If verification fails, return None
        return None
