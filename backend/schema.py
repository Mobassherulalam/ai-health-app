from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime

class ECGPrediction(BaseModel):
    cls: int
    label: str
    probability: float
    actual_class: Optional[int] = None
    actual_label: Optional[str] = None

class ECGRecord(BaseModel):
    timestamp: datetime
    prediction: ECGPrediction
    signal: List[float]

class ECGStream(BaseModel):
    stream: List[ECGRecord]

class VitalsPrediction(BaseModel):
    risk: str
    probability: float
    actual_risk: Optional[int] = None
    actual_prob: Optional[float] = None

class VitalsData(BaseModel):
    spo2: float
    heart_rate: float
    oxygen_flow: float
    systolic_bp: float
    diastolic_bp: float
    derived_pulse_pressure: float
    derived_hrv: float

class VitalsRecord(BaseModel):
    timestamp: datetime
    prediction: VitalsPrediction
    vitals: VitalsData

class VitalsStream(BaseModel):
    stream: List[VitalsRecord]