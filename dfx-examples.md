## Add

` dfx canister call artistRegistry add '(principal "<principal>", record {thumbnail="lol"; name="lol"; frontend=null; description="lol"; details=vec {record {"lol"; variant {Text="lol"}}}; principal_id=principal "<principal>"})' `

## Get

` dfx canister call artistRegistry get '(principal "<principal>")' `

## Remove

` dfx canister call artistRegistry remove '(principal "<principal>")' `