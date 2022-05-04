# Artist Registry

Artists Registry.

## Deploy it

### 1. Deploy socials canister
```bash
dfx deploy artistRegistry --argument '(record { admins = vec { principal "'$(dfx identity get-principal)'" }; artistWhitelist = vec { principal "'$(dfx identity get-principal)'" }})'
```

### 2. Deploy its asset canister
```bash
dfx canister call artistRegistry createAssetCan
```

## Test it

### 1. Name.

```bash
dfx canister call artistRegistry name
```

# Whitelist

```bash
dfx canister call artistRegistry whitelistArtists '(vec { principal "bum4c-sxl2u-t64yr-crqjb-q5ovk-fwu7b-m6fnw-7z2vy-mh3f3-delh5-wae" })'
```