# Account Abstraction Paymaster Contract

### Environment Variables

```
RPC_URL=https://rpc.fusespark.io
PRIVATE_KEY=
ENTRY_POINT=0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
SPONSOR_ADDRESS=
SPONSOR_PRIVATE_KEY=
```

### Deployment

```
forge script script/EtherspotPaymaster.s.sol --chain-id 123 --fork-url https://rpc.fusespark.io --broadcast -vvvv --legacy --verify
```

```
cast send CONTRACT_ADDRESS --private-key "xxxx" "depositFunds()()" --value 0.8ether --chain-id 123 --rpc-url https://rpc.fusespark.io --legacy
```

```
cast call CONTRACT_ADDRESS "sponsorFunds()(uint256)" --chain-id 123 --rpc-url https://rpc.fusespark.io --legacy
```
