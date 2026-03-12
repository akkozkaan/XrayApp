import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

import modal
import torch
import torch.nn as nn
from torchvision import models, transforms
import torchvision.transforms.functional as F
import io
import base64
import numpy as np
from PIL import Image
from fastapi import Request

model_weights_path = os.path.join(os.path.dirname(__file__), "model_weights")

# 1. ADDED APT_INSTALL FOR LINUX GRAPHICS ENGINES
image = (
    modal.Image.debian_slim()
    .apt_install("libgl1", "libglib2.0-0") # <--- THE FIX: Install OpenGL libraries
    .pip_install("torch", "torchvision", "pillow", "numpy", "fastapi[standard]", "grad-cam", "opencv-python-headless")
    .add_local_dir(model_weights_path, remote_path="/weights")
)

app = modal.App("xray-sota-engine")

# --- GLOBAL CONFIGURATIONS ---
CHEST_LABELS = [
    'No Finding', 'Enlarged Cardiomediastinum', 'Cardiomegaly', 'Lung Opacity',
    'Lung Lesion', 'Edema', 'Consolidation', 'Pneumonia', 'Atelectasis',
    'Pneumothorax', 'Pleural Effusion', 'Pleural Other', 'Fracture', 'Support Devices'
]
CHEST_THRESHOLDS = {
    'No Finding': 0.83, 'Enlarged Cardiomediastinum': 0.16, 'Cardiomegaly': 0.21,
    'Lung Opacity': 0.34, 'Lung Lesion': 0.30, 'Edema': 0.49, 'Consolidation': 0.54,
    'Pneumonia': 0.49, 'Atelectasis': 0.36, 'Pneumothorax': 0.61, 'Pleural Effusion': 0.46,
    'Pleural Other': 0.65, 'Fracture': 0.50, 'Support Devices': 0.22,
}
MURA_THRESHOLD = 0.40
MODELS_CACHE = {}

class PadToSquare:
    def __call__(self, img):
        w, h = img.size
        max_wh = max(w, h)
        padding = [(max_wh - w) // 2, (max_wh - h) // 2, (max_wh - w + 1) // 2, (max_wh - h + 1) // 2]
        return F.pad(img, padding, 0, 'constant')

def calibrate(raw_prob, threshold):
    if raw_prob < threshold:
        calibrated = (raw_prob / threshold) * 49.9
    else:
        calibrated = 50.0 + ((raw_prob - threshold) / (1.0 - threshold)) * 50.0
    return float(min(100.0, max(0.0, round(calibrated, 1))))

def get_models():
    if not MODELS_CACHE:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        
        chest = models.densenet121(weights=None)
        chest.features.conv0 = nn.Conv2d(1, 64, kernel_size=(7, 7), stride=(2, 2), padding=(3, 3), bias=False)
        chest.classifier = nn.Linear(chest.classifier.in_features, 14)
        chest.load_state_dict(torch.load("/weights/chexpert_sota_best.pth", map_location=device))
        MODELS_CACHE["chest"] = chest.to(device).eval()

        bone = models.densenet169(weights=None)
        bone.classifier = nn.Linear(bone.classifier.in_features, 1)
        bone.load_state_dict(torch.load("/weights/mura_sota_best.pth", map_location=device))
        MODELS_CACHE["bone"] = bone.to(device).eval()
        
    return MODELS_CACHE

@app.cls(image=image, gpu="T4", scaledown_window=15)
class XRayEngine:
    def __enter__(self):
        get_models()

    # THE FIX: Added `mode: str` to act as a Router
    @modal.fastapi_endpoint(method="POST")
    async def predict(self, request: Request, mode: str = "chest"):
        try:
            from pytorch_grad_cam import GradCAM
            from pytorch_grad_cam.utils.image import show_cam_on_image
            from pytorch_grad_cam.utils.model_targets import ClassifierOutputTarget

            models_dict = get_models()
            device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
            body = await request.body()

            if not body:
                return {"success": True, "message": "Server is hot and models are in VRAM."}

            raw_img = Image.open(io.BytesIO(body)).convert("RGB")

            # ==========================================================
            # ISOLATED BONE INFERENCE (Saves Credits!)
            # ==========================================================
            if mode == "bone":
                t_bone = transforms.Compose([
                    PadToSquare(),
                    transforms.Resize((512, 512)), # <-- UPDATE THIS TO 512
                    transforms.ToTensor(),
                    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
                ])
                
                img_bone = t_bone(raw_img).unsqueeze(0).to(device)
                
                # Grad-CAM Needs Gradients!
                with torch.set_grad_enabled(True):
                    img_bone.requires_grad = True
                    bone_out_tensor = models_dict["bone"](img_bone)
                    bone_out = torch.sigmoid(bone_out_tensor).item()
                    
                    # Target the final convolutional layer
                    target_layers = [models_dict["bone"].features.norm5]
                    cam = GradCAM(model=models_dict["bone"], target_layers=target_layers)
                    targets = [ClassifierOutputTarget(0)]
                    grayscale_cam = cam(input_tensor=img_bone, targets=targets)[0, :]
                
                bone_calibrated = calibrate(bone_out, MURA_THRESHOLD)
                
                # Align the base image exactly like the tensor for the overlay
                overlay_img = PadToSquare()(raw_img)
                overlay_img = F.resize(overlay_img, [512, 512])
                rgb_img_np = np.float32(overlay_img) / 255.0
                
                visualization = show_cam_on_image(rgb_img_np, grayscale_cam, use_rgb=True)
                
                # Convert Heatmap to Base64 String
                heatmap_pil = Image.fromarray(visualization)
                buffered = io.BytesIO()
                heatmap_pil.save(buffered, format="JPEG")
                heatmap_b64 = base64.b64encode(buffered.getvalue()).decode("utf-8")

                return {
                    "success": True,
                    "mura": {
                        "prediction": "Anomaly Detected" if bone_calibrated >= 50.0 else "Normal",
                        "confidence": bone_calibrated,
                        "heatmap": heatmap_b64
                    }
                }

            # ==========================================================
            # ISOLATED CHEST INFERENCE (Saves Credits!)
            # ==========================================================
            else:
                def txrv_normalize(tensor):
                    return (tensor * 2048) - 1024
                
                t_chest = transforms.Compose([
                    transforms.Resize(256),          # Eğitimdeki gibi önce 256'ya büyüt
                    transforms.CenterCrop(224),      # Sonra ortadan 224 kes
                    transforms.Grayscale(num_output_channels=1), # Siyah beyaza çevir
                    transforms.ToTensor(),           # 0.0 ile 1.0 arasına al
                    transforms.Lambda(txrv_normalize) # THE FIX: -1024 ile +1024 arasına genişlet!
                ])
                img_chest = t_chest(raw_img).unsqueeze(0).to(device)

                with torch.set_grad_enabled(True):
                    img_chest.requires_grad = True
                    chest_out_tensor = models_dict["chest"](img_chest)
                    chest_out = torch.sigmoid(chest_out_tensor)[0].cpu().detach().numpy()

                chest_results = {}
                disease_detected = False
                
                for i, label in enumerate(CHEST_LABELS):
                    raw_score = chest_out[i].item()
                    calibrated_score = calibrate(raw_score, CHEST_THRESHOLDS[label])
                    chest_results[label] = {"finding": label, "confidence": calibrated_score}
                    
                    if label not in ['No Finding', 'Support Devices'] and calibrated_score >= 50.0:
                        disease_detected = True

                if disease_detected:
                    chest_results['No Finding']['confidence'] = 0.0
                elif chest_results['No Finding']['confidence'] < 50.0:
                    chest_results['No Finding']['confidence'] = 99.0

                sorted_chest = sorted(list(chest_results.values()), key=lambda x: x["confidence"], reverse=True)
                
                # Grad-CAM Focuses solely on the TOP predicted disease
                best_class_name = sorted_chest[0]["finding"]
                best_idx = CHEST_LABELS.index(best_class_name)

                with torch.set_grad_enabled(True):
                    target_layers = [models_dict["chest"].features.norm5]
                    cam = GradCAM(model=models_dict["chest"], target_layers=target_layers)
                    targets = [ClassifierOutputTarget(best_idx)]
                    grayscale_cam = cam(input_tensor=img_chest, targets=targets)[0, :]
                
                # Align the base image exactly like the tensor (CenterCrop)
                overlay_img = F.resize(raw_img, 256)
                overlay_img = F.center_crop(overlay_img, 224)
                rgb_img_np = np.float32(overlay_img) / 255.0
                
                visualization = show_cam_on_image(rgb_img_np, grayscale_cam, use_rgb=True)
                
                heatmap_pil = Image.fromarray(visualization)
                buffered = io.BytesIO()
                heatmap_pil.save(buffered, format="JPEG")
                heatmap_b64 = base64.b64encode(buffered.getvalue()).decode("utf-8")

                return {
                    "success": True,
                    "chest": {
                        "top_findings": sorted_chest[:3],
                        "heatmap": heatmap_b64
                    }
                }

        except Exception as e:
            return {"success": False, "error": str(e)}