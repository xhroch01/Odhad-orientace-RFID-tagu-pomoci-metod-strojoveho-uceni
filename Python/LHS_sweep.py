# python LHS_sweep.py

# Pouzite verze SW = Python 3.8 + pyaedt 0.17.5  |  HFSS 2021.2

from ansys.aedt.core import Desktop, Hfss
from hfss_config import AEDT_VER, PROJECT, DESIGN, SETUP_NAME, EXPORT_BASE
import os
import time
import numpy as np
from scipy.stats import qmc

# Nesimulovane kvadranty nutno zakomentovat!
#
NUM_SAMPLES = 200
X_RANGE = [0, 600]
Y_RANGE = [-1200, 0]
SUBDIR = "AoA_LHS_Dataset_kvadrant1"

# 
# NUM_SAMPLES = 200
# X_RANGE = [0, 600]
# Y_RANGE = [0, 1200]
# SUBDIR = "AoA_LHS_Dataset_kvadrant2"

# 
# NUM_SAMPLES = 200
# X_RANGE = [-600, 0]
# Y_RANGE = [0, 1200]
# SUBDIR = "AoA_LHS_Dataset_kvadrant3"

#
# NUM_SAMPLES = 200
# X_RANGE = [-300, 0]
# Y_RANGE = [-1200, 0]
# SUBDIR = "AoA_LHS_Dataset_kvadrant4"

# Rozsah pro Rotaci XY
ROT_XY_RANGE = [-90, 90]

# HFSS nastaveni
CORES = 10
FIELD_EXPR = "E_Re_Im"
FREQ = "915MHz"
PHASE = "0deg"

# Nazvy promennych v HFSS
VAR_X = "X_CS_Tag"
VAR_Y = "Y_CS_Tag"
VAR_ROT_XY = "Tag_Rot_XY"

# Definice pts souboru
PTS_DIR = r"SEM VLOZIT CESTU K .PTS SOUBORUM!"

PTS_FILES = [
    ("lambda4", os.path.join(PTS_DIR, "AoA_4_ctecky_lambda4.pts")),
    ("lambda2", os.path.join(PTS_DIR, "AoA_4_ctecky_lambda2.pts")),
    ("lambda3", os.path.join(PTS_DIR, "AoA_4_ctecky_lambda3.pts")),
]

# Generovani bodu
print(f"Promenne: X, Y, RotXY. Pocet bodu: {NUM_SAMPLES}")

# Sampler pro 3 dimenze
sampler = qmc.LatinHypercube(d=3)
sample = sampler.random(n=NUM_SAMPLES)

# Skalovani na rozsahy
l_bounds = [X_RANGE[0], Y_RANGE[0], ROT_XY_RANGE[0]]
u_bounds = [X_RANGE[1], Y_RANGE[1], ROT_XY_RANGE[1]]

scaled_samples = qmc.scale(sample, l_bounds, u_bounds)

# Prevod na cela cisla
int_samples = np.rint(scaled_samples).astype(int)

# Pripojeni k HFSS
timestamp = time.strftime("%Y%m%d_%H%M%S")
RUN_DIR = os.path.join(EXPORT_BASE, SUBDIR, timestamp)
os.makedirs(RUN_DIR, exist_ok=True)

Desktop(version=AEDT_VER, new_desktop=False, non_graphical=False, close_on_exit=False)
hfss = Hfss(project=PROJECT, design=DESIGN, new_desktop=False, non_graphical=False, close_on_exit=False)
fields = hfss.odesign.GetModule("FieldsReporter")

def token(v):
    return str(v).replace("-", "m")

# Hlavni loop

start_time = time.time()

for i, row in enumerate(int_samples):
    x, y, r_xy = row
    
    print(f"\n --- SIMULATION {i+1}/{NUM_SAMPLES} --- [X={x}, Y={y}, RotXY={r_xy}]---")

    # Nastaveni promennych
    hfss[VAR_X] = f"{x}mm"
    hfss[VAR_Y] = f"{y}mm"
    hfss[VAR_ROT_XY] = f"{r_xy}deg"

    # Spusteni simulace
    hfss.analyze_setup(SETUP_NAME, cores=CORES)

    # Nastaveni stacku kalkulatoru
    fields.CopyNamedExprToStack(FIELD_EXPR)
    
    for label, pts_path in PTS_FILES:
        
        out_dir = os.path.join(RUN_DIR, label)
        os.makedirs(out_dir, exist_ok=True)
        
        # Nazev souboru
        fname = (f"AoA_{label}_X_cs_{token(x)}_Y_cs_{token(y)}_RotXY_{token(r_xy)}_RotXZ_0_RotYZ_0.fld")
        
        fields.ExportToFile(
            os.path.join(out_dir, fname),
            pts_path,
            f"{SETUP_NAME} : LastAdaptive",
            ["Freq:=", FREQ, "Phase:=", PHASE],
            True
        )

total_time = time.time() - start_time
print(f"\n --- Dataset hotovy. Celkovy cas simulace: {total_time/3600:.2f} hod.---")