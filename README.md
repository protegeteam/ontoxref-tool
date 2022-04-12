# Ontology Term Cross-References Tool

The tool provides the method to find mappings (or cross-references) between terms from ontologies and coding standards. The tool uses mapping data extracted from a variety of biomedical ontologies that contain cross-references information.

## Data collection pipeline

### Prerequisite

The pipeline requires some third-party software programs that you will need to install them first:
1. ROBOT tool (http://robot.obolibrary.org/)
2. CSVJSON (https://csvjson.com/)
3. JQ (https://stedolan.github.io/jq/)

### Running the pipeline

Clone the repository:

```
$ git clone https://github.com/protegeteam/ontoxref-tool.git
$ cd ontoxref-tool
```

Type the command below:

```
$ make xref_all
```

## ontoxref for Python 3.x

See [this page](https://github.com/protegeteam/ontoxref-tool/tree/main/pypi) for more information.


