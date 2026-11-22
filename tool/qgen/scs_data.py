import importlib
from scs_refs import E
for m in ['scs_q1', 'scs_q2', 'scs_q3']:
    try:
        importlib.import_module(m)
    except ModuleNotFoundError as e:
        if e.name != m:
            raise
