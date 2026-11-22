import importlib
from aif_refs import E
for m in ['aif_q1', 'aif_q2', 'aif_q3']:
    try:
        importlib.import_module(m)
    except ModuleNotFoundError as e:
        if e.name != m:
            raise
