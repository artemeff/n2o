empty :=
ROOTS := apps deps
space := $(empty) $(empty)
comma := $(empty),$(empty)
VSN   := $(shell expr substr `git rev-parse HEAD` 1 6)
DATE  := $(shell git show -s --format="%ci" HEAD | sed -e 's/\+/Z/g' -e 's/-/./g' -e 's/ /-/g' -e 's/:/./g')
ERL_LIBS := $(subst $(space),:,$(ROOTS))
relx  := "{release,{$(RELEASE),\"$(VER)\"},[$(subst $(space),$(comma),$(APPS))]}.\\n{include_erts,true}.\
\\n{extended_start_script,true}.\\n{generate_start_script,true}.\\n{sys_config,\"$(SYS)\"}.\
\\n{vm_args,\"$(VM)\"}.\\n{overlay,[{mkdir,\"log/sasl\"}]}."

test: eunit ct
compile: get-deps static-link
delete-deps get-deps compile clean update-deps:
	./mad $@
.applist:
	./depman.erl $(APPS) > $@
$(RUN_DIR) $(LOG_DIR):
	mkdir -p $(RUN_DIR) & mkdir -p $(LOG_DIR)
console: .applist
	ERL_LIBS=$(ERL_LIBS) erl $(ERL_ARGS) -eval \
		'[ok = application:ensure_started(A, permanent) || A <- $(shell cat .applist)]'
start: $(RUN_DIR) $(LOG_DIR) .applist
	ERL_LIBS=$(ERL_LIBS) run_erl -daemon $(RUN_DIR)/ $(LOG_DIR)/ "exec $(MAKE) console"
attach:
	to_erl $(RUN_DIR)/
release:
	echo $(shell echo $(relx) > relx.config) & relx
stop:
	kill -9 `ps ax -o pid= -o command=|grep $(RELEASE)|grep $(COOKIE)|awk '{print $$1}'`
$(PLT_NAME):
	ERL_LIBS=deps dialyzer --build_plt --output_plt $(PLT_NAME) --apps $(APPS) || true
dialyze: $(PLT_NAME) compile
	dialyzer deps/*/ebin --plt $(PLT_NAME) --no_native -Werror_handling -Wunderspecs -Wrace_conditions
tar:
	tar zcvf $(RELEASE)-$(VSN)-$(DATE).tar.gz _rel/lib/*/ebin _rel/lib/*/priv _rel/bin _rel/releases
eunit:
	rebar eunit skip_deps=true
ct:
	rebar ct skip_deps=true verbose=1

.PHONY: delete-deps get-deps compile clean console start attach release update-deps dialyze ct eunit tar
