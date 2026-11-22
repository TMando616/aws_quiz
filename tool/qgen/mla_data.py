import importlib
from mla_refs import E
for m in ['mla_q1', 'mla_q2', 'mla_q3']:
    try:
        importlib.import_module(m)
    except ModuleNotFoundError as e:
        if e.name != m:
            raise
