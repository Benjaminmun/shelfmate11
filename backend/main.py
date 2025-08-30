import firebase_admin
from firebase_admin import credentials, auth, firestore
from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
import logging

# Initialize Firebase Admin SDK with your service account
cred = credentials.Certificate("serviceAccountKey.json")  # Ensure the correct service account file
firebase_admin.initialize_app(cred)

# Initialize Firestore client
db = firestore.client()

# Initialize FastAPI app
app = FastAPI()

# Add CORS middleware to allow frontend access (adjust origins as needed)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Or set specific domains for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# OAuth2PasswordBearer provides the necessary abstraction for token-based auth
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Root endpoint to indicate the server is running
@app.get("/")
def read_root():
    return {"message": "FastAPI server is running successfully!"}

# Function to verify Firebase ID token
def verify_token(id_token: str):
    try:
        # Decode and verify the ID token using Firebase Admin SDK
        decoded_token = auth.verify_id_token(id_token)
        # Log the decoded token for debugging purposes
        logging.info(f"Decoded Token: {decoded_token}")
        return decoded_token
    except Exception as e:
        logging.error(f"Error verifying token: {str(e)}")
        return None

# Dependency to verify the Firebase token
def get_current_user(token: str = Depends(oauth2_scheme)):
    decoded_token = verify_token(token)
    if decoded_token is None:
        raise HTTPException(status_code=401, detail="Invalid or expired Firebase token.")
    return decoded_token

# Secure endpoint that requires Firebase authentication
@app.post("/secure-endpoint")
async def secure_endpoint(current_user: dict = Depends(get_current_user)):
    return {"message": "Authenticated", "user_info": current_user}

# Example of accessing Firestore with Firebase
@app.get("/get-user-data")
async def get_user_data(user_id: str, current_user: dict = Depends(get_current_user)):
    """
    Get user data from Firestore based on the user ID (you can customize this as needed).
    """
    try:
        user_ref = db.collection('users').document(user_id)
        user_data = user_ref.get()
        if user_data.exists:
            return user_data.to_dict()
        else:
            raise HTTPException(status_code=404, detail="User not found.")
    except Exception as e:
        logging.error(f"Error accessing Firestore: {e}")
        raise HTTPException(status_code=500, detail=str(e))
