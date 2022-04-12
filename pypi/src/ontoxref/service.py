from abc import abstractmethod


class Service:
    @abstractmethod
    def get_name(self):
        pass


class XrefService(Service):
    def __init__(self, con):
        self.con = con

    def get_name(self):
        return "XrefService"

    def find_xref(self, curie, target_ontology):
        return self._find(curie, target_ontology, [])

    def _find(self, curie, target_ontology, visited_xref):
        visited_xref.append(curie)
        try:
            xrefs = self.con.query(curie)
            for xref in xrefs:
                if xref in visited_xref:
                    continue
                if xref.startswith(target_ontology):
                    return xref
                else:
                    found_xref =\
                        self._find(xref, target_ontology, visited_xref)
                    if found_xref is not None:
                        return found_xref
                visited_xref = [curie]
            return None
        except KeyError:
            return None
