
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";

import Hex "./Hex";
import Types "./types";



module {

    public func balance(account : Text) : async Result.Result<Nat, Types.InvoiceError> {
        switch (Hex.decode(account)){
            case (#err err){
               #err({
                message = ?"Invalid account";
                kind =  #InvalidAccount ;
              });
            };
            case (#ok account) {
                //Local Faucet canister.
                let ledger = actor("rrkah-fqaaa-aaaaa-aaaaq-cai"): actor {
                    account_balance : query (Types.AccountBalanceArgs) -> async (Types.Tokens)
                };
                let balance = await ledger.account_balance({account = Blob.fromArray(account)});
                #ok(Nat64.toNat(balance.e8s));
            };
        };
    };
    
    // public func transfer(args : T.TransferArgs) : async T.TransferResult {
        
    //     //Local Faucet canister.
    //     let ledger = actor("vttjj-zyaaa-aaaal-aabba-cai"): actor {
    //         transfer : (T.TransferArgs) -> async (T.TransferResult)
    //     };
        
    //     switch(await ledger.transfer(args)) {
    //         case (#Ok(res)) { #Ok(res); };
    //         case (#Err(e)) { #Err(e); };
    //     };
    // };

}