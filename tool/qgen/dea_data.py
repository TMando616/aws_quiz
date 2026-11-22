import importlib
from dea_refs import E
for m in ['dea_q1', 'dea_q2', 'dea_q3']:
    try:
        importlib.import_module(m)
    except ModuleNotFoundError as e:
        if e.name != m:
            raise
