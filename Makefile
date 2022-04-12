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

xref-%.json: $(MIRRORDIR)/%.owl
	$(call extract_xrefs,$^)

.PHONY: xref-all
.PRECIOUS: xref-all.json
xref-all: xref-uberon.json xref-hp.json xref-doid.json xref-mondo.json xref-chebi.json
	$(JQ) -s 'map(to_entries) | add | group_by(.key) | map({ key: (.[0].key), value:([.[].value] | add | unique) }) | from_entries' $^ > $@.json

xref-%-only: xref-all.json
	$(JQ) -s '.[] | with_entries(select(.key|match("$(ONT)")))' $^ > $@.json