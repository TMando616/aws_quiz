import importlib
from clf_refs import E
for m in ['clf_q1', 'clf_q2', 'clf_q3', 'clf_q4']:
    try:
        importlib.import_module(m)
    except ModuleNotFoundError as e:
        if e.name != m:
            raise
