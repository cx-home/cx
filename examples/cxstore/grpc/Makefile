CX      := ../../../vcx/target/cx
PIDFILE := /tmp/cxstore-grpc.pid
LOG     := /tmp/cxstore-grpc.log
CPORT   := 18910
GPORT   := 18911

# The SERVER is the cxstore daemon (`cx store-serve`), which binds two listeners
# from one config: CSRP (HTTP/1.1) on CPORT and gRPC (HTTP/2 + protobuf) on GPORT.
# The CLIENT opens `cx-store+grpc://…/docs/` and drives the store over gRPC — the
# SAME `[$store:…]` ops as the CSRP example, just a different transport scheme.
#
# The daemon grants itself net via the --allow-net flags (deny-by-default); the
# client needs net only to the gRPC port.

.PHONY: server stop client run

server:   ## start the cxstore daemon (CSRP + gRPC) in the background
	@$(CX) store-serve --config cxstore.service.cx \
	  --allow-net=127.0.0.1:$(CPORT) --allow-net=127.0.0.1:$(GPORT) > $(LOG) 2>&1 & echo $$! > $(PIDFILE)
	@sleep 2   # let both listeners bind
	@echo "server pid $$(cat $(PIDFILE)) — gRPC on tcp://127.0.0.1:$(GPORT)  (log: $(LOG))"

stop:     ## stop the daemon
	@kill $$(cat $(PIDFILE)) 2>/dev/null && rm -f $(PIDFILE) && echo stopped || echo "not running"

client:   ## run the gRPC client against the running daemon
	@$(CX) --allow-net=127.0.0.1:$(GPORT) client.cx

run: server client stop   ## one-shot: start daemon → client over gRPC → stop
