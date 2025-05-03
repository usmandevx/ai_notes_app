# AI Notes Manager

## App Features

- **Voice Command Note Management**: The app allows users to manage notes via voice commands. Users can create, update, and delete notes using voice input.
- **Notes List**: Displays all the notes created by the user, including their title, content, and timestamp.
- **Note Management**: The user can view a list of notes and perform actions like editing or deleting them.
- **Speech-to-Text Integration**: The app uses the `speech_to_text` package to convert spoken commands into text.
- **Local Database (Hive)**: Note data is stored locally using the Hive database. Notes are persisted across app sessions.
- **Gemini LLM Integration**: The app integrates with a Gemini-based API to interpret voice commands and extract actionable data for note management, such as note title, content, and timestamp.

## Setup Instructions

### Prerequisites
1. **Flutter SDK**: Ensure you have Flutter SDK installed. If not, install it from [flutter.dev](https://flutter.dev/docs/get-started/install).
2. **Hive Database**: The app uses Hive for local storage. Ensure the `hive` and `hive_flutter` packages are included in your `pubspec.yaml` file.
3. **Environment Variables**: Set the following environment variables for Gemini API:
    - `API_KEY`: The API key for Gemini.
    - `API_URL`: The endpoint for Gemini API.
    - `SYSTEM_PROMPT`: A system template used to structure user commands.
      These variables should be loaded from a `.env` file using the `flutter_dotenv` package.

### Steps to Run the App

1. **Clone the repository**:
   ```bash
   git clone https://github.com/usmandevx/ai_notes_app.git
