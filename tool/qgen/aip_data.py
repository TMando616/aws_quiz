import importlib
from aip_refs import E
for m in ['aip_q1', 'aip_q2', 'aip_q3']:
    try:
        importlib.import_module(m)
    except ModuleNotFoundError as e:
        if e.name != m:
            raise
