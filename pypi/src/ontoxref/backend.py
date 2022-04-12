import json
import random
from lmdbm import Lmdb
from ontoxref.service import XrefService


class JsonLmdb(Lmdb):
    def _pre_key(self, value):
        return value.encode("utf-8")

    def _post_key(self, value):
        return value.decode("utf-8")

    def _pre_value(self, value):
        return json.dumps(value).encode("utf-8")

    def _post_value(self, value):
        return json.loads(value.decode("utf-8"))


class Connection:
    def __init__(self, pid, db):
        self.pid = pid
        self.db = db

    def pid(self):
        return self.pid

    def query(self, key):
        return self.db[key]

    def get_service(self, name):
        if name == "XrefService":
            return XrefService(self)
        else:
            raise ValueError("Unknown service name [" + name + "]")


class ConnectionManager:
    def __init__(self, db_name):
        self.db_name = db_name
        self.open_connections = {}

    @staticmethod
    def init(file_location, db_name="xref.db"):
        file = open(file_location)
        mappings = json.load(file)
        with JsonLmdb.open(db_name, 'n') as db:
            for key, value in mappings.items():
                db[key] = value
            db.close()
        return ConnectionManager(db_name)

    def get_connection(self):
        db = self._open_database()
        return self._open_connection(db)

    def _open_database(self):
        return JsonLmdb.open(self.db_name, 'r')

    def _open_connection(self, db):
        pid = random.getrandbits(32)
        con = Connection(pid, db)
        self.open_connections[pid] = db
        return con

    def list_connections(self):
        return self.open_connections

    def kill(self, pid):
        try:
            self.open_connections[pid].close()
            del self.open_connections[pid]
        except KeyError:
            return

    def kill_all(self):
        for pid in self.open_connections.keys():
            self.kill(pid)
