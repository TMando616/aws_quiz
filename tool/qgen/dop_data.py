import importlib
from dop_refs import E
for m in ['dop_q1', 'dop_q2', 'dop_q3']:
    try:
        importlib.import_module(m)
    except ModuleNotFoundError as e:
        if e.name != m:
            raise
