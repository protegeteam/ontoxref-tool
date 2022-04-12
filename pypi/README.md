# ontoxref for Python 3.x

Find mappings (or cross-references) between terms from ontologies and coding standards

## Prerequisite

The client module requires Python 3.x

## Install

```
pip install ontoxref
```

## Example code

```python
from ontoxref.backend import ConnectionManager

con_mngr = ConnectionManager.init("/path/to/xref-all.json")
con = con_mngr.get_connection()
service = con.get_service("XrefService")

# Find ICD10CM code for 'EFO:0000095'"
service.find_xref("EFO:0000095", "ICD10CM")

# Find DOID code for 'MONDO:0004948'"
service.find_xref("MONDO:0004948", "DOID")
```