import importlib
from dva_refs import E
for m in ['dva_q1', 'dva_q2', 'dva_q3', 'dva_q4']:
    try:
        importlib.import_module(m)
    except ModuleNotFoundError as e:
        if e.name != m:
            raise
