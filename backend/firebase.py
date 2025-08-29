import firebase_admin
from firebase_admin import credentials, auth, firestore
from firebase_admin.exceptions import FirebaseError
import logging

# Initialize Firebase Admin SDK with your service account
cred = credentials.Certificate("serviceAccountKey.json")  # Ensure the correct service account file
firebase_admin.initialize_app(cred)

# Initialize Firestore client
db = firestore.client()

# Function to verify Firebase ID token
def verify_token(id_token: str):
    try:
        # Decode and verify the ID token using Firebase Admin SDK
        decoded_token = auth.verify_id_token(id_token)
        
        # Log the decoded token for debugging purposes
        logging.info(f"Decoded Token: {decoded_token}")
        
        # Return the decoded token, which contains user information (UID, email, etc.)
        return decoded_token
    except auth.ExpiredIdTokenError:
        # Handle expired token scenario
        logging.error("The ID token has expired.")
        return None
    except auth.RevokedIdTokenError:
        # Handle revoked token scenario
        logging.error("The ID token has been revoked.")
        return None
    except auth.InvalidIdTokenError:
        # Handle invalid token format or malformed token
        logging.error("The ID token is invalid (incorrect format or malformed).")
        return None
    except FirebaseError as e:
        # General Firebase-related error (network issues, etc.)
        logging.error(f"Error verifying token: {str(e)}")
        return None
