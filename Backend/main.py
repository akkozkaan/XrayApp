import os
import base64
import secrets
from fastapi import FastAPI, UploadFile, File, Form, Header
from fastapi.responses import JSONResponse
import httpx
from google import genai
from google.genai import types

app = FastAPI()

# IMPORTANT: Update this URL after deploying the new app.py to Modal!
MODAL_URL = "https://y20035241--xray-sota-engine-xrayengine-predict.modal.run"

# Vercel Environment Variable
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
BACKEND_API_KEY = os.environ.get("BACKEND_API_KEY")
DEFAULT_MAX_UPLOAD_BYTES = 10 * 1024 * 1024
ALLOWED_CONTENT_TYPE_PREFIX = "image/"
CHUNK_SIZE_BYTES = 1024 * 1024

try:
    MAX_UPLOAD_BYTES = int(os.environ.get("MAX_UPLOAD_BYTES", DEFAULT_MAX_UPLOAD_BYTES))
except ValueError:
    MAX_UPLOAD_BYTES = DEFAULT_MAX_UPLOAD_BYTES

if MAX_UPLOAD_BYTES <= 0:
    MAX_UPLOAD_BYTES = DEFAULT_MAX_UPLOAD_BYTES

def error_response(status_code: int, message: str):
    return JSONResponse(
        status_code=status_code,
        content={"success": False, "error": message}
    )

def authorize_request(api_key: str | None):
    if not BACKEND_API_KEY:
        return error_response(503, "Server auth is not configured.")
    if not api_key:
        return error_response(401, "Missing API key.")
    expected_key = str(BACKEND_API_KEY)
    provided_key = str(api_key)
    if not secrets.compare_digest(provided_key, expected_key):
        return error_response(403, "Invalid API key.")
    return None

async def read_upload_limited(file: UploadFile, max_bytes: int) -> bytes | None:
    total = 0
    chunks = []
    while True:
        chunk = await file.read(CHUNK_SIZE_BYTES)
        if not chunk:
            break
        total += len(chunk)
        if total > max_bytes:
            return None
        chunks.append(chunk)
    return b"".join(chunks)

def is_supported_image_content(content: bytes) -> bool:
    if len(content) < 4:
        return False

    return (
        content.startswith(b"\xFF\xD8\xFF")  # JPEG
        or content.startswith(b"\x89PNG\r\n\x1a\n")  # PNG
        or content.startswith((b"GIF87a", b"GIF89a"))  # GIF
        or content.startswith(b"BM")  # BMP
        or content.startswith((b"II*\x00", b"MM\x00*"))  # TIFF
        or (len(content) > 12 and content.startswith(b"RIFF") and content[8:12] == b"WEBP")  # WEBP
    )

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
async def warmup_server(x_api_key: str | None = Header(default=None, alias="X-API-KEY")):
    auth_error = authorize_request(x_api_key)
    if auth_error:
        return auth_error

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
    lang: str = Form("en"),
    x_api_key: str | None = Header(default=None, alias="X-API-KEY")
):
    auth_error = authorize_request(x_api_key)
    if auth_error:
        return auth_error

    if not file.content_type or not file.content_type.startswith(ALLOWED_CONTENT_TYPE_PREFIX):
        return error_response(415, "Only image uploads are allowed.")

    content = await read_upload_limited(file, MAX_UPLOAD_BYTES)
    if content is None:
        return error_response(413, f"File too large. Max allowed is {MAX_UPLOAD_BYTES} bytes.")
    if not content:
        return error_response(400, "Uploaded file is empty.")
    if not is_supported_image_content(content):
        return error_response(415, "Uploaded file content is not a supported image format.")
    
    # 1. Talk to Modal (Get the math and the image)
    async with httpx.AsyncClient(timeout=55.0) as client:
        try:
            response = await client.post(f"{MODAL_URL}?mode={mode}", content=content)
            response.raise_for_status()
            data = response.json()
        except Exception as e:
            print(f"Connection Error: {str(e)}")
            return {"success": False, "error": "Connection Error: Inference service unavailable."}

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
            
    except KeyError:
        return {"success": False, "error": "Missing expected fields in inference response."}
