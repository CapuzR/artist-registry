## Add

` dfx canister call artistRegistry add '(record {thumbnail="lol"; name="lol"; frontend=null; description="lol"; details=vec {record {"username"; variant {Text="capuzr"}}}; principal_id=principal "exr4a-6lhtv-ftrv4-hf5dc-co5x7-2fgz7-mlswm-q3bjo-hehbc-lmmw4-tqe"})' `

## Get

` dfx canister call artistRegistry get '(principal "<principal>")' `

## Remove

` dfx canister call artistRegistry remove '(principal "exr4a-6lhtv-ftrv4-hf5dc-co5x7-2fgz7-mlswm-q3bjo-hehbc-lmmw4-tqe")' `