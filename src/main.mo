import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Trie "mo:base/Trie";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Types "./types";
import Utils "./utils";
import Prim "mo:prim";
import Rels "./Rels/Rels";
import Blob "mo:base/Blob";

import aC "./actorClasses/artist/artistCanister";
import assetC "./actorClasses/asset/assetCanister";

shared({ caller = owner }) actor class(initOptions: Types.InitOptions) = this {

//-------------------Types

    type Metadata = Types.Metadata;
    type Error = Types.Error;
    type DetailValue = Types.DetailValue;

//-------------------State
    stable var admins : [Principal] = initOptions.admins; 
    stable var artistWhitelist : [Principal] = initOptions.artistWhitelist;

    stable var assetCanisterIds : [Principal] = [];

    stable var usernamePpal : [(Text, Principal)] = [];//username,artistPrincipal
    let usernamePpalRels = Rels.Rels<Text, Principal>((Text.hash, Principal.hash), (Text.equal, Principal.equal), usernamePpal);

    stable var artists : Trie.Trie<Principal, Metadata> = Trie.empty();
    stable var registryName : Text = "Artists registry";

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

        var assetName = "http://localhost:8000/";
        let avatarKey = Text.concat("A", Principal.toText(caller));
        assetName := Text.concat(assetName,  avatarKey);
        assetName := Text.concat(assetName, "?canisterId=");
        assetName := Text.concat(assetName, Principal.toText(assetCanisterIds[0]));

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

    public shared({caller}) func createArtistCan() : async Result.Result<(Principal, Principal), Error> {

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
                if(Utils.isInDetails(v.details, "canisterId")) { return #err(#Unknown("Already exists")); };

                let artistCan = await aC.ArtistCanister(v);
                 
                switch(await artistCan.createAssetCan()) {
                    case (#ok canPpals) {
                        let (canisterId, assetCanId)  : (Principal, Principal) = canPpals;
                        let buff : Buffer.Buffer<(Text, DetailValue)> = Utils.arrayToBuffer(v.details);
                        buff.add(("canisterId", #Principal(canisterId)));
                        buff.add(("assetCanId", #Principal(assetCanId)));

                        let artist: Metadata = {
                            thumbnail = v.thumbnail;
                            name = v.name;
                            frontend = null;
                            description = v.description;
                            principal_id = v.principal_id;
                            details = buff.toArray();
                        };
                        let dummy = await _update(caller, artist);
                        #ok((canisterId, assetCanId));

                    };
                    case (#err e) { return #err(e)};
                };
            };
            case null {
                return #err(#NonExistentItem);
            };
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

    public shared({caller}) func createAssetCan () : async Result.Result<(Principal, Principal), Error> {

        if(not Utils.isAuthorized(caller, admins)) {
            return #err(#NotAuthorized);
        };

        if(assetCanisterIds.size() != 0) { return #err(#Unknown("Already exists")); };

        let tb : Buffer.Buffer<Principal> = Buffer.Buffer(1);
        let assetCan = await assetC.Assets(caller);
        let assetCanisterId = await assetCan.getCanisterId();

        tb.add(assetCanisterId);

        assetCanisterIds := tb.toArray();

        return #ok((Principal.fromActor(this), assetCanisterId));

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

    public query func getCanMemInfo() : async () {

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
    
//---------------Upgrades

    system func preupgrade() {

        usernamePpal := getAllUsernamePpalRels();

    };

    system func postupgrade() {
        
        usernamePpal := [];

    };

};
