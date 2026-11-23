import json, sys
from pathlib import Path
import numpy as np, pandas as pd, joblib
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.impute import SimpleImputer
from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier, HistGradientBoostingClassifier
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import roc_auc_score, precision_recall_fscore_support, confusion_matrix, brier_score_loss

CAT = ["categoria", "barrio", "dia_semana", "franja_horaria"]
NUM = ["presupuesto", "dias_anticipacion", "num_postulaciones_24h", "tiempo_primera_postulacion", "precio_relativo"]
SEED = 42

def preprocesador():
    return ColumnTransformer([
        ("cat", Pipeline([("imp", SimpleImputer(strategy="constant", fill_value="desconocido")),
                          ("oh", OneHotEncoder(handle_unknown="infrequent_if_exist", min_frequency=20, sparse_output=False))]), CAT),
        ("num", Pipeline([("imp", SimpleImputer(strategy="median", add_indicator=True)), ("sc", StandardScaler())]), NUM),
    ])

MODELOS = {
    "regresion_logistica": LogisticRegression(max_iter=2000, class_weight="balanced"),
    "random_forest": RandomForestClassifier(n_estimators=400, min_samples_leaf=5, class_weight="balanced", random_state=SEED, n_jobs=-1),
    "gradient_boosting": HistGradientBoostingClassifier(learning_rate=.06, max_iter=300, random_state=SEED),
    "red_neuronal_mlp": MLPClassifier(hidden_layer_sizes=(64, 32), alpha=1e-3, max_iter=600, early_stopping=True, random_state=SEED),
}
MODELO_ACTIVO = "red_neuronal_mlp"

def main(csv="solicitudes_sinteticas.csv", version="v1"):
    df = pd.read_csv(csv)
    df["dia_semana"] = df["dia_semana"].astype(str)
    X, y = df[CAT + NUM], df["contratada"].astype(int)
    X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=.2, stratify=y, random_state=SEED)
    cv = StratifiedKFold(5, shuffle=True, random_state=SEED)

    resultados, pipes = {}, {}
    for nombre, modelo in MODELOS.items():
        pipe = Pipeline([("prep", preprocesador()), ("modelo", modelo)])
        auc_cv = cross_val_score(pipe, X_tr, y_tr, cv=cv, scoring="roc_auc")
        pipe.fit(X_tr, y_tr)
        proba = pipe.predict_proba(X_te)[:, 1]; pred = (proba >= .5).astype(int)
        p, r, f1, _ = precision_recall_fscore_support(y_te, pred, average="binary", pos_label=0)
        resultados[nombre] = {"auc_cv_media": round(auc_cv.mean(), 4), "auc_cv_std": round(auc_cv.std(), 4),
                              "auc_test": round(roc_auc_score(y_te, proba), 4), "precision_No": round(p, 3), "recall_No": round(r, 3),
                              "f1_No": round(f1, 3), "brier": round(brier_score_loss(y_te, proba), 4),
                              "matriz_confusion": confusion_matrix(y_te, pred).tolist()}
        pipes[nombre] = pipe
        print(f"{nombre:22s} AUC cv={auc_cv.mean():.3f}±{auc_cv.std():.3f}  AUC test={resultados[nombre]['auc_test']:.3f}  F1(No)={f1:.3f}")

    # Se comparan varios modelos, pero el que se guarda es la red neuronal
    mejor = MODELO_ACTIVO
    print("\nMejor AUC (cv):", max(resultados, key=lambda k: resultados[k]["auc_cv_media"]), "· modelo guardado:", mejor)
    Path("modelos").mkdir(exist_ok=True)
    joblib.dump(pipes[mejor], f"modelos/modelo_{version}.joblib")
    meta = {"modelo": mejor, "version": version, "n_entrenamiento": int(len(X_tr)), "n_prueba": int(len(X_te)),
            "tasa_contratacion": round(float(y.mean()), 3), "auc_roc": resultados[mejor]["auc_test"], "comparacion": resultados,
            "columnas": CAT + NUM, "fuente": csv}
    Path(f"modelos/modelo_{version}.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False))
    print(f"Guardado modelos/modelo_{version}.joblib y .json")

if __name__ == "__main__":
    main(*sys.argv[1:])
