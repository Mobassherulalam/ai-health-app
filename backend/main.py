import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import pandas as pd
import numpy as np
import joblib
import tensorflow as tf
from utils import simulate_ecg_timeseries, simulate_vitals_timeseries
from schema import ECGStream, ECGRecord, ECGPrediction, VitalsStream, VitalsRecord, VitalsPrediction, VitalsData

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

ECG_MODEL_PATH    = os.path.join(BASE_DIR, 'models', 'xgb_pipeline_ecg_mitbih_with_metadata.pkl')
VITALS_MODEL_PATH = os.path.join(BASE_DIR, 'models', 'vitals_cnn_model.h5')

ECG_DATA_DIR = os.path.join(BASE_DIR, 'simulation data')
VITALS_DATA_DIR = os.path.join(BASE_DIR, 'simulation data')

ecg_class_dfs = {
    cls: pd.read_csv(os.path.join(ECG_DATA_DIR, f'ecg_class{cls}.csv'))
    for cls in range(5)
}
vitals_low  = pd.read_csv(os.path.join(VITALS_DATA_DIR, 'vital_class0.csv'))
vitals_high = pd.read_csv(os.path.join(VITALS_DATA_DIR, 'vital_class1.csv'))

if not os.path.exists(ECG_MODEL_PATH):
    raise FileNotFoundError(f"ECG model not found at {ECG_MODEL_PATH}")
if not os.path.exists(VITALS_MODEL_PATH):
    raise FileNotFoundError(f"Vitals model not found at {VITALS_MODEL_PATH}")

ecg_pipline = joblib.load(ECG_MODEL_PATH)

ecg_model = ecg_pipline['pipeline']
vitals_model = tf.keras.models.load_model(VITALS_MODEL_PATH)

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

ecg_label_map = {
    0: "Normal",
    1: "Supraventricular Ectopic",
    2: "Ventricular Ectopic",
    3: "Fusion Beat",
    4: "Unknown/Paced",
}

@app.get("/simulate/ecg", response_model=ECGStream)
def simulate_ecg(length: int = 200):
    df_stream = simulate_ecg_timeseries(ecg_class_dfs, length=length)
    records = []
    for _, row in df_stream.iterrows():
        X = row.drop(["ecg_class", "timestamp"]).values.reshape(1, -1)
        y = row["ecg_class"]
        probas = ecg_model.predict_proba(X)[0]
        pred_class = int(np.argmax(probas))
        pred_prob  = float(probas[pred_class])
        records.append(ECGRecord(
            timestamp=row["timestamp"],
            prediction=ECGPrediction(
                cls=pred_class,
                label=ecg_label_map[pred_class],
                probability = pred_prob,
                actual_class = int(y),
                actual_label=ecg_label_map[int(y)]
                ),
            signal=row.drop(["ecg_class", "timestamp"]).tolist()
        ))
    return ECGStream(stream=records)

@app.get("/simulate/vitals", response_model=VitalsStream)
def simulate_vitals(length: int = 200):
    df_stream = simulate_vitals_timeseries(vitals_low, vitals_high, length=length)
    records = []
    for _, row in df_stream.iterrows():
        X = row.drop(["risk_category", "timestamp", "risk_prob"]).values.astype(np.float64).reshape(1, -1, 1)
        actual_category = row["risk_category"]
        actual_risk_prob = row["risk_prob"]
        prob = float(vitals_model.predict(X, verbose=0)[0][0])
        pred_risk = "Low" if prob > 0.5 else "High"
        records.append(VitalsRecord(
            timestamp=row["timestamp"],
            prediction=VitalsPrediction(
                risk=pred_risk,
                probability=prob,
                actual_risk=actual_category,
                actual_prob=actual_risk_prob
                ),
            vitals=VitalsData(
                spo2=float(row["Oxygen Saturation"]),
                heart_rate=float(row["Heart Rate"]),
                oxygen_flow=float(row["Respiratory Rate"]),
                systolic_bp=float(row["Systolic Blood Pressure"]),
                diastolic_bp=float(row["Diastolic Blood Pressure"]),
                derived_pulse_pressure=float(row["Derived_Pulse_Pressure"]),
                derived_hrv=float(row["Derived_HRV"]),
                )
        ))
    print(VitalsStream(stream=records))
    return VitalsStream(stream=records)