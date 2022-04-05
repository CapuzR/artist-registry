## Add

` dfx canister call artistRegistry add '(record {thumbnail="lol"; name="lol"; frontend=null; description="lol"; details=vec {record {"lol"; variant {Text="lol"}}}; principal_id=principal "m5spm-rypb4-5dh4x-cfmly-f2ngh-qjvm4-wyntp-kbhfk-5mhn7-ag65r-qae"})' `

## Get

` dfx canister call artistRegistry get '(principal "<principal>")' `

## Remove

` dfx canister call artistRegistry remove '(principal "m5spm-rypb4-5dh4x-cfmly-f2ngh-qjvm4-wyntp-kbhfk-5mhn7-ag65r-qae")' `