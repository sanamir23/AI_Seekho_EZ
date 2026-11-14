import os
from dotenv import load_dotenv
load_dotenv()

def test_audio():
    import google.generativeai as genai
    genai.configure(api_key=os.environ["GEMINI_API_KEY"])
    
    with open("test.mp3", "rb") as f:
        content = f.read()
    
    mime = "audio/mp3"
    model = genai.GenerativeModel("gemini-flash-latest")
    
    print("Sending audio to Gemini...")
    try:
        response = model.generate_content([
            "Transcribe the following audio accurately in its original language. If the audio is empty or you cannot hear anything, return nothing.",
            {"mime_type": mime, "data": content},
        ])
        print("Response:", response.text)
    except Exception as e:
        print("Error:", repr(e))

if __name__ == "__main__":
    test_audio()
