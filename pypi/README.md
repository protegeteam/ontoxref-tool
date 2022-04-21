# ontoxref for Python 3.x

Find mappings (or cross-references) between terms from ontologies and coding standards

## Prerequisite

The client module requires Python 3.x

## Install

```
pip install ontoxref
```

## Example code

Import `ConnectionManager` from the backend module
```python
from ontoxref.backend import ConnectionManager
```

Initiate the database once (it may take some time to load).
```python
con_mngr = ConnectionManager.init()
```

Pass the connection in your code to use the service.
```python
con = con_mngr.get_connection()
service = con.get_service("XrefService")

# Find ICD10CM code for 'EFO:0000095'"
service.find_xref("EFO:0000095", "ICD10CM")

# Find DOID code for 'MONDO:0004948'"
service.find_xref("MONDO:0004948", "DOID")
```

Note: The database initiation can be done using a local file
```python
con_mngr = ConnectionManager.init_locally("path/to/file")
```

