![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![PyTorch](https://img.shields.io/badge/PyTorch-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white)
![Modal](https://img.shields.io/badge/Modal-000000?style=for-the-badge&logo=modal&logoColor=white)
![Vercel](https://img.shields.io/badge/Vercel-000000?style=for-the-badge&logo=vercel&logoColor=white)
![Gemini](https://img.shields.io/badge/Gemini-8E75B2?style=for-the-badge&logo=googlebard&logoColor=white)

An end-to-end, serverless mobile application designed to assist medical professionals in detecting thoracic (chest) and musculoskeletal (bone) pathologies from X-ray images. This project overcomes mobile hardware limitations by utilizing a distributed cloud architecture while providing dual-layer Explainable AI (XAI) for clinical transparency.

## 🚀 Key Engineering Features

* **Thin Client Architecture:** The heavy Deep Learning models are entirely offloaded to the cloud. The compiled Flutter app is incredibly lightweight (~30 MB) and consumes minimal RAM (150-200 MB), allowing it to run flawlessly on low-end devices without OOM (Out of Memory) errors.
* **Serverless GPU & Docker Image Baking:** Hosted on Modal's serverless NVIDIA T4 GPUs. To eliminate "Cold-Start" and network download delays, the massive `.pth` weight files are "baked" directly into the GPU container image during deployment.
* **Dual-Layer Explainable AI (XAI):** Solves the AI "Black-Box" problem. 
    1.  **Visual:** Generates spatial Grad-CAM heatmaps to pinpoint anomalies.
    2.  **Textual:** Integrates the Gemini API with strict Prompt Engineering to synthesize deterministic, hallucination-free medical reports explaining *why* the AI made its decision.
* **Dynamic Threshold Normalization:** Uses piecewise linear interpolation at the API Gateway level to normalize dynamically optimized, disease-specific thresholds (e.g., $T=0.36$, $T=0.83$) to a standard 50% baseline for a frictionless UX.
* **Zero-Retention Privacy:** Operates statelessly. X-ray images are processed entirely in the ephemeral VRAM and are immediately discarded after analysis, ensuring strict patient data privacy (KVKK/HIPAA compliance).

## 🧠 AI Models & Performance

The system utilizes a Dual-Engine architecture trained on gold-standard datasets:

1.  **Thoracic Engine (DenseNet-121):** Trained on the CheXpert dataset to detect 9 macro-pathologies (e.g., Pleural Effusion, Lung Opacity). Utilizes dynamic algorithmic thresholds to achieve high F1-Scores.
2.  **Musculoskeletal Engine (DenseNet-169):** Trained on the MURA dataset for fracture detection. Employs a custom `Pad-To-Square` preprocessing algorithm and $512\times512$ high-resolution matrices to preserve high-frequency signals, achieving an 82.2% F1-Score for hairline fractures.

## 🏗️ System Architecture

1.  **Client (Flutter):** Captures/Uploads the X-Ray, encodes it to Base64, and sends it via TLS 1.3 encryption.
2.  **API Gateway (Vercel):** Authenticates the request and routes it to the GPU cluster.
3.  **Inference Server (Modal):** Loads the baked models into VRAM, executes the PyTorch inference, generates the Grad-CAM, and queries the LLM.
4.  **LLM (Gemini API):** Generates the textual medical report based on X-ray classifications.

## ⚙️ Installation & Setup

### Prerequisites
* Flutter SDK (>= 3.0.0)
* Python (>= 3.10)
* Modal Account & Token (`modal token new`)
* Gemini API Key

### Backend Setup (Modal)
1. Navigate to the backend directory:
   ```bash
   cd backend
Install Modal client:

Bash
pip install modal
Add your model .pth download links and Gemini API key to the environment variables.

Deploy the serverless GPU function:

Bash
modal deploy main.py
Frontend Setup (Flutter)
Navigate to the app directory:

Bash
cd app
Install dependencies:

Bash
flutter pub get
Update the API Endpoint in lib/services/api_service.dart with your Vercel/Modal URL.

Run the app:

Bash
flutter run
⚠️ Medical Disclaimer
This application is a proof-of-concept and an academic research project. It is not an FDA-approved medical device. The AI-generated heatmaps and reports are strictly for observational and decision-support purposes. Final diagnostic authority always rests with a qualified medical professional.
