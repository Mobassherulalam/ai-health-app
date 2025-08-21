import pandas as pd
import numpy as np

def simulate_vitals_timeseries(low_df, high_df, length=200, seed=42):
    np.random.seed(seed)
    half = length // 2
    probs = np.concatenate([
        np.linspace(0.0, 0.8, half),
        np.linspace(0.8, 0.0, length-half)
    ])
    records = []
    for i, p in enumerate(probs):
        row = high_df.sample(1).iloc[0] if np.random.rand()<p else low_df.sample(1).iloc[0]
        input_vector = row.drop(["Risk Category"])
        risk_category = row["Risk Category"]
        rec = input_vector.to_dict()
        rec.update({
            'risk_category': risk_category,
            'timestamp': pd.Timestamp.now() + pd.Timedelta(seconds=i),
            'risk_prob': float(p)
            })
        records.append(rec)
    return pd.DataFrame(records)

def simulate_ecg_timeseries(class_dfs, length=200, seed=42):
    np.random.seed(seed)
    probs = [0.7] + [0.075] * 4
    records = []
    for i in range(length):
        cls = np.random.choice(list(class_dfs.keys()), p=probs)
        row = class_dfs[cls].sample(1).iloc[0]
        ecg_class = row.iloc[-1]
        input_vector = row.iloc[:-1]
        rec = input_vector.to_dict()
        rec.update({
            'ecg_class': ecg_class,
            'timestamp': pd.Timestamp.now() + pd.Timedelta(milliseconds=i*10)
            })
        records.append(rec)
    return pd.DataFrame(records)