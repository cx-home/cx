CX      := ../../../vcx/target/cx
PIDFILE := /tmp/cxstore-csrp.pid
LOG     := /tmp/cxstore-csrp.log

# NOTE: --allow-all (not just --allow-net): the CSRP handler's observability/
# tracing path needs more than the net capability; a denied cap poisons
# [$http:respond] so the server closes the connection without responding
# (client then sees CXER4504 / E_STORE_BACKEND_UNREACHABLE).

.PHONY: server stop client run

server:   ## start the CSRP server in the background
	@$(CX) --allow-all server.cx > $(LOG) 2>&1 & echo $$! > $(PIDFILE)
	@sleep 2   # let it bind
	@echo "server pid $$(cat $(PIDFILE)) on tcp://127.0.0.1:18901  (log: $(LOG))"

stop:     ## stop the server
	@kill $$(cat $(PIDFILE)) 2>/dev/null && rm -f $(PIDFILE) && echo stopped || echo "not running"

client:   ## run the client against the running server
	@$(CX) --allow-all client.cx

run: server client stop   ## one-shot: start → client → stop
