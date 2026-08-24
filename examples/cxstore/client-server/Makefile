CX      := ../../../vcx/target/cx
PIDFILE := /tmp/cxstore-xsp.pid
LOG     := /tmp/cxstore-xsp.log
# The daemon's XSP responder identity seed (the config names this env var).
# A throwaway 32-byte Ed25519 seed for the demo — never a real key.
export CX_CLIENT_SERVER_EXAMPLE_SEED := 4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb

.PHONY: server stop client run

server:   ## start the store daemon (XSP profile) in the background
	@$(CX) store-serve --config cxstore.service.cx --allow-env --allow-net=127.0.0.1:18900 --allow-net=127.0.0.1:18901 > $(LOG) 2>&1 & echo $$! > $(PIDFILE)
	@sleep 2   # let both listeners bind
	@echo "server pid $$(cat $(PIDFILE)) — XSP on tcp://127.0.0.1:18901, health on http://127.0.0.1:18900  (log: $(LOG))"

stop:     ## stop the server
	@kill $$(cat $(PIDFILE)) 2>/dev/null && rm -f $(PIDFILE) && echo stopped || echo "not running"

client:   ## run the client against the running server
	@$(CX) --allow-net=127.0.0.1:18901 client.cx

run: server client stop   ## one-shot: start → client → stop
