import asyncio
import os
from dotenv import load_dotenv

load_dotenv()

async def test_langchain():
    from langchain_google_genai import ChatGoogleGenerativeAI
    print("Testing LangChain ChatGoogleGenerativeAI...")
    try:
        llm = ChatGoogleGenerativeAI(
            model=os.environ.get("GEMINI_MODEL", "gemini-2.0-flash-lite"),
            google_api_key=os.environ["GEMINI_API_KEY"]
        )
        res = llm.invoke("Say hello")
        print("LangChain Success:", res.content)
    except Exception as e:
        print("LangChain Error:", repr(e))

def test_genai():
    import google.generativeai as genai
    print("Testing google.generativeai...")
    try:
        genai.configure(api_key=os.environ["GEMINI_API_KEY"])
        model = genai.GenerativeModel("gemini-flash-latest")
        res = model.generate_content("Say hello")
        print("genai Success:", res.text)
    except Exception as e:
        print("genai Error:", repr(e))

async def main():
    test_genai()
    await test_langchain()

if __name__ == "__main__":
    asyncio.run(main())
