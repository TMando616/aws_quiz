import importlib
from soa_refs import E
for m in ["soa_q1","soa_q2","soa_q3","soa_q4","soa_q5"]:
    try:
        importlib.import_module(m)
    except ModuleNotFoundError as e:
        if e.name != m:
            raise
