-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean:; forge clean

# Remove modules
remove:; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install:; forge install chainaccelorg/foundry-devops@0.0.11 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install transmissions11/solmate@v6 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test:; forge test

testOneFn:
	@forge test --fork-url $(SEPOLIA_RPC_URL) --mt test_CanPerformUpkeepAndHypeMeme -vvvv

testForkMainnet:
	@forge test --fork-url $(MAINNET_RPC_URL)

testForkMainnetCoverage:
	@forge coverage --fork-url $(MAINNET_RPC_URL)

testForkMainnetCoverageReport:
	@forge coverage --fork-url $(MAINNET_RPC_URL) --report lcov

testForkPolygon:
	@forge test --fork-url $(POLYGON_RPC_URL)

testForkPolygonCoverage:
	@forge coverage --fork-url $(POLYGON_RPC_URL)

testForkPolygonCoverageReport:
	@forge coverage --fork-url $(POLYGON_RPC_URL) --report lcov

testForkAvalanche:
	@forge test --fork-url $(AVALANCHE_RPC_URL)

testForkAvalancheCoverage:
	@forge coverage --fork-url $(AVALANCHE_RPC_URL)

testForkAvalancheCoverageReport:
	@forge coverage --fork-url $(AVALANCHE_RPC_URL) --report lcov

testForkSepolia:
	@forge test --fork-url $(SEPOLIA_RPC_URL)

testForkSepoliaCoverage:
	@forge coverage --fork-url $(SEPOLIA_RPC_URL)

testForkSepoliaCoverageReport:
	@forge coverage --fork-url $(SEPOLIA_RPC_URL) --report lcov

snapshot:; forge snapshot

format:; forge fmt

anvil:; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS:= --rpc-url http://localhost:8545 --private-key $(LOCAL_PRIVATE_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS:= --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deployDYM:
	@forge script script/DeployDYM.s.sol:DeployDYM $(NETWORK_ARGS)

deployDFM:
	@forge script script/DeployDFM.s.sol:DeployDFM $(NETWORK_ARGS)

deployAST:
	@forge script script/DeployAsta.s.sol:DeployAsta $(NETWORK_ARGS)

swapETH:
	@forge script script/Interactions.s.sol:SwapETH $(NETWORK_ARGS)

createPool:
	@forge script script/Interactions.s.sol:CreatePool $(NETWORK_ARGS)

balance:
	@forge script script/Interactions.s.sol:CheckTokenBalance $(NETWORK_ARGS)
