import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Hash       "mo:base/Hash";
import HashMap    "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Trie "mo:base/Trie";

import Hex "./Hex";
import ICP "./ICPledger";
import NFTTypes "./actorClasses/NFT/types";
import Rels "./Rels/Rels";
import TokenTypes "./actorClasses/NFT/token";
import Types "./types";
import Utils "./utils";
import aC "./actorClasses/artist/artistCanister";
import assetC "./actorClasses/asset/assetCanister";

shared({ caller = owner }) actor  class(initOptions: Types.InitOptions) = ArtistRegistry {

//-------------------Types

    type Metadata = Types.Metadata;
    type Error = Types.Error;
    type DetailValue = Types.DetailValue;

//-------------------State
    stable var admins : [Principal] = initOptions.admins; 
    stable var artistWhitelist : [Principal] = initOptions.artistWhitelist;

    stable var assetCanisterIds : [Principal] = [];

    stable var usernamePpal : [(Text, Principal)] = []; //username,artistPrincipal
    let usernamePpalRels = Rels.Rels<Text, Principal>((Text.hash, Principal.hash), (Text.equal, Principal.equal), usernamePpal);
    
    stable var artists : Trie.Trie<Principal, Metadata> = Trie.empty();
    stable var registryName : Text = "Artists registry";

    //-------------------Invoices states;

     var invoices = HashMap.HashMap<Nat, Types.Invoice>(1, Nat.equal, Hash.hash);
     var counter : Nat = 0;
    //  var owner : Principal =  Principal.fromActor(ArtistRegistry);

    //-------------------Invoices methods;

    public shared query ({caller}) func getInvoice (id:Nat) : async Result.Result<Types.Invoice, Types.InvoiceError> {
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

    public shared ({caller}) func createInvoice ( token : Text, amount : Nat, quantity : Nat ) : async Result.Result<Types.CreateInvoiceResult, Types.InvoiceError> {
    
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
        Principal.fromActor(ArtistRegistry)
        );
        switch(account){
        case (#err(e)) {
            return #err(e);
        };
        case (#ok(result)){
            
            switch(result){
            case (#text (textAccount)){
                invoices.put(invoiceId, { id = invoiceId; creator = owner; amount = amount; token = "ICP"; destination=textAccount; quantity = quantity });
    
                #ok({
                    invoice = {
                    id=invoiceId;
                    creator=owner;
                    amount=amount;
                    token=token;
                    destination=textAccount;
                    quantity=quantity;
                };
                subAccount=textAccount;
                });
            }
            }
        };
        case (_){
            #err({
            message = ?"Not Yet";
            kind = #NotYet;
            });
        } 
        };
    };

    private func getAccount (token : Text, principal : Principal, invoiceId : Nat, canisterId : Principal)  :  async Result.Result<Types.AccountIdentifier, Types.InvoiceError> {
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
          let result : Types.AccountIdentifier = #text(hexEncoded);
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

    public shared ({caller}) func isVerifyPayment (invoiceId : Nat) : async Result.Result<Types.CreateCanistersResult, Types.InvoiceError> {

        let canisterId = Principal.fromActor(ArtistRegistry);
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
                        }else{
                            let artistCan = await createArtistCan(caller, invoice.quantity);
                            switch(artistCan){
                                case(#err err){
                                    return #err({
                                        message = ?"Error un create canisters privates";
                                        kind = #Other;
                                    });
                                };
                                case (#ok canisters){
                                    #ok(canisters)
                                }
                            }
                            
                        }
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

    


//-------------------Registry

    public query func name() : async Text {
        return registryName;
    };

    public query func get(principalId : Principal) : async ?Metadata {
        Trie.find(
            artists,
            Utils.key(principalId),
            Principal.equal
        ); 
    };

    public query func getByUsername(username : Text) : async ?Metadata {
    
        let principalIds : [Principal] = _getPrincipalByUsername(username);
    
        if(principalIds.size() != 0) {
            return Trie.find(
                artists,
                Utils.key(principalIds[0]),
                Principal.equal
            ); 
        } else {
            return null;
        };
    };
    
    public query({caller}) func getAll() : async Result.Result<[(Principal,Metadata)], Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let artistIter : Iter.Iter<(Principal, Metadata)> = Trie.iter(artists);
        #ok(Iter.toArray(artistIter));
    };

    public shared({caller}) func add(metadata : Metadata) : async Result.Result<(), Error> {

        if(not Utils.isAuthorized(caller, artistWhitelist)) {
            return #err(#NotAuthorized);
        };

        // var assetName = "http://localhost:8000/";
        // let avatarKey = Text.concat("A", Principal.toText(caller));
        // assetName := Text.concat(assetName,  avatarKey);
        // assetName := Text.concat(assetName, "?canisterId=");
        // assetName := Text.concat(assetName, Principal.toText(assetCanisterIds[0]));
        
        let assetName = "http://" # Principal.toText(assetCanisterIds[0]) # ".raw.ic0.app/A" # Principal.toText(caller);

        let artist : Metadata = {
            thumbnail = assetName;
            name = metadata.name;
            frontend = metadata.frontend;
            description = metadata.description;
            principal_id = metadata.principal_id;
            details = metadata.details;
        };
        

        let (newArtist, existing) = Trie.put(
            artists,
            Utils.key(caller),
            Principal.equal,
            artist
        );

        switch(existing) {
            case null {
                artists := newArtist;
                label l for(d in metadata.details.vals()) {
                    if(d.0 == "username") {
                        switch(d.1){
                            case(#Text(u)) {
                                usernamePpalRels.put(u, caller);
                                continue l;
                            };
                            case (_) {
                                continue l;
                            };
                        };
                    } else if (d.0 == "avatarAsset") {
                        switch(d.1) {
                            case(#Slice(a)) {
                                await _storeImage(Text.concat("A", Principal.toText(metadata.principal_id)), a);
                                continue l;
                            };
                            case (_) {
                                continue l;
                            };
                        };
                    } else if (d.0 == "bannerAsset") {
                        switch(d.1) {
                            case(#Slice(a)) {
                                await _storeImage(Text.concat("B", Principal.toText(metadata.principal_id)), a);
                                continue l;
                            };
                            case (_) {
                                continue l;
                            };
                        };
                    };
                };
                #ok(());
            };
            case (? v) {
                #err(#Unknown("Already exists"));
            };
        };
    };

    public shared({caller}) func remove(principal: Principal) : async Result.Result<(), Error> {

        if(not Utils.isAuthorized(caller, artistWhitelist) or Principal.notEqual(principal, caller)) {
            return #err(#NotAuthorized);
        };

        let result = Trie.find(
            artists,
            Utils.key(principal),
            Principal.equal,
        );

        switch(result) {
            case null {
                #err(#NonExistentItem);
            };
            case (? v) {
                artists := Trie.replace(
                    artists,
                    Utils.key(principal),
                    Principal.equal,
                    null
                ).0;
                await _deleteImage(Text.concat("A", Principal.toText(principal)));
                await _deleteImage(Text.concat("B", Principal.toText(principal)));
                let username = usernamePpalRels.get1(caller);
                if(username.size() != 0) {
                    usernamePpalRels.delete(username[0], caller);
                };
                #ok(());
            };
        };
    };

    public shared({caller}) func update(metadata : Metadata) : async Result.Result<(), Error> {

        if(not Utils.isAuthorized(caller, artistWhitelist) or Principal.notEqual(metadata.principal_id, caller)) {
            return #err(#NotAuthorized);
        };

        await _update(caller, metadata);
    };

    private func _update(principal: Principal, artist : Metadata) : async Result.Result<(), Error> {

        let result = Trie.find(
            artists,           // Target trie
            Utils.key(principal),     // Key
            Principal.equal           // Equality Checker
        );

        switch(result) {
            
            case null {
                #err(#NonExistentItem);
            };
            case (? v) {
                artists := Trie.replace(
                    artists,
                    Utils.key(principal),
                    Principal.equal,
                    ?artist
                ).0;
                label l for(d in artist.details.vals()) {
                    if(d.0 == "username") {
                        switch(d.1){
                            case(#Text(u)) {
                                usernamePpalRels.put(u, principal);
                            };
                            case (_) {
                                break l;
                            };
                        };
                        // #Vec { #Slice { Asset }, #True/#False }
                    } else if (d.0 == "avatarAsset") {
                        switch(d.1){
                            case (#Vec(vB)){
                                switch(vB[1]) {
                                    case(#True) {
                                        switch (vB[0]) {
                                            case(#Slice(a)) {
                                                await _deleteImage(Text.concat("A", Principal.toText(artist.principal_id)));
                                                await _storeImage(Text.concat("A", Principal.toText(artist.principal_id)), a);
                                                break l;
                                            };
                                            case (_) {
                                                break l;
                                            };
                                        };
                                    };
                                    case (_) {
                                        break l;
                                    };
                                };
                            };
                            case (_) {
                                break l;
                            };
                        };
                    } else if (d.0 == "bannerAsset") {
                        switch(d.1){
                            case (#Vec(vB)){
                                switch(vB[1]) {
                                    case(#True) {
                                        switch (vB[0]) {
                                            case (#Slice(a)) {
                                                await _deleteImage(Text.concat("B", Principal.toText(artist.principal_id)));
                                                await _storeImage(Text.concat("B", Principal.toText(artist.principal_id)), a);
                                                break l;
                                            };
                                            case (_) {
                                                break l;
                                            };
                                        };
                                    };
                                    case (_) {
                                        break l;
                                    };
                                };
                            };
                            case (_) {
                                break l;
                            };
                        };
                    };
                };
                #ok(());
            };
        };
    };

    private func createArtistCan(caller : Principal, quantity : Nat) : async Result.Result<Types.CreateCanistersResult, Error> {

        if(not Utils.isAuthorized(caller, artistWhitelist)) {
            return #err(#NotAuthorized);
        };

        let result = Trie.find(
            artists,
            Utils.key(caller),
            Principal.equal,
        );
        
        switch(result) {
            case (? v) {
                if(v.principal_id != caller) { return #err(#NotAuthorized); };
                if(Utils.isInDetails(v.details, "canister   Id")) { return #err(#Unknown("Already exists")); };

                // let cycleShare = ;
                let cycleShare = 10_000_000_000_000;
                Cycles.add(cycleShare);
                let artistCan = await aC.ArtistCanister(v, Principal.fromActor(ArtistRegistry));
                var count : Nat = 0;
                var buff : Buffer.Buffer<Text> = Buffer.Buffer(1);
                
                // buff.add(("canisterId", #Principal(canisterId)));
                // buff.add(("assetCanId", #Principal(assetCanId)));

                // let amountAccepted = await artistCan.wallet_receive();
                while (count < quantity) {
                    count += 1;
                    Debug.print(debug_show(count));
                    let assetCanister = await artistCan.createAssetCan();
                   switch(assetCanister){
                       case (#err err){
                            return #err(#NonExistentItem);
                       };
                       case (#ok canisterIds){
                            Debug.print(debug_show(canisterIds));
                       }
                   }
                };

                #ok({
                        canisterId = "CanisterID";
                        assetCanisters = ["Canister 1", "Canister 2"];
                    });
            };
            case null {
                return #err(#NonExistentItem);
            };
        };
    };

    public shared({caller}) func transferAuthNFT (nftCanId : Principal, to : Principal, id : Text) : async Result.Result<(), NFTTypes.Error> {

        let service = actor(Principal.toText(nftCanId)): actor {
            transfer : (Principal, Text) -> async ({ 
                #err : NFTTypes.Error;
                #ok;
             });
             authorize : (TokenTypes.AuthorizeRequest) -> async ({
                #err : NFTTypes.Error;
                #ok;
             });
        };

        switch(await service.transfer(to, id)) {
            case (#ok) {
                switch(await service.authorize({
                    id = id;
                    p = Principal.fromActor(ArtistRegistry);
                    isAuthorized = false;
                })) {
                    case (#ok) { #ok(());  };
                    case (#err(e)) { return #err(e) };
                };
            };
            case (#err(e)) { return #err(e) };
        };
    };

//-------------------Username
    
    public query func usernameExist (username : Text) : async Bool {
        _usernameExist(username);
    };

    public query func getUsernamesByPrincipal (principal : Principal) : async [Text] {
        _getUsernamesByPrincipal(principal);
    };

    private func _getUsernamesByPrincipal (principal : Principal) : [Text] {
        usernamePpalRels.get1(principal);
    };
    
    public query func getPrincipalByUsername (username : Text) : async [Principal] {
        _getPrincipalByUsername(username);
    };

    private func _getPrincipalByUsername (username : Text) : [Principal] {
        usernamePpalRels.get0(username);
    };

    private func _usernameExist (username : Text) : Bool {
        if(usernamePpalRels.get0Size(username) == 0) { 
            return false;
        } else {
            return true;
        };
    };

    public shared({caller}) func assignUsername (username : Text) : async Result.Result<(), Error> {
        if (Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        } else if (_usernameExist(username)) {
            return #err(#Unknown("Already exists"));
        } else {
            usernamePpalRels.put(username, caller);
            return #ok(());
        };
    };

    private func getAllUsernamePpalRels () : [(Text, Principal)] {
        usernamePpalRels.getAll();
    };

//-------------------Assets
    
    private func _storeImage(key : Text, asset : [Nat8]) : async () {
        
        let aCActor = actor(Principal.toText(assetCanisterIds[0])): actor { 
            store : shared ({
                key : Text;
                content_type : Text;
                content_encoding : Text;
                content : [Nat8];
                sha256 : ?[Nat8];
            }) -> async ()
        };
        let result = await aCActor.store({
                key = key;
                content_type = "image/jpeg";
                content_encoding = "identity";
                content = asset;
                sha256 = null;
        });

    };

    private func _deleteImage(key : Text) : async () {
        
        let aCActor = actor(Principal.toText(assetCanisterIds[0])): actor { 
            delete_asset : shared ({
                key : Text;
            }) -> async ()
        };
        await aCActor.delete_asset({
                key = key;
        });

    };

//-------------------Admins

    public query func balance() : async Nat {
        Cycles.balance();
    };
    
    public shared({caller}) func createAssetCan () : async Result.Result<(Principal, Principal), Error> {

        if(not Utils.isAuthorized(caller, admins)) {
            return #err(#NotAuthorized);
        };

        if(assetCanisterIds.size() != 0) { return #err(#Unknown("Already exists")); };
        let tb : Buffer.Buffer<Principal> = Buffer.Buffer(1);
        
        let cycleShare = 2_000_000_000_000;
        Cycles.add(cycleShare);
        Debug.print(debug_show("LLEGUE HAST"));
        let assetCan = await assetC.Assets(caller);
        let assetCanisterId = await assetCan.getCanisterId();
        
        tb.add(assetCanisterId);

        assetCanisterIds := tb.toArray();

        return #ok((Principal.fromActor(ArtistRegistry), assetCanisterId));

    };

    public shared({caller}) func whitelistArtists (principal : [Principal]) : async Result.Result<(), Error> {
        
        if(not Utils.isAuthorized(caller, admins)) {
            return #err(#NotAuthorized);
        };

        artistWhitelist := Array.append(artistWhitelist, principal);
        return #ok(());

        };

        public shared({caller}) func getWhitelistedArtists () : async Result.Result<[Principal], Error> {
            
        if(not Utils.isAuthorized(caller, admins)) {
            return #err(#NotAuthorized);
        };

        return #ok(artistWhitelist);

    };

    public shared({caller}) func isArtistWhitelisted (principal : Principal) : async Result.Result<Bool, Error> {
            
        if(not Utils.isAuthorized(caller, admins)) {
            return #err(#NotAuthorized);
        };

        return #ok(Utils.isAuthorized(principal, artistWhitelist));

    };

    public query func getCanMemInfo () : async () {

        return ();

        //   Debug.print(debug_show("memory size"));
        //   Debug.print(debug_show(Prim.rts_memory_size()));
        //   Debug.print(debug_show("Stable memory size"));
        //   Debug.print(debug_show(Prim.stableMemorySize()));
        //   Debug.print(debug_show("total_allocation"));
        //   Debug.print(debug_show(Prim.rts_total_allocation()));
        //   Debug.print(debug_show("max live size"));
        //   Debug.print(debug_show(Prim.rts_max_live_size()));
        //   Debug.print(debug_show("heap"));
        //   Debug.print(debug_show(Prim.rts_heap_size()));
    };
    
    public shared({caller}) func wallet_receive() : async () {
        ignore Cycles.accept(Cycles.available());
    };
    
//---------------Upgrades

    system func preupgrade() {

        usernamePpal := getAllUsernamePpalRels();

    };

    system func postupgrade() {
        
        usernamePpal := [];

    };

};
