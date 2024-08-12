.PHONY: kill-anvil
kill-anvil: ## kill process running at port 8545 (default port of anvil)
	# may fail, we can ignore that
	lsof -i :8545 -s TCP:LISTEN -t | xargs -I {} -n 1 kill {} || :

.PHONY: run-anvil
run-anvil:
	anvil --block-time 2 >.anvil.log &

# E.g. make anvil-deploy-safe-singleton
.PHONY: anvil-deploy-safe-singleton
anvil-deploy-safe-singleton: ## deploy Safe Singleton contract according to https://github.com/safe-global/safe-singleton-factory/blob/main/artifacts/31337/deployment.json
	if [ "$$(cast code 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7)" != "0x" ]; then \
	  echo "Safe singleton contract already deployed, skipping"; \
	else \
	  	echo "Deploying Safe singleton"; \
		cast send 0xE1CB04A0fA36DdD16a06ea828007E35e1a3cBC37 --value 0.01ether --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 && \
		cast publish "0xf8a78085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf382f4f5a00dc4d1d21b308094a30f5f93da35e4d72e99115378f135f2295bea47301a3165a0636b822daad40aa8c52dd5132f378c0c0e6d83b4898228c7e21c84e631a0b891"; \
	fi

# E.g. make anvil-deploy-safe-suite rpcurl=http://127.0.0.1:8545
.PHONY: anvil-deploy-safe-suite
anvil-deploy-safe-suite: rpcurl=http://127.0.0.1:8545
anvil-deploy-safe-suite: ## deploy basic safe suites locally
	forge script --broadcast script/SafeSuiteSetup.s.sol:SafeSuiteSetupScript --rpc-url $(rpcurl)

deploy-safe:
.PHONY: deploy-safe
deploy-safe: rpcurl=http://127.0.0.1:8545
deploy-safe: account=0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
deploy-safe: ## deploy counter module and some safes
	forge script script/Deployment.s.sol:DeploymentScript --broadcast \
		--sig "deploySafe(address,uint256)" $(account) $$(cast nonce $(account)) --rpc-url $(rpcurl)

# E.g. make create-safes-And-module rpcurl=http://127.0.0.1:8545
.PHONY: create-safes-And-module
create-safes-And-module: numsafe=3
create-safes-And-module: fundinfinney=300
create-safes-And-module: rpcurl=http://127.0.0.1:8545
create-safes-And-module: ## deploy counter module and some safes
	forge script script/Deployment.s.sol:DeploymentScript --broadcast \
		--sig "createSafesAndModule(uint256,uint256)" $(numsafe) $(fundinfinney) --rpc-url $(rpcurl)

# E.g. make call-counter
.PHONY: call-counter
call-counter: account=0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
call-counter: pk=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
call-counter: rpcurl=http://127.0.0.1:8545
call-counter: ## call counter
	cast send $(module) "increment(address)" $(safe) \
		--rpc-url $(rpcurl) --private-key $(pk)


# E.g. make call-get-counter
.PHONY: call-get-counter
call-get-counter: account=0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
call-get-counter: pk=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
call-get-counter: rpcurl=http://127.0.0.1:8545
call-get-counter: ## call counter
	cast call $(module) "getCount(address)" $(safe) \
		--rpc-url $(rpcurl) --private-key $(pk)


.PHONY: run-local
run-local: ## run local
	echo "Starting Anvil on host"
	make kill-anvil
	make run-anvil
	make anvil-deploy-safe-singleton
	make anvil-deploy-safe-suite
	echo "To test counter, please run:"
	make create-safes-And-module | \
		grep -oE "Counter module: [^ ]+|Safe: [^ ]+" | \
		awk '{ \
			if ($$1 == "CounterModule") { \
				counter = $$3; \
			} else { \
				safes = safes $$2 " "; \
			} \
		} \
		END { \
			split(safes, safe_array); \
			for (i = 1; i <= length(safe_array); i++) { \
				printf("make call-counter module=%s safe=%s\n", counter, safe_array[i]); \
			} \
		}'