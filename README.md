# Artist Registry

Artists Registry.

## Deploy it

### 1. Deploy socials canister
```bash
dfx deploy artistRegistry --argument '(record { admins = vec { principal "'$(dfx identity get-principal)'" }; artistWhitelist = vec { principal "'$(dfx --identity=player1 identity get-principal)'" }})'
dfx canister install artistRegistry --mode upgrade --argument '(record { admins = vec { principal "'$(dfx identity get-principal)'" }; artistWhitelist = vec { principal "'$(dfx identity get-principal)'" }})'
```

### 2. Deploy its asset canister
```bash
dfx canister call artistRegistry createAssetCan
```

# Whitelist

```bash
dfx canister call artistRegistry whitelistArtists '(vec { principal "bum4c-sxl2u-t64yr-crqjb-q5ovk-fwu7b-m6fnw-7z2vy-mh3f3-delh5-wae"; principal "'$(dfx --identity=player5 identity get-principal)'" })'
```

### 3. Add artist

```bash
dfx --identity=player5 canister call artistRegistry add '( record { thumbnail = "T1"; name = "Test1"; frontend = null; description = "Test1"; principal_id = principal "'$(dfx --identity=player5 identity get-principal)'"; details = vec {  }; } )'
```

## Test it

### 1. Name.

```bash
dfx canister call artistRegistry name
```

## Deposit Cycles to canister 

```bash
dfx wallet --network local send "rrkah-fqaaa-aaaaa-aaaaq-cai" 10000000000000
```

## Create Artist Can

```bash
dfx --identity=player1 canister call artistRegistry createArtistCan '()'
```

## Create NFT Can

```bash
dfx --identity=player5 canister call qjdve-lqaaa-aaaaa-aaaeq-cai createNFTCan '(record { name = "Test1"; symbol = "T1"; supply = 3; website = "test1.com"; socials = vec { null }; prixelart = "Test1"; principal "'$(dfx --identity=player5 identity get-principal)'" }, principal "'$(dfx --identity=player5 identity get-principal)'")'
```

## Init NFT Can

```bash
dfx --identity=player5 canister call renrk-eyaaa-aaaaa-aaada-cai initNFTCan '(principal "qoctq-giaaa-aaaaa-aaaea-cai", principal "'$(dfx --identity=player5 identity get-principal)'")' 
```

## Mint 1 NFT

```bash
dfx --identity=player6 canister call q4eej-kyaaa-aaaaa-aaaha-cai mint '( record { payload = variant { Payload = blob "/0x49" }; contentType = "image/jpeg"; owner = principal "'$(dfx --identity=player6 identity get-principal)'"; properties = vec { record { name = "Test1"; value =  variant { Text = "Lol" }; immutable = true } }; isPrivate = false; } )'
```

## Transfer NFT

```bash
dfx --identity=default canister call q4eej-kyaaa-aaaaa-aaaha-cai transfer '( principal "'$(dfx --identity=player1 identity get-principal)'", "0" )'
```

## Check balance of NFT

```bash
dfx --identity=player5 canister call q4eej-kyaaa-aaaaa-aaaha-cai balanceOf '( principal "'$(dfx --identity=player5 identity get-principal)'" )'
```

## Authorize third-party to manage NFT

```bash
dfx --identity=player6 canister call q4eej-kyaaa-aaaaa-aaaha-cai authorize '( record { id="2"; p = principal "'$(dfx --identity=default identity get-principal)'"; isAuthorized = true; } )'
```

## Artist Registry transfer being authorized.

```bash
dfx canister call artistRegistry transferAuthNFT '( principal "q4eej-kyaaa-aaaaa-aaaha-cai", principal "'$(dfx --identity=player3 identity get-principal)'", "0" )'
```


dfx canister call renrk-eyaaa-aaaaa-aaada-cai mint '( record { payload = variant { Payload = "/0x49" }; contentType = "image/jpeg"; owner = "'$(dfx --identity=User0 identity get-principal)'"; properties= vec { record { name="1"; value = variant { Text = "val1" }; immutable = true; } }; isPrivate=false; } )'

//Local
dfx deploy socials --argument '(record { authorized = vec { principal "'$(dfx identity get-principal)'" }})'
dfx canister call socials createAssetCan
dfx deploy artistRegistry --argument '(record { admins = vec { principal "'$(dfx identity get-principal)'" }; artistWhitelist = vec { principal "'$(dfx identity get-principal)'" }})'
dfx canister call artistRegistry createAssetCan
dfx canister call artistRegistry whitelistArtists '(vec { principal "bum4c-sxl2u-t64yr-crqjb-q5ovk-fwu7b-m6fnw-7z2vy-mh3f3-delh5-wae"; principal "avo45-hly5c-royjn-4dkiq-il5qh-gzydu-jlkko-2uuxv-kznnc-cw46t-xae"; principal "mlvdq-eg2nv-zsiyw-gc5yk-mvwsn-wd3m6-a2d2i-tf2lf-xbpvu-yhfzb-sqe"; principal "ig7ub-7l5g7-sjhup-z57ap-qchw6-2vvfp-rzdkw-xecys-5z6us-3d4jm-7ae"; principal "agxe3-xikyh-anb3s-36fp2-hx7cb-rgmbw-hc4yh-bu5gd-zsluj-rjgt7-wqe"; principal "'$(dfx identity get-principal)'" })'
dfx deploy prixelart_assets

//IC
dfx deploy socials --network ic --argument '(record { authorized = vec { principal "'$(dfx identity get-principal)'" }})'

dfx canister --network ic call socials createAssetCan

dfx deploy artistRegistry --network ic --argument '(record { admins = vec { principal "'$(dfx identity get-principal)'" }; artistWhitelist = vec { principal "bum4c-sxl2u-t64yr-crqjb-q5ovk-fwu7b-m6fnw-7z2vy-mh3f3-delh5-wae"; principal "avo45-hly5c-royjn-4dkiq-il5qh-gzydu-jlkko-2uuxv-kznnc-cw46t-xae"; principal "mlvdq-eg2nv-zsiyw-gc5yk-mvwsn-wd3m6-a2d2i-tf2lf-xbpvu-yhfzb-sqe"; principal "ig7ub-7l5g7-sjhup-z57ap-qchw6-2vvfp-rzdkw-xecys-5z6us-3d4jm-7ae"; principal "agxe3-xikyh-anb3s-36fp2-hx7cb-rgmbw-hc4yh-bu5gd-zsluj-rjgt7-wqe" }})'

dfx canister --network ic call artistRegistry createAssetCan

dfx canister --network ic call artistRegistry whitelistArtists '(vec { principal "bum4c-sxl2u-t64yr-crqjb-q5ovk-fwu7b-m6fnw-7z2vy-mh3f3-delh5-wae"; principal "avo45-hly5c-royjn-4dkiq-il5qh-gzydu-jlkko-2uuxv-kznnc-cw46t-xae"; principal "mlvdq-eg2nv-zsiyw-gc5yk-mvwsn-wd3m6-a2d2i-tf2lf-xbpvu-yhfzb-sqe"; principal "ig7ub-7l5g7-sjhup-z57ap-qchw6-2vvfp-rzdkw-xecys-5z6us-3d4jm-7ae"; principal "agxe3-xikyh-anb3s-36fp2-hx7cb-rgmbw-hc4yh-bu5gd-zsluj-rjgt7-wqe" })'

dfx deploy --network ic prixelart_assets

dfx canister --network ic call artistRegistry whitelistArtists '(vec { principal "mh5zo-bbknh-tinss-4lvk4-fgz4v-wbs5h-ltia4-oy2mo-oujxu-keuct-wae" })'


//Reinstall
dfx canister --network ic install artistRegistry --mode reinstall --argument '(record { admins = vec { principal "'$(dfx identity get-principal)'" }; artistWhitelist = vec { principal "bum4c-sxl2u-t64yr-crqjb-q5ovk-fwu7b-m6fnw-7z2vy-mh3f3-delh5-wae"; principal "avo45-hly5c-royjn-4dkiq-il5qh-gzydu-jlkko-2uuxv-kznnc-cw46t-xae"; principal "mlvdq-eg2nv-zsiyw-gc5yk-mvwsn-wd3m6-a2d2i-tf2lf-xbpvu-yhfzb-sqe"; principal "ig7ub-7l5g7-sjhup-z57ap-qchw6-2vvfp-rzdkw-xecys-5z6us-3d4jm-7ae"; principal "agxe3-xikyh-anb3s-36fp2-hx7cb-rgmbw-hc4yh-bu5gd-zsluj-rjgt7-wqe" }})'

dfx canister --network ic install socials --mode reinstall --argument '(record { authorized = vec { principal "'$(dfx identity get-principal)'" }})'

