HEX_URL    ?= https://repo.hex.pm/installs/1.8.0/hex-0.20.5.ez
HEX_SHA    ?= cb7fdddbc4e5051b403cfb5e874ceb5cb0ecbe981a2a1517b97f9f76c67d234692e901ff48ee10dc712f728ae6ed0a51b11b8bd65b5db5582896123de20e7d49
REBAR_URL  ?= https://repo.hex.pm/installs/1.0.0/rebar-2.6.2
REBAR_SHA  ?= ff1c5ddfce1fcfd73fd65b8bfc0ff1c13aefc2e98921d528cbc1f35e86c9caa1c9c4e848b9ce6404d9a81c50cfcf0e45dd0dddb23cd42708664c41fce6618900
REBAR3_URL ?= https://repo.hex.pm/installs/1.0.0/rebar3-3.5.1
REBAR3_SHA ?= 86e998642991d384e9a6d4f216552609496da0e6ec4eb235df5b8b637d078c1a118bc7cdab501d1d54d24e0b6642adf32cc0c43019d948304301ceef227bedfd

.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

test:
	mix test test/itest

generate-security_critical_api_specs:
	priv/openapitools/openapi-generator-cli generate -i ./security_critical_api_specs.yml -g elixir -o apps/watcher_security_critical_api

generate-info_api_specs:
	priv/openapitools/openapi-generator-cli generate -i ./info_api_specs.yml -g elixir -o apps/watcher_info_api

generate-operator_api_specs:
	priv/openapitools/openapi-generator-cli generate -i ./operator_api_specs.yml -g elixir -o apps/child_chain_api

generate_api_code: generate-security_critical_api_specs generate-info_api_specs generate-operator_api_specs

clean_generate_api_code:
	rm -rf apps/child_chain_api || true && \
	rm -rf apps/watcher_info_api || true && \
	rm -rf apps/watcher_security_critical_api

install:
	mkdir -p priv/openapitools
	curl https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/bin/utils/openapi-generator-cli.sh > priv/openapitools/openapi-generator-cli
	chmod u+x priv/openapitools/openapi-generator-cli

# Mimicks `mix local.hex --force && mix local.rebar --force` but with version pinning. See:
# - https://github.com/elixir-lang/elixir/blob/master/lib/mix/lib/mix/tasks/local.hex.ex
# - https://github.com/elixir-lang/elixir/blob/master/lib/mix/lib/mix/tasks/local.rebar.ex
install-hex-rebar:
	mix archive.install ${HEX_URL} --force --sha512 ${HEX_SHA}
	mix local.rebar rebar ${REBAR_URL} --force --sha512 ${REBAR_SHA}
	mix local.rebar rebar3 ${REBAR3_URL} --force --sha512 ${REBAR3_SHA}
