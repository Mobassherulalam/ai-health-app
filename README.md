# 🏥 AI Health Monitoring System

This repository contains a **full-stack health monitoring application** with a **FastAPI backend** and a **Flutter frontend**. The system predicts potential health risks based on **ECG signals** and **vital signs data** using machine learning models trained on publicly available datasets.

## 📂 Repository Structure

```
├── backend/        # FastAPI backend
│   ├── app/        # API source code
│   ├── models/     # Saved ML models
│   ├── utils.py    # Data simulation scripts
│   ├── schema.py   # Pydantic schemas
│   ├── main.py     # FastAPI entrypoint
│   └── requirements.txt
│
├── frontend/       # Flutter application
│   ├── lib/        # Flutter source code
│   ├── assets/     # App images/icons
│   └── pubspec.yaml
│
└── README.md
```

---

## 🚀 Features

* ✅ **Machine Learning Models** trained on real-world health datasets
* ✅ **FastAPI Backend** for inference, simulation, and API endpoints
* ✅ **Flutter Frontend** for a user-friendly interface
* ✅ **Real-time health monitoring** with ECG & vital sign simulation
* ✅ **Cross-platform support** (Android, iOS, Web)

---

## 📊 Datasets Used

The models are trained using the following datasets:

1. **Human Vital Signs Dataset**

   * Source: [Kaggle - Human Vital Sign Dataset](https://www.kaggle.com/datasets/nasirayub2/human-vital-sign-dataset)
   * Contains synthetic and real-world vital measurements such as **heart rate, blood pressure, oxygen levels, and temperature**.

2. **Heartbeat ECG Dataset**

   * Source: [Kaggle - Heartbeat Dataset](https://www.kaggle.com/datasets/shayanfazeli/heartbeat/data)
   * Includes **ECG time-series data** for detecting abnormal rhythms and potential arrhythmias.

The backend uses **Random Forest** and **XGBoost** classifiers trained on these datasets.

---

## ⚙️ Installation & Setup

### 🔹 1. Clone the Repository

```bash
git clone https://github.com/yourusername/health-monitoring-system.git
cd health-monitoring-system
```

---

### 🔹 2. Backend (FastAPI) Setup

1. Navigate to backend:

   ```bash
   cd backend
   ```

2. Create virtual environment (optional but recommended):

   ```bash
   python -m venv venv
   source venv/bin/activate   # On Linux/Mac
   venv\Scripts\activate      # On Windows
   ```

3. Install dependencies:

   ```bash
   pip install -r requirements.txt
   ```

4. Run the FastAPI server:

   ```bash
   uvicorn main:app --reload
   ```

   The backend will run at: **[http://127.0.0.1:8000](http://127.0.0.1:8000)**

---

### 🔹 3. Frontend (Flutter) Setup

1. Navigate to frontend:

   ```bash
   cd ../frontend
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Run the app:

   ```bash
   flutter run
   ```

   You can run it on **Web**.

---

## 🔗 API Endpoints (FastAPI)

| Endpoint           | Method | Description                          |
| ------------------ | ------ | ------------------------------------ |
| `/predict/ecg`     | POST   | Predicts ECG class (normal/abnormal) |
| `/predict/vitals`  | POST   | Predicts risk from human vitals      |
| `/simulate/ecg`    | GET    | Generates simulated ECG data         |
| `/simulate/vitals` | GET    | Generates simulated vitals data      |

---

## 📱 Frontend Overview

* **Login/Signup** for users
* **Dashboard** to view real-time vitals & ECG predictions
* **Interactive charts** to visualize time-series data
* **Prediction results** from ML models served by FastAPI

---

## 🛠️ Tech Stack

* **Backend:** FastAPI, Python, Pandas, NumPy, Scikit-learn, XGBoost
* **Frontend:** Flutter, Dart
* **Models:** 1D-CNN, XGBoost (trained on Kaggle datasets)

---

## 🤝 Contribution

1. Fork the repo
2. Create a feature branch (`git checkout -b feature-name`)
3. Commit changes (`git commit -m "Added new feature"`)
4. Push branch (`git push origin feature-name`)
5. Open a Pull Request

---

Would you like me to also include **example API request/response payloads** (like JSON input/output for `/predict/ecg` and `/predict/vitals`) so developers testing your repo don’t have to guess the schema?
