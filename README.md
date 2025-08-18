# 🦆 QuackFit – AI-Powered Fitness App
QuackFit is a **Capstone Project mobile fitness app** that uses **AI** and **cloud technologies** to deliver:  
✅ Personalized workout plans  
✅ Motivational quotes  
✅ Fitness images  

---

## 📌 About This Repository
This repo showcases my contributions in:
- **Backend engineering** (AWS Lambda + API Gateway)  
- **Frontend integration** (Flutter HttpService with retry/error handling)  
- **API security** (AWS Secrets Manager, dotenv)  
- **System documentation & testing**  

---

## 🚀 Features
- **AI-Generated Workout Plans** → Powered by **OpenAI GPT-4**, tailored to user age, body focus, and fitness goals  
- **Motivational Quotes** → Integrated with **ZenQuotes API** for daily inspiration  
- **Dynamic Images** → Pulled from **Unsplash API** for fitness motivation  
- **Serverless Backend** → Deployed on **AWS Lambda**, scalable & cost-efficient  
- **Robust Frontend Service** (Flutter HttpService) with:  
  - Automatic retry & timeout handling  
  - JSON validation & error categorization  
  - Connectivity checks for health monitoring  

---

## 🛠️ Tech Stack

### **Frontend (Mobile App)**
- Flutter (Dart)  
- dotenv for config management  
- Custom HttpService for retries, error handling, and Lambda API calls  

### **Backend (Serverless)**
- AWS Lambda (Node.js)  
- API Gateway (REST endpoints: `/plan`, `/quote`, `/image`)  
- AWS Secrets Manager (API key protection)  

### **APIs Integrated**
- OpenAI GPT-4 → Fitness plan generation  
- ZenQuotes → Motivational quotes  
- Unsplash → Fitness images  

---

## 📂 Repository Content
```plaintext
/backend/
└── index.js              # AWS Lambda function (Node.js) for plan/quote/image generation

/frontend/
└── http_service.dart     # Flutter HttpService managing API calls, retries, and error handling

/design/
├── figma_prototype.png   # UI/UX prototype export
└── slides.pdf            # Capstone presentation slides
```

---
## 📸 Screenshots & Demo
- **AI Workout Plan (JSON)** <img width="360" height="540" alt="image" src="https://github.com/user-attachments/assets/2b74e181-1e75-47cb-a41f-2840af5397a0" />
- **Motivational Quote & Image**  

---

## 📌 My Contributions
- Developed AWS Lambda backend handling AI plan generation & external APIs  
- Designed Flutter HttpService with:  
  - Timeout & retry strategy  
  - Validation of user demographic data  
  - Connectivity & health-check logic  
  - Error messaging system for user-friendly feedback  
- Secured API credentials via **AWS Secrets Manager** & `.env` files  
- Created requirement engineering docs, SQA plan, and UAT reports  
- Collaborated with UI/UX team for seamless frontend integration  

---

## 📈 Project Impact
- Delivered a **scalable, fault-tolerant mobile fitness app**  
- Showcased ability to connect **AI, serverless backend, and mobile frontend**  
- Demonstrated strong skills in **API integration, error handling, and security-first development**  

---

## 🔒 Security Notice
This repository is for **showcase purposes only**.  
All secrets (OpenAI, Unsplash, AWS) have been removed and replaced with placeholders.  

---

✨ Developed as part of **Capstone Project @ Taylor’s University, 2025**

