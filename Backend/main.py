import os
import base64
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
import httpx
from google import genai
from google.genai import types

app = FastAPI()

# IMPORTANT: Update this URL after deploying the new app.py to Modal!
MODAL_URL = "https://y20035241--xray-sota-engine-xrayengine-predict.modal.run"

# Vercel Environment Variable
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

async def generate_ai_message(mode: str, findings_data, heatmap_b64: str, lang: str) -> str:
    """Passes the Grad-CAM image and the exact percentiles to the VLM for a natural language summary."""
    if not GEMINI_API_KEY:
        return "AI analysis unavailable: Missing API Key on server."
        
    try:
        client = genai.Client(api_key=GEMINI_API_KEY)
        
        # Prepare the Base64 image for Gemini
        image_part = types.Part.from_bytes(
            data=base64.b64decode(heatmap_b64),
            mime_type="image/jpeg"
        )
        
        language_instruction = f"IMPORTANT: Write your entire response in the language code '{lang}' (e.g., 'tr' for Turkish, 'en' for English)."
        
        # Dynamically prompt based on the comprehensive label output or bone anomaly
        if mode == "chest":
            prompt = f"""
            You are the advanced medical AI vision model that just analyzed this chest X-ray. 
            Speak  to the user in the formal way (e.g., "Uploaded X-Ray shows that", Based on the analyze").
            Here are your own top findings and calibrated confidence scores across the full label set: {findings_data}
            Tell what in the Grad-CAM heatmap led you to these conclusions. For example, if "Cardiomegaly" had a high confidence, you might say "The highlighted areas around the heart suggest an enlarged cardiac silhouette, which is consistent with cardiomegaly." Make correlations between the heatmap activations and the specific findings in the report.
            Avoid giving the impression that you know the exact results. Instead, speak in terms of probabilities and mean that the findings are one of the probabilites.

            Task: Write a concise, 4-sentence summary of your findings.
                    Conclude with: 'Please be aware that this is only an AI observation based on activation areas, and is not a definitive medical diagnosis. The AI models make mistakes. Always consult with a qualified healthcare professional for an accurate diagnosis and appropriate medical advice.'
            {language_instruction}
            """
        else:
            prompt = f"""
            You are the advanced medical AI vision model that just analyzed this Fracture x-ray. 
            Speak  to the user in the formal way (e.g., "Uploaded X-Ray shows that", Based on the analyze").
            Here are your own top findings and calibrated confidence scores across the full label set: {findings_data}
            Tell what in the Grad-CAM heatmap led you to these conclusions. For example, if "Cardiomegaly" had a high confidence, you might say "The highlighted areas around the heart suggest an enlarged cardiac silhouette, which is consistent with cardiomegaly." Make correlations between the heatmap activations and the specific findings in the report.
            Avoid giving the impression that you know the exact results. Instead, speak in terms of probabilities and mean that the findings are one of the probabilites.

            Task: Write a concise, 4-sentence summary of your findings.
            Conclude with: 'Please be aware that this is only an AI observation based on activation areas, and is not a definitive medical diagnosis. The AI models make mistakes. Always consult with a qualified healthcare professional for an accurate diagnosis and appropriate medical advice.'
            {language_instruction}
            """
            
        # We use flash because it is insanely fast and cheap for this specific task
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=[image_part, prompt]
        )
        return response.text
        
    except Exception as e:
        print(f"VLM Error: {str(e)}")
        return "The AI was unable to generate a summary at this time."

@app.get("/")
def read_root():
    return {"status": "VLM AI Active!"}

@app.get("/warmup")
async def warmup_server():
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            await client.post(MODAL_URL, content=b"")
        except Exception:
            pass 
    return {"success": True, "status": "Modal container is warming up"}

@app.post("/analyze")
async def analyze_image(
    file: UploadFile = File(...), 
    mode: str = Form("chest"),
    lang: str = Form("en")
):
    content = await file.read()
    
    # 1. Talk to Modal (Get the math and the image)
    async with httpx.AsyncClient(timeout=55.0) as client:
        try:
            response = await client.post(f"{MODAL_URL}?mode={mode}", content=content)
            response.raise_for_status()
            data = response.json()
        except Exception as e:
            print(f"Connection Error: {str(e)}")
            return {"success": False, "error": f"Connection Error: {str(e)}"}

    if data.get("success") == False:
        return {"success": False, "error": f"Modal Error: {data.get('error', 'Unknown')}"}

    try:
        # 2. Extract Data
        is_bone = (mode == "bone")
        findings = data["mura"] if is_bone else data["chest"]["top_findings"]
        heatmap_b64 = data.get("mura" if is_bone else "chest", {}).get("heatmap")
        
        # 3. Ask the VLM to interpret it
        ai_message = await generate_ai_message(mode, findings, heatmap_b64, lang)

        # 4. Return everything to the Flutter App
        return {
            "success": True, 
            "ai_message": ai_message, # <--- The new magic string
            "type": "Bone Analysis" if is_bone else "Chest Analysis",
            "report": findings,
            "heatmap": heatmap_b64
        }
            
    except KeyError as e:
        return {"success": False, "error": f"Missing key: {str(e)}", "raw_data": data}