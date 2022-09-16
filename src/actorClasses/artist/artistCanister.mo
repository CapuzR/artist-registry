import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Hash       "mo:base/Hash";
import HashMap    "mo:base/HashMap";
import Iter    "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Prim "mo:⛔";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Trie "mo:base/Trie";

import Source "mo:uuid/async/SourceV4";
import UUID "mo:uuid/UUID";

import Hex "../../Hex";
import ICP "../../ICPledger";
import NFTTypes "../NFT/types";
import Token "../NFT/token";
import Types "./types";
import TypesInvoices "../../types";
import Utils "../../utils";
import assetC "../asset/assetCanister";
import nFTC "../NFT/main";

shared({ caller = artistRegistry }) actor class ArtistCanister(artistMeta : Types.Metadata, artistRegistryId : Principal) = this {

    let limit = 10_000_000_000;
    type Metadata = Types.Metadata;
    type Error = Types.Error;
    type Art = Types.Art;
    type ArtUpdate = Types.ArtUpdate;

    stable var arts : Trie.Trie<Text, Art> = Trie.empty();
    stable var registryName : Text = Text.concat(artistMeta.name, "Artist Canister");
    stable var canisterMeta : Metadata = artistMeta;
    stable var artistRegistry : Principal = artistRegistryId;
    stable var assetCanisterIds : [Principal] = [];
    stable var nftCanisters : [Types.NFTMetadataExt] = [];
    stable var authorized : [Principal] = [artistRegistry, artistMeta.principal_id];
    stable var owners : [Principal] = [artistRegistry, artistMeta.principal_id];

     var invoices = HashMap.HashMap<Nat, Types.Invoice>(1, Nat.equal, Hash.hash);
     var counter : Nat = 0;

     public shared query ({caller}) func getInvoices() : async Result.Result<[(Nat, Types.Invoice)], TypesInvoices.InvoiceError> {
        
        if(not Utils.isAuthorized(caller, owners)) {
            return #err(
                {
                    message = ?"Invoice not found";
                    kind = #NotAuthorized;
                }
            );
        };

        let invBuff : Buffer.Buffer<(Nat, Types.Invoice)> = Buffer.Buffer(0);

        for (inv in invoices.entries()) {
            invBuff.add(inv);
        };

        #ok(invBuff.toArray());
     };

     public shared query ({caller}) func getInvoice (id:Nat) : async Result.Result<Types.Invoice, TypesInvoices.InvoiceError> {
        if(Principal.isAnonymous(caller)) {
        return #err({
            message = ?"Not Authorized";
            kind = #NotAuthorized ;
            });
        };

        switch (invoices.get(id)) {
            case null {
                #err({
                    message = ?"Invoice not found";
                    kind = #NotFound;
                });
            };
            case (? v) {
                #ok((v))
            };
        };
    };

    public shared ({caller}) func createInvoice ( token : Text, amount : Nat, quantity : Nat, tokenIndexes : ?[Text] ) : async Result.Result<Types.CreateInvoiceResult, TypesInvoices.InvoiceError> {
    
        if(Principal.isAnonymous(caller)) {
            return #err({
                message = ?"Not Authorized";
                kind = #NotAuthorized ;
            });
        };

        let invoiceId : Nat = counter + 1;
        counter+=1;

        let account = await getAccount(
            token,
            caller,
            invoiceId,
            Principal.fromActor(this)
        );

        switch(account){
            case (#err(e)) {
                return #err(e);
            };
            case (#ok(result)){
                switch(result){
                    case (#text (textAccount)){
                        invoices.put(
                            invoiceId, 
                            { 
                                id = invoiceId; 
                                creator = artistRegistry; 
                                amount = amount; 
                                token = "ICP"; 
                                destination=textAccount; 
                                quantity = quantity;
                                tokenIndexes = tokenIndexes;
                            }
                        );
            
                        #ok({
                            invoice = {
                                id = invoiceId;
                                creator = artistRegistry;
                                amount = amount;
                                token = token;
                                destination = textAccount;
                                quantity = quantity;
                                tokenIndexes = tokenIndexes;
                            };
                            subAccount = textAccount;
                        });
                    };
                };
            };
            case (_){
                #err({
                message = ?"Not Yet";
                kind = #NotYet;
                });
            } 
        };
    };

    public shared ({caller}) func isVerifyPayment ( invoiceId : Nat, nftCanId : Principal ) : async Result.Result<(), TypesInvoices.InvoiceError> {

        let canisterId = Principal.fromActor(this);
        let currentInvoice = await getInvoice(invoiceId);
         
        switch (currentInvoice) {
          case (#err(e)) {
            return #err(e);
          };
          case (#ok(invoice)) {
             
            switch (invoice.token){
              case("ICP"){
                let balanceResult = await ICP.balance(invoice.destination);
                switch(balanceResult){
                    case(#err err) {
                        return #err({
                            message = ?"Error in get balance";
                            kind = #Other;
                        });
                    };
                    case(#ok balance){
                        if(balance < invoice.amount){
                            return #err({
                                message = ?"Insuficient balance for validate invoice";
                                kind = #Other;
                            });
                        } else {
                            let tokenIds = await balanceOfNFTCan(nftCanId, canisterId);
                            var count : Nat = 0;
                            
                            label l for (tokenId in tokenIds.vals()) {
                                if(count <= invoice.quantity) {
                                    let transferResult = await transferAuthNFT(nftCanId, caller, tokenId);
                                    switch(transferResult){
                                        case(#err err) {
                                            return #err({
                                                message = ?"Error in transfer NFT";
                                                kind = #Other;
                                            });
                                        }; 
                                        case (#ok){
                                            continue l;
                                        };   
                                    };
                                    count += 1;
                                } else {
                                    break l;
                                };
                            };
                            #ok(()); 
                        };
                    };
                };
            };
              case(_){
                return #err({
                  message = ?"This token is not yet supported. Currently, this canister supports ICP.";
                  kind = #NotFound;
                });
              };
            };
          };
        };
    };

    private func isIn(id : Text, tokenIndexes : ?[Text]) : Bool {

        switch(tokenIndexes){
            case (null) { return false; };
            case ( ?tki ) {
                for (i in tki.vals()) {
                    if (i == id) {
                        return true;
                    };
                };
                return false;
            };
        };
    };

    public shared ({caller}) func isVerifyTransferWH (canisterId: Text, ids : [Text], invoiceId : Nat) : async Result.Result<(), TypesInvoices.InvoiceError> {
            
        label l for(id in ids.vals()) {
            let currentInvoice = await getInvoice(invoiceId);
            switch (currentInvoice) {
                case (#err(e)) {
                    return #err(e);
                };
                case (#ok(invoice)) {
                    if (isIn(id, invoice.tokenIndexes)) {
                        let nftCan : Principal = Principal.fromText(canisterId);
                        let ownerRes = await ownerOfNFTCan(nftCan, id);
                        switch(ownerRes) {
                            case (#err(e)) {
                                return #err({
                                    message = ?"Other";
                                    kind = #Other;
                                });
                            };
                            case (#ok(owner)) { 
                                if(owner == Principal.fromText("e3mmv-5qaaa-aaaah-aadma-cai")){
                                    switch(await getToken(nftCan, id)){
                                        case (#err(e)) {
                                            return #err({
                                                message = ?"Other";
                                                kind = #Other;
                                            });
                                        };
                                        case (#ok(token)) {
                                            label m for (prop in token.properties.vals()) {
                                                if (prop.name == "burnedBy") {
                                                    switch (prop.value) {
                                                        case ( #Principal (val) ) { 
                                                            if (val == caller) {
                                                                if (prop.name == "invoiceId") {
                                                                    switch (prop.value) {
                                                                        case ( #Text (val) ) { 
                                                                            if (val == invoiceId) {
                                                                                continue l;
                                                                            } else {
                                                                                return #err({
                                                                                    message = ?"Not the owner";
                                                                                    kind = #NotFound;
                                                                                });
                                                                            };
                                                                        };
                                                                        case ( _ ) { 
                                                                            
                                                                        };
                                                                    }
                                                                };
                                                            } else {
                                                                return #err({
                                                                    message = ?"Not the owner";
                                                                    kind = #NotFound;
                                                                });
                                                            };
                                                        };
                                                        case ( _ ) { 
                                                            
                                                        };
                                                    }
                                                };
                                            };
                                            continue l;
                                        };
                                    };
                                } else {
                                    return #err({
                                    message = ?"Error in verify transfer";
                                    kind = #NotFound;
                                }); 
                                };
                            };
                            
                        // let owner = Principal.toText(token.owner);
                        };
                    } else {
                        return #err({
                            message = ?"You're trying to pay with wrong WH.";
                            kind = #NotFound;
                        });
                    };
                };
            };
        };
        #ok(());
    };
        private func transferAuthNFT (nftCanId : Principal, to : Principal, id : Text) : async Result.Result<(), NFTTypes.Error> {

        let service = actor(Principal.toText(nftCanId)): actor {
            transfer : (Principal, Text) -> async ({ 
                #err : NFTTypes.Error;
                #ok;
             });
             authorize : (Token.AuthorizeRequest) -> async ({
                #err : NFTTypes.Error;
                #ok;
             });
        };

        switch(await service.transfer(to, id)) {
            case (#ok) {
                switch(await service.authorize({    
                    id = id;
                    p = Principal.fromActor(this);
                    isAuthorized = false;
                })) {
                    case (#ok) { #ok(());  };
                    case (#err(e)) { return #err(e) };
                };
            };
            case (#err(e)) { return #err(e) };
        };
    };

    private func getAccount (token : Text, principal : Principal, invoiceId : Nat, canisterId : Principal)  :  async Result.Result<TypesInvoices.AccountIdentifier, TypesInvoices.InvoiceError> {
      switch(token){
        case("ICP"){
          let account = Utils.getICPAccountIdentifier({
            principal = canisterId;
            subaccount = Utils.generateInvoiceSubaccount({
              caller = principal;
              id = invoiceId;
            })
          });
          let hexEncoded = Hex.encode(Blob.toArray(account));
          let result : TypesInvoices.AccountIdentifier = #text(hexEncoded);
          return #ok(result);
        };
        case(_){
           #err({
          message = ?"Invalid token";
          kind = #InvalidToken ;
        });
        };
      };
    };


    public query({caller}) func authorizedArr () : async Result.Result<[Principal], Error> {

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        return #ok(authorized);
    };

    public query func name () : async Text {
        return registryName;
    };

    public query func artistMetadata () : async Metadata {
        return canisterMeta;
    };

    public query func getCanisterId () : async Principal {
        return Principal.fromActor(this);
    };

    public query({caller}) func getAssetCanIds () : async  Result.Result<[Principal], Error>  {

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        return #ok(assetCanisterIds);
    };

    public query({caller}) func getCanIds () : async  [Principal]  {

        return [Principal.fromActor(this), assetCanisterIds[0]];
    };

    public shared({caller}) func createAssetCan () : async Result.Result<(Principal, Principal), Error> {

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        // if(assetCanisterIds.size() != 0) { return #err(#Unknown("Already exists")); };

        let tb : Buffer.Buffer<Principal> = Buffer.Buffer(1);
        
        let cycleShare = 2_000_000_000_000;
        Cycles.add(cycleShare);
        let assetCan = await assetC.Assets(canisterMeta.principal_id);
        let assetCanisterId = await assetCan.getCanisterId();

        tb.add(assetCanisterId);

        assetCanisterIds := tb.toArray();

        return #ok((Principal.fromActor(this), assetCanisterId));

    };

        public query ({caller}) func getContractInfo() : async Types.ContractInfo {
        return {
            heapSize = Prim.rts_heap_size();
            memorySize = Prim.rts_memory_size();
            maxLiveSize = Prim.rts_max_live_size();
            cycles = Cycles.balance();
        };
};

    public shared({caller}) func initNFTCan (nftCanId : Principal, creator : Principal) : async Result.Result<(), Error> {
        
        if(not Utils.isAuthorized(creator, owners) and not Utils.isAuthorized(caller, owners)) {
            return #err(#NotAuthorized);
        };
        if(Utils.isAuthorized(creator, owners) and (Principal.equal(caller, artistRegistry) or Principal.notEqual(caller, creator))) {
            return #err(#NotAuthorized);
        };
        
        let service = actor(Principal.toText(nftCanId)): actor {
            init: () -> async ()
        };

        #ok(await service.init());

    };

    private func ownerOfNFTCan (nftCanId : Principal, id : Text) : async Result.Result<Principal, NFTTypes.Error> {
        
        let service = actor(Principal.toText(nftCanId)): actor {
            ownerOfPublic: (id : Text) -> async ({ 
                #err : NFTTypes.Error;
                #ok : Principal;
             });
        };
        // switch(await service.ownerOfPublic(id : Text))
        await service.ownerOfPublic(id);

    };

    private func balanceOfNFTCan (nftCanId : Principal, ppal : Principal) : async [Text] {
        
        let service = actor(Principal.toText(nftCanId)): actor {
            balanceOfPublic: (ppal : Principal) -> async ([Text]);
        };
        // switch(await service.ownerOfPublic(id : Text))
        await service.balanceOfPublic(ppal);

    };

    private func getTokens (nftCanId : Principal, ppal : Principal) : async Result.Result<[Token.Metadata], NFTTypes.Error> {
        
        let service = actor(Principal.toText(nftCanId)): actor {
            tokenMetadataByOwner: (ppal : Principal) -> async ({ 
                #err : NFTTypes.Error;
                #ok : [Token.Metadata];
             });
        };
        // switch(await service.ownerOfPublic(id : Text))
        await service.tokenMetadataByOwner(ppal);

    };

    private func getToken (nftCanId : Principal, id : Text) : async Result.Result<Token.Metadata, NFTTypes.Error> {
        
        let service = actor(Principal.toText(nftCanId)): actor {
            tokenMetadataByIndex: (id : Text) -> async ({ 
                #err : NFTTypes.Error;
                #ok : Token.Metadata;
             });
        };
        // switch(await service.ownerOfPublic(id : Text))
        await service.tokenMetadataByIndex(id);

    };

    type UpdatableCanisterSettings = {
        controllers : ?[Principal];
    };
    
    let IC =
    actor "aaaaa-aa" : actor {
      update_settings : { 
          canister_id : Principal;
          settings : UpdatableCanisterSettings;
        } ->
        async ();
    };
    
    public shared({caller}) func createNFTCan(nFTMetadata : Types.NFTMetadata, creator : Principal) : async Result.Result<Types.NFTMetadataExt, Error> {
        
                Debug.print(debug_show("aqui0"));
        if(not Utils.isAuthorized(creator, owners) and not Utils.isAuthorized(caller, owners)) {
            return #err(#NotAuthorized);
        };
                Debug.print(debug_show("creator"));
                Debug.print(debug_show(creator));
                Debug.print(debug_show("owners"));
                Debug.print(debug_show(owners));
                Debug.print(debug_show("caller"));
                Debug.print(debug_show(caller));
                Debug.print(debug_show("isAuthorized"));
                Debug.print(debug_show(Utils.isAuthorized(creator, owners)));
                Debug.print(debug_show("caller artistRegistry"));
                Debug.print(debug_show(Principal.equal(caller, artistRegistry)));
                Debug.print(debug_show("caller creator"));
                Debug.print(debug_show(Principal.notEqual(caller, creator)));
                Debug.print(debug_show("both"));
                Debug.print(debug_show((Principal.equal(caller, artistRegistry) or Principal.notEqual(caller, creator))));
                Debug.print(debug_show("all"));
                Debug.print(debug_show(Utils.isAuthorized(creator, owners) and (Principal.equal(caller, artistRegistry) or Principal.notEqual(caller, creator))));
        if(Utils.isAuthorized(creator, owners) and (Principal.equal(caller, artistRegistry) or Principal.notEqual(caller, creator))) {
            return #err(#NotAuthorized);
        };

                Debug.print(debug_show("aqui2"));
        let cycleShare = 400_000_000_000;
        Cycles.add(cycleShare);
                Debug.print(debug_show("aqui3"));
        let newNFTCan = await nFTC.NFT(
            {
                name = nFTMetadata.name;
                symbol = nFTMetadata.symbol;
                supply = nFTMetadata.supply;
                value = nFTMetadata.value;
                website = nFTMetadata.website;
                socials = nFTMetadata.socials;
                prixelart = nFTMetadata.prixelart;
            }, 
            creator
        );
                Debug.print(debug_show("aqui4"));
        let tb : Buffer.Buffer<Types.NFTMetadataExt> = Utils.arrayToBuffer(nftCanisters);   
                Debug.print(debug_show("aqui5"));
        //Is necessary to add canisterInfo here?
        let newNFTCanMeta : Types.NFTMetadataExt =  {
            name = nFTMetadata.name;
            symbol = nFTMetadata.symbol;
            supply = nFTMetadata.supply;
            value = nFTMetadata.value;
            website = nFTMetadata.website;
            socials = nFTMetadata.socials;
            prixelart = nFTMetadata.prixelart;
            principal = Principal.fromActor(newNFTCan);
        };

                Debug.print(debug_show("aqui6"));
        tb.add(newNFTCanMeta);

                Debug.print(debug_show("aqui7"));
        nftCanisters := tb.toArray();
        
                Debug.print(debug_show("aqui8"));
        await IC.update_settings({
            canister_id = Principal.fromActor(newNFTCan);
            settings = {
                controllers = ?[Principal.fromActor(newNFTCan)];
            };
        });
                Debug.print(debug_show("aqui9"));

        #ok(newNFTCanMeta);
    };

    public query func getNFTCan () : async [Types.NFTMetadataExt] {
        return nftCanisters;
    };
    
    public func wallet_receive() : async { accepted: Nat64 } {
        let available = Cycles.available();
        let accepted = Cycles.accept(Nat.min(available, limit));
        { accepted = Nat64.fromNat(accepted) };
    };


//Art...............................................................................
    public shared({caller}) func createArt (art : ArtUpdate) : async Result.Result<Text, Error> {

        let g = Source.Source();
        let artId = UUID.toText(await g.new());

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        let artThumb = "http://" # Principal.toText(assetCanisterIds[0]) # ".raw.ic0.app/A" # artId;
        // let artThumb = Text.concat("http://localhost:8000/", Text.concat(artId, Text.concat(".jpeg?canisterId=", Principal.toText(assetCanisterIds[0]))))
        
        let newArt : Art = {
            artBasics = art.artBasics;
            createdAt = Time.now();
            thumbnail = artThumb;
        };

        let (newArts, existing) = Trie.put(
            arts,         
            Utils.keyText(artId), 
            Text.equal,
            newArt
        );

        switch(existing) {
            case null {
                await _storeImage(Text.concat("T", artId), art.thumbAsset);
                arts := newArts;
                #ok(artId);
            };
            case (? v) {
                #err(#Unknown("Already exists"));
            };
        };
    };
    
    public query({caller}) func privReadArtById (id : Text) : async Result.Result<Art, Error> {
        
        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };
        
        let result : ?Art = Trie.find(
            arts,
            Utils.keyText(id),
            Text.equal
        );
        
        switch (result) {
            case null {
                #err(#NonExistentItem)
            };
            case (? r) {
                #ok(r);
            };
        };
    };

    public shared({caller}) func updateArt (art : ArtUpdate, artId : Text) : async Result.Result<(), Error> {
        
        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        let result = Trie.find(
            arts,
            Utils.keyText(artId),
            Text.equal 
        );

        switch(result) {
            case null {
                #err(#NonExistentItem)
            };
            case (? v) {
                let newArt : Art = {
                    artBasics = art.artBasics;
                    createdAt = v.createdAt;
                    thumbnail = v.thumbnail;
                };

                arts := Trie.replace(
                    arts,
                    Utils.keyText(artId),
                    Text.equal,
                    ?newArt
                ).0;

                if ( art.updateThumbnail ) {
                    await _deleteImage(Text.concat("T", artId));
                    await _storeImage(Text.concat("T", artId), art.thumbAsset);
                };
                return #ok(());
            };
        };
    };

    public shared({caller}) func deleteArt (artId : Text) : async Result.Result<(), Error> {
        
        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        let result = Trie.find(
            arts,
            Utils.keyText(artId),
            Text.equal 
        );

        switch(result) {
            case null {
                #err(#NonExistentItem)
            };
            case (? v) {
                arts := Trie.replace(
                    arts,
                    Utils.keyText(artId),
                    Text.equal,
                    null
                ).0;
                return #ok(());
            };
        };
    };

//Private
    private func _storeImage (name : Text, asset : Blob) : async () {

        let key = Text.concat(name, ".jpeg");
        
        let aCActor = actor(Principal.toText(assetCanisterIds[0])): actor { 
            store : shared ({
                key : Text;
                content_type : Text;
                content_encoding : Text;
                content : Blob;
                sha256 : ?Blob;
            }) -> async ()
        };
        await aCActor.store({
                key = key;
                content_type = "image/jpeg";
                content_encoding = "identity";
                content = asset;
                sha256 = null;
        });

    };

    private func _deleteImage (name : Text) : async () {

        let key = Text.concat(name, ".jpeg");
        
        let aCActor = actor(Principal.toText(assetCanisterIds[0])): actor { 
            delete_asset : shared ({
                key : Text;
            }) -> async ()
        };
        await aCActor.delete_asset({
                key = key;
        });

    };
}