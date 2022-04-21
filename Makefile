# ----------------------------------------
# Constant variables
# ----------------------------------------

URIBASE=http://purl.obolibrary.org/obo
MIRRORDIR=mirror
QUERIESDIR=queries
TMPDIR=tmp

ROBOT=robot # ROBOT tool - http://robot.obolibrary.org
CSVJSON=csvjson # CSVJSON - https://csvjson.com
JQ=jq # JQ - https://stedolan.github.io/jq/
CURL=curl

# ----------------------------------------
# Required working directories
# ----------------------------------------

$(TMPDIR) $(MIRRORDIR):
	mkdir -p $@

# ----------------------------------------
# Mirroring upstream ontologies
# ----------------------------------------

MIR=true # Global parameter to bypass mirror generation

define download_ontology_base
	curl -L $(URIBASE)/$(1)/$(1)-base.owl --create-dirs -o $(MIRRORDIR)/$(1).owl --retry 4 --max-time 200 && \
		$(ROBOT) convert -i $(MIRRORDIR)/$(1).owl -o $@.tmp.owl && \
		mv $@.tmp.owl $(TMPDIR)/$@.owl
endef

define download_owl_ontology
	curl -L $(URIBASE)/$(1).owl --create-dirs -o $(MIRRORDIR)/$(1).owl --retry 4 --max-time 5000 && \
		$(ROBOT) convert -i $(MIRRORDIR)/$(1).owl -o $@.tmp.owl && \
		mv $@.tmp.owl $(TMPDIR)/$@.owl
endef

define download_obo_ontology
	curl -L $(URIBASE)/$(1).obo --create-dirs -o $(MIRRORDIR)/$(1).owl --retry 4 --max-time 5000 && \
		$(ROBOT) convert -i $(MIRRORDIR)/$(1).owl -o $@.tmp.owl && \
		mv $@.tmp.owl $(TMPDIR)/$@.owl
endef

## ONTOLOGY: uberon
.PHONY: mirror-uberon
.PRECIOUS: $(MIRRORDIR)/uberon.owl
mirror-uberon:
	if [ $(MIR) = true ]; then $(call download_ontology_base,uberon); fi

## ONTOLOGY: mondo
.PHONY: mirror-mondo
.PRECIOUS: $(MIRRORDIR)/mondo.owl
mirror-mondo:
	if [ $(MIR) = true ]; then $(call download_ontology_base,mondo); fi

## ONTOLOGY: doid
.PHONY: mirror-doid
.PRECIOUS: $(MIRRORDIR)/doid.owl
mirror-doid:
	if [ $(MIR) = true ]; then $(call download_ontology_base,doid); fi

## ONTOLOGY: hp
.PHONY: mirror-hp
.PRECIOUS: $(MIRRORDIR)/hp.owl
mirror-hp: | $(TMPDIR)
	if [ $(MIR) = true ]; then $(call download_ontology_base,hp); fi

## ONTOLOGY: pr
.PHONY: mirror-pr
.PRECIOUS: $(MIRRORDIR)/pr.owl
mirror-pr: | $(TMPDIR)
	if [ $(MIR) = true ]; then $(call download_obo_ontology,pr); fi

## ONTOLOGY: chebi
.PHONY: mirror-chebi
.PRECIOUS: $(MIRRORDIR)/chebi.owl
mirror-chebi: | $(TMPDIR)
	if [ $(MIR) = true ]; then curl -L $(URIBASE)/chebi.owl.gz --create-dirs -o $(MIRRORDIR)/chebi.owl.gz --retry 4 --max-time 5000 && \
		gzip -d $(MIRRORDIR)/chebi.owl.gz && \
		$(ROBOT) convert -i $(MIRRORDIR)/chebi.owl -o $@.tmp.owl && \
		mv $@.tmp.owl $(TMPDIR)/$@.owl; fi

$(MIRRORDIR)/%.owl: mirror-% | $(MIRRORDIR)
	if cmp -s $(TMPDIR)/mirror-$*.owl $@ ; then echo "Mirror identical, ignoring."; else echo "Mirrors different, updating."; fi && \
	cp $(TMPDIR)/mirror-$*.owl $@

# ----------------------------------------
# Extracting xrefs from ontologies
# ----------------------------------------

define extract_xrefs
	$(ROBOT) query --input $(1) --query $(QUERIESDIR)/get_xrefs.sparql $(TMPDIR)/result.csv && \
	$(CSVJSON) $(TMPDIR)/result.csv | $(JQ) -s '.[] | map({(.entity_id): [.xref_id]}) | reduce .[] as $$o ({} ; reduce ($$o|keys)[] as $$key (.; .[$$key] += $$o[$$key]))' > $(TMPDIR)/xrefs.json 
	$(CSVJSON) $(TMPDIR)/result.csv | $(JQ) -s '.[] | map({(.xref_id): [.entity_id]}) | reduce .[] as $$o ({} ; reduce ($$o|keys)[] as $$key (.; .[$$key] += $$o[$$key]))' > $(TMPDIR)/inv_xrefs.json 
	$(JQ) -s 'map(to_entries) | add | group_by(.key) | map({ key: (.[0].key), value:([.[].value] | add | unique) }) | from_entries' $(TMPDIR)/xrefs.json $(TMPDIR)/inv_xrefs.json > $@
endef

define extract_loinc_mappings
	$(CURL) --request GET \
		--url 'https://data.bioontology.org/mappings?ontologies=LOINC%2C$(1)&pagesize=5000' \
		--header 'Authorization: apiKey token=d1819526-0173-4d11-bd43-adda0999d27c' > $(TMPDIR)/mappings.json
	$(JQ) '.collection[].classes | map(."@id"| sub("http://purl.bioontology.org/ontology/LNC/";"LOINC:") | sub("http://purl.obolibrary.org/obo/$(1)_";"$(1):")) | {(.[0]): [.[1]]}' $(TMPDIR)/mappings.json > $(TMPDIR)/xrefs.json
	$(JQ) '.collection[].classes | map(."@id"| sub("http://purl.bioontology.org/ontology/LNC/";"LOINC:") | sub("http://purl.obolibrary.org/obo/$(1)_";"$(1):")) | {(.[1]): [.[0]]}' $(TMPDIR)/mappings.json > $(TMPDIR)/inv_xrefs.json
	$(JQ) -s 'map(to_entries) | add | group_by(.key) | map({ key: (.[0].key), value:([.[].value] | add | unique) }) | from_entries' $(TMPDIR)/xrefs.json $(TMPDIR)/inv_xrefs.json > $@
endef

xref-%.json: $(MIRRORDIR)/%.owl
	$(call extract_xrefs,$^)

map-loinc-uberon.json:
	$(call extract_loinc_mappings,UBERON)

map-loinc-cl.json:
	$(call extract_loinc_mappings,CL)

map-loinc-pr.json:
	$(call extract_loinc_mappings,PR)

map-loinc-chebi.json:
	$(call extract_loinc_mappings,CHEBI)

.PHONY: xref-all
.PRECIOUS: xref-all.json
xref-all: xref-uberon.json \
		xref-hp.json \
		xref-doid.json \
		xref-mondo.json \
		xref-chebi.json \
		xref-pr.json \
		map-loinc-uberon.json \
		map-loinc-cl.json \
		map-loinc-pr.json \
		map-loinc-chebi.json
	$(JQ) -s 'map(to_entries) | add | group_by(.key) | map({ key: (.[0].key), value:([.[].value] | add | unique) }) | from_entries' $^ > $@.json

xref-%-only: xref-all.json
	$(JQ) -s '.[] | with_entries(select(.key|match("$(ONT)")))' $^ > $@.json