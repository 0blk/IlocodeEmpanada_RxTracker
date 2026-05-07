# RxTracker Setup Guide

This guide explains how to set up and run the RxTracker project locally.

## 1. Backend Setup (FastAPI)

### Prerequisites
- Python 3.10 or higher
- A Google Gemini API Key (Get one from [Google AI Studio](https://aistudio.google.com/))

### Installation
1. Navigate to the backend directory:
   ```powershell
   cd rxtracker/backend
   ```
2. Install the required dependencies:
   ```powershell
   pip install -r requirements.txt
   # Ensure the new AI SDK is installed:
   pip install google-genai
   ```

### Configuration
1. Create a file named `.env` in the `rxtracker/backend/` folder.
2. Add your Gemini API Key to the file:
   ```env
   GEMINI_API_KEY=your_actual_api_key_here
   ```

### Running the Server
Start the backend on port 8080 (the port configured in the Flutter app):
```powershell
uvicorn main:app --host 127.0.0.1 --port 8080 --reload
```
You can verify the server is running by visiting `http://127.0.0.1:8080/health` in your browser.

---

## 2. Frontend Setup (Flutter)

### Prerequisites
- Flutter SDK installed and configured.
- Google Chrome (for web development).

### Installation
1. Navigate to the flutter app directory:
   ```powershell
   cd rxtracker/flutter_app
   ```
2. Fetch dependencies:
   ```powershell
   flutter pub get
   ```

### Running the App
Run the application in Chrome:
```powershell
flutter run -d chrome
```

---

## 3. Troubleshooting

### Connection Issues ("Failed to fetch")
- Ensure the backend is running on **port 8080**.
- If running on Web, ensure you are using `127.0.0.1` instead of `localhost` in your browser if prompted.
- Check the Python terminal for any `!!! Server Error` messages.

### AI Scanning Problems
- If scanning returns "No Medicines Detected," check the terminal for API errors.
- Ensure your API Key has access to the `gemini-3-flash-preview` model.
- If you see `400 API key expired`, generate a new key from AI Studio.
