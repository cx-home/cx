CX := ../../../vcx/target/cx

# A directory tree of .cxd data files <-> a content-addressed cx store.
# ingest.cx loads sample/ into cxpack://./out-store, named by relative path.
# materialize.cx writes the store's docs back out to ./restored.
# watch.cx keeps the store LIVE as sample/ changes (real inotify/FSEvents).
# Pure cx recipes — edit them to change the substrate, filter, or naming.

.PHONY: ingest materialize watch run clean

ingest:        ## load the sample/ tree into the store (idempotent)
	@$(CX) --allow-all ingest.cx

materialize:   ## write the store's docs back out to ./restored
	@$(CX) --allow-all materialize.cx

watch:         ## continuously sync sample/ into the store as files change (Ctrl-C to stop)
	@$(CX) --allow-all watch.cx

run: clean ingest materialize   ## one-shot: ingest then materialize

clean:         ## remove the generated store + restored tree
	@rm -rf out-store restored
