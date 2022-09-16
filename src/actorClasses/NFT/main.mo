import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Iter "mo:base/Iter";
import Prim "mo:⛔";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import Event "event";
import Http "http";
import MapHelper "mapHelper";
import Property "property";
import Staged "staged";
import Static "static";
import Token "token";
import Types "types";

shared({ caller = artistCanister }) actor class NFT(contractMetadata : Types.ContractMetadata, nftCreator : Principal) = NFTService {
    var MAX_RESULT_SIZE_BYTES     = 1_000_000; // 1MB Default
    var HTTP_STREAMING_SIZE_BYTES = 1_900_000;

    stable var CONTRACT_METADATA : Types.ContractMetadata = contractMetadata;
    stable var INITALIZED : Bool = false;

    stable var TOPUP_AMOUNT             = 2_000_000;
    stable var BROKER_CALL_LIMIT        = 25;
    stable var BROKER_FAILED_CALL_LIMIT = 25;

    stable var id          = 0;
    stable var payloadSize = 0;
    stable var nftEntries : [(
        Text, // Token Identifier.
        (
            ?Principal, // Owner of the token.
            [Principal] // Authorized principals.
        ),
        Token.Token, // NFT data.
    )] = [];
    let nfts = Token.NFTs(
        id, 
        payloadSize, 
        nftEntries,
    );

    stable var staticAssetsEntries : [(
        Text,        // Asset Identifier (path).
        Static.Asset // Asset data.
    )] = [];
    let staticAssets = Static.Assets(staticAssetsEntries);
    
    stable var contractOwners : [Principal] = [nftCreator, artistCanister];

    stable var messageBrokerCallback : ?Event.Callback = null;
    stable var messageBrokerCallsSinceLastTopup : Nat = 0;
    stable var messageBrokerFailedCalls : Nat = 0;

    let IC =
    actor "aaaaa-aa" : actor {
      update_settings : { 
          canister_id : Principal;
          settings : UpdatableCanisterSettings;
        } ->
        async ();
    };

    public type UpdateEventCallback = {
        #Set : Event.Callback;
        #Remove;
    };

    // Removes or updates the event callback.
    public shared ({caller}) func updateEventCallback(update : UpdateEventCallback) : async () {
        assert(_isOwner(caller));
        // TODO: reset 'failed calls/calls since last topup'?
        switch (update) {
            case (#Remove) {
                messageBrokerCallback := null;  
            };
            case (#Set(cb)) {
                messageBrokerCallback := ?cb;
            };
        };
    };

    // Returns the event callback status.
    public shared ({caller}) func getEventCallbackStatus() : async Event.CallbackStatus {
        assert(_isOwner(caller));
        return {
            callback            = messageBrokerCallback;
            callsSinceLastTopup = messageBrokerCallsSinceLastTopup;
            failedCalls         = messageBrokerFailedCalls;
            noTopupCallLimit    = BROKER_CALL_LIMIT;
            failedCallsLimit    = BROKER_FAILED_CALL_LIMIT;
        };
    };

    system func preupgrade() {
        id                  := nfts.currentID();
        payloadSize         := nfts.payloadSize();
        nftEntries          := Iter.toArray(nfts.entries());
        staticAssetsEntries := Iter.toArray(staticAssets.entries());
    };

    system func postupgrade() {
        id                  := 0;
        payloadSize         := 0;
        nftEntries          := [];
        staticAssetsEntries := [];
    };

    type UpdatableCanisterSettings = {
        controllers : ?[Principal];
    };

    type CanisterSettings = {
        controllers : ?[Principal];
        compute_allocation : ?Nat;
        memory_allocation : ?Nat;
        freezing_threshold : ?Nat;
    };
    // Initializes the contract blackholing it. Can only be called once.
    // @pre: isOwner
    public shared({caller}) func init() : async () {
        assert(not INITALIZED and _isOwner(caller));
        contractOwners := [];
        INITALIZED        := true;
        await IC.update_settings({
            canister_id = Principal.fromActor(NFTService);
            settings = {
                controllers = ?[Principal.fromText("e3mmv-5qaaa-aaaah-aadma-cai")];
            };
        });
    };

    // Updates the access rights of one of the contact owners.
    public shared({caller}) func updateContractOwners(
        user          : Principal, 
        isAuthorized : Bool,
    ) : async Result.Result<(), Types.Error> {
        if (not _isOwner(caller)) { return #err(#Unauthorized); };

        switch(isAuthorized) {
            case (true) {
                contractOwners := Array.append(
                    contractOwners,
                    [user],
                );
            };
            case (false) {
                contractOwners := Array.filter<Principal>(
                    contractOwners, 
                    func(v) { v != user; },
                );
            };
        };
        ignore _emitEvent({
            createdAt     = Time.now();
            event         = #ContractEvent(
                #ContractAuthorize({
                    user         = user;
                    isAuthorized = isAuthorized;
                }),
            );
            topupAmount   = TOPUP_AMOUNT;
            topupCallback = wallet_receive;
        });
        #ok();
    };

    // Returns the meta data of the contract.
    public query func getMetadata() : async Types.ContractMetadata {
        CONTRACT_METADATA;
    };

    // Returns the total amount of minted NFTs.
    public query func getTotalMinted() : async Nat {
        nfts.getTotalMinted();
    };

    public shared({caller}) func wallet_receive() : async () {
        ignore ExperimentalCycles.accept(ExperimentalCycles.available());
    };

    // Mints a new egg.
    // @pre: isOwner
    public shared ({caller}) func mint(egg : Token.Egg) : async Result.Result<Text,Types.Error> {
        assert(_isOwner(caller));
        switch (await nfts.mint(Principal.fromActor(NFTService), egg)) {
            case (#err(e)) { #err(#FailedToWrite(e)); };
            case (#ok(id, owner)) {
                ignore _emitEvent({
                    createdAt     = Time.now();
                    event         = #ContractEvent(
                        #Mint({
                            id    = id; 
                            owner = owner;
                        }),
                    );
                    topupAmount   = TOPUP_AMOUNT;
                    topupCallback = wallet_receive;
                });
                ignore await authorize({
                    id = id;
                    p = Principal.fromActor(NFTService);
                    isAuthorized = true;
                });
                #ok(id);
            };
        };
    };
    
    public shared ({caller}) func mintWH(eggs : [Token.Egg]) : async Result.Result<[Text],Types.Error> {
        assert(_isOwner(caller));
        let idsBuff : Buffer.Buffer<Text> = Buffer.Buffer(eggs.size());
        label l for (egg in eggs.vals()) {
            switch (await nfts.mint(Principal.fromActor(NFTService), egg)) {
                case (#err(e)) { return #err(#FailedToWrite(e)); };
                case (#ok(id, owner)) {
                    ignore _emitEvent({
                        createdAt     = Time.now();
                        event         = #ContractEvent(
                            #Mint({
                                id    = id; 
                                owner = owner;
                            }),
                        );
                        topupAmount   = TOPUP_AMOUNT;
                        topupCallback = wallet_receive;
                    });
                    idsBuff.add(id);
                    continue l;
                };
            };
        };
        #ok(idsBuff.toArray());
    };

    // Writes a part of an NFT to the staged data. 
    // Initializing another NFT will destruct the data in the buffer.
    public shared({caller}) func writeStaged(data : Staged.WriteNFT) : async Result.Result<Text, Types.Error> {
        assert(_isOwner(caller));
        switch (await nfts.writeStaged(data)) {
            case (#ok(id)) { #ok(id); };
            case (#err(e)) { #err(#FailedToWrite(e)); };
        };
    };

    public type ContractInfo = {
        heap_size : Nat; 
        memory_size : Nat;
        max_live_size : Nat;
        nft_payload_size : Nat; 
        total_minted : Nat; 
        cycles : Nat; 
        authorized_users : [Principal]
    };

    // Returns the contract info.
    // @pre: isOwner
    public shared ({caller}) func getContractInfo() : async ContractInfo {
        assert(_isOwner(caller));
        return {
            heap_size        = Prim.rts_heap_size();
            memory_size      = Prim.rts_memory_size();
            max_live_size    = Prim.rts_max_live_size();
            nft_payload_size = payloadSize; 
            total_minted     = nfts.getTotalMinted(); 
            cycles           = ExperimentalCycles.balance();
            authorized_users = contractOwners;
        };
    };

    // List all static assets.
    // @pre: isOwner
public query ({caller}) func listAssets() : async [(Text, (?Principal, [Principal]), Property.Properties)] {
        let nftRes : Iter.Iter<(Text, (?Principal, [Principal]), Property.Properties)> = nfts.softEntries();
        Iter.toArray(nftRes);
    };
    // Allows you to replace delete and stage NFTs.
    // Putting and initializing staged data will overwrite the present data.
    public shared ({caller}) func assetRequest(data : Static.AssetRequest) : async Result.Result<(), Types.Error> {
        assert(_isOwner(caller));
        switch (await staticAssets.handleRequest(data)) {
            case (#ok())   { #ok(); };
            case (#err(e)) { #err(#FailedToWrite(e)); };
        };
    };

    // Returns the tokens of the given principal.
    public query func balanceOf(p : Principal) : async [Text] {
        nfts.tokensOf(p);
    };

    // Returns the tokens of the given principal.
    public shared({caller}) func balanceOfPublic(p : Principal) : async [Text] {
        nfts.tokensOf(p);
    };

    // Returns the owner of the NFT with given identifier.
    public query func ownerOf(id : Text) : async Result.Result<Principal, Types.Error> {
        nfts.ownerOf(id);
    };

    public shared ({caller}) func ownerOfPublic(id : Text) : async Result.Result<Principal, Types.Error> {
        nfts.ownerOf(id);
    };

    // Transfers one of your own NFTs to another principal.
    public shared ({caller}) func transfer(to : Principal, id : Text) : async Result.Result<(), Types.Error> {
        let owner = switch (_canChange(caller, id)) {
            case (#err(e)) { return #err(e); };
            case (#ok(v))  { v; };
        };
        let res = await nfts.transfer(to, id);
        ignore _emitEvent({
            createdAt     = Time.now();
            event         = #TokenEvent(
                #Transfer({
                    from = owner; 
                    to   = to; 
                    id   = id;
                }));
            topupAmount   = TOPUP_AMOUNT;
            topupCallback = wallet_receive;
        });
        res;
    };

    public shared ({caller}) func burn(ids : [Text], invoiceId : Text) : async Result.Result<(), Types.Error> {
        label l for(id in ids.vals()) {
            let owner = switch (_canChange(caller, id)) {
                case (#err(e)) { return #err(e); };
                case (#ok(v))  { v; };
            };
            switch(await nfts.burn(caller, id, invoiceId)) {
                case (#err(e)) { return #err(e); };
                case (#ok) {
                    ignore _emitEvent({
                        createdAt     = Time.now();
                        event         = #TokenEvent(
                            #Transfer({
                                from = owner; 
                                to   = Principal.fromText("e3mmv-5qaaa-aaaah-aadma-cai"); 
                                id   = id;
                            }));
                        topupAmount   = TOPUP_AMOUNT;
                        topupCallback = wallet_receive;
                    });
                    continue l;
                 };
            };
        };
        #ok(());
    };
    //TODO
    // Allows the caller to authorize another principal to act on its behalf.
    public shared ({caller}) func authorize(req : Token.AuthorizeRequest) : async Result.Result<(), Types.Error> {
        switch (_canChange(caller, req.id)) {
            case (#err(e)) { return #err(e); };
            case (#ok(v))  { };
        };
        if (not nfts.authorize(req)) {
            return #err(#AuthorizedPrincipalLimitReached(Token.AUTHORIZED_LIMIT))
        };
        ignore _emitEvent({
            createdAt     = Time.now();
            event         = #TokenEvent(
                #Authorize({
                    id           = req.id; 
                    user         = req.p; 
                    isAuthorized = req.isAuthorized;
                }));
            topupAmount   = TOPUP_AMOUNT;
            topupCallback = wallet_receive;
        });
        #ok();
    };

    private func _canChange(caller : Principal, id : Text) : Result.Result<Principal, Types.Error> {
        let owner = switch (nfts.ownerOf(id)) {
            case (#err(e)) {
                if (not _isOwner(caller)) return #err(e);
                Principal.fromActor(NFTService);
            };
            case (#ok(v))  {
                // The owner not is the caller.
                if (not _isOwner(caller) and v != caller) {
                    // Check whether the caller is authorized.
                    if (not nfts.isAuthorized(caller, id)) return #err(#Unauthorized);
                };
                v;
            };
        };
        #ok(owner);
    };

    // Returns whether the given principal is authorized to change to NFT with the given identifier.
    public query func isAuthorized(id : Text, p : Principal) : async Bool {
        nfts.isAuthorized(p, id);
    };

    // Returns which principals are authorized to change the NFT with the given identifier.
    public query func getAuthorized(id : Text) : async [Principal] {
        nfts.getAuthorized(id);
    };

    // Gets the token with the given identifier.
    public shared({caller}) func tokenByIndex(id : Text) : async Result.Result<Token.PublicToken, Types.Error> {
        switch(nfts.getToken(id)) {
            case (#err(e)) { return #err(e); };
            case (#ok(v))  {
                if (v.isPrivate) {
                    if (not nfts.isAuthorized(caller, id) and not _isOwner(caller)) {
                        return #err(#Unauthorized);
                    };
                };
                var payloadResult : Token.PayloadResult = #Complete(v.payload[0]);
                if (v.payload.size() > 1) {
                    payloadResult := #Chunk({
                        data       = v.payload[0]; 
                        totalPages = v.payload.size(); 
                        nextPage   = ?1;
                    });
                };
                let owner = switch (nfts.ownerOf(id)) {
                    case (#err(_)) { Principal.fromActor(NFTService); };
                    case (#ok(v))  { v;                         }; 
                };
                return #ok({
                    contentType = v.contentType;
                    createdAt = v.createdAt;
                    id = id;
                    owner = owner;
                    payload = payloadResult;
                    properties = v.properties;
                });
            }
        }
    };
    
    // Gets the token chunk with the given identifier and page number.
    public shared({caller}) func tokenChunkByIndex(id : Text, page : Nat) : async Result.Result<Token.Chunk, Types.Error> {
        switch (nfts.getToken(id)) {
            case (#err(e)) { return #err(e); };
            case (#ok(v)) {
                if (v.isPrivate) {
                    if (not nfts.isAuthorized(caller, id) and not _isOwner(caller)) {
                        return #err(#Unauthorized);
                    };
                };
                let totalPages = v.payload.size();
                if (page > totalPages) {
                    return #err(#InvalidRequest);
                };
                var nextPage : ?Nat = null;
                if (totalPages > page + 1) {
                    nextPage := ?(page + 1);
                };
                #ok({
                    data       = v.payload[page];
                    nextPage   = nextPage;
                    totalPages = totalPages;
                });
            };
        };
    };

    // Returns the token metadata of an NFT based on the given identifier.
    public shared ({caller}) func tokenMetadataByIndex(id : Text) : async Result.Result<Token.Metadata, Types.Error> {
        switch (nfts.getToken(id)) {
            case (#err(e)) { return #err(e); };
            case (#ok(v)) {
                if (v.isPrivate) {
                    if (not nfts.isAuthorized(caller, id) and not _isOwner(caller)) {
                        return #err(#Unauthorized);
                    };
                };
                #ok({
                    contentType = v.contentType;
                    createdAt   = v.createdAt;
                    id          = id;
                    owner       = switch (nfts.ownerOf(id)) {
                        case (#err(_)) { nftCreator; };
                        case (#ok(v))  { v;   };
                    };
                    properties  = v.properties;
                });
            };
        };
    };

    // Returns the token metadata of an NFT based on the given identifier.
    public shared ({caller}) func tokenMetadataByOwner(ppal : Principal) : async Result.Result<[Token.Metadata], Types.Error> {
        let tokensIds : [Text] = nfts.tokensOf(ppal);
        var tokensBuff : Buffer.Buffer<Token.Metadata> = Buffer.Buffer(tokensIds.size());
        label l for (id in tokensIds.vals()) {
            switch (nfts.getToken(id)) {
                case (#err(e)) { return #err(e); };
                case (#ok(v)) {
                    if (v.isPrivate) {
                        if (not nfts.isAuthorized(caller, id) and not _isOwner(caller)) {
                            return #err(#Unauthorized);
                        };
                    };
                    tokensBuff.add({
                        contentType = v.contentType;
                        createdAt   = v.createdAt;
                        id          = id;
                        owner       = switch (nfts.ownerOf(id)) {
                            case (#err(_)) { nftCreator; };
                            case (#ok(v))  { v;   };
                        };
                        properties  = v.properties;
                    });
                    continue l;
                };
            };
        };
        #ok(tokensBuff.toArray());
    };

    // Returns the attributes of an NFT based on the given query.
    public query ({caller}) func queryProperties(
        q : Property.QueryRequest,
    ) : async Result.Result<Property.Properties, Types.Error> {
        switch(nfts.getToken(q.id)) {
            case (#err(e)) { #err(e); };
            case (#ok(v))  {
                if (v.isPrivate) {
                    if (not nfts.isAuthorized(caller, q.id) and not _isOwner(caller)) {
                        return #err(#Unauthorized);
                    };
                };
                switch (q.mode) {
                    case (#All)      { #ok(v.properties); };
                    case (#Some(qs)) { Property.get(v.properties, qs); };
                };
            };
        };
    };

    // Updates the attributes of an NFT and returns the resulting (updated) attributes.
    public shared ({caller}) func updateProperties(
        u : Property.UpdateRequest,
    ) : async Result.Result<Property.Properties, Types.Error> {
        switch(nfts.getToken(u.id)) {
            case (#err(e)) { #err(e); };
            case (#ok(v))  {
                if (v.isPrivate) {
                    if (not nfts.isAuthorized(caller, u.id) and not _isOwner(caller)) {
                        return #err(#Unauthorized);
                    };
                };
                switch (Property.update(v.properties, u.update)) {
                    case (#err(e)) { #err(e); };
                    case (#ok(ps)) {
                        switch (nfts.updateProperties(u.id, ps)) {
                            case (#err(e)) { #err(e); };
                            case (#ok())   { #ok(ps); };
                        };
                    };
                };
            };
        };
    };

    private func _isOwner(p : Principal) : Bool {
        switch(Array.find<Principal>(contractOwners, func(v) {return v == p})) {
            case (null) { false; };
            case (? v)  { true;  };
        };
    };

    private func _emitEvent(event : Event.Message) : async () {
        let emit = func(broker : Event.Callback, msg : Event.Message) : async () {
            try {
                await broker(msg);
                messageBrokerCallsSinceLastTopup := messageBrokerCallsSinceLastTopup + 1;
                messageBrokerFailedCalls := 0;
            } catch(_) {
                messageBrokerFailedCalls := messageBrokerFailedCalls + 1;
                if (messageBrokerFailedCalls > BROKER_FAILED_CALL_LIMIT) {
                    messageBrokerCallback := null;
                };
            };
        };

        switch(messageBrokerCallback) {
            case (null)    { return; };
            case (?broker) {
                if (messageBrokerCallsSinceLastTopup > BROKER_CALL_LIMIT) return;
                ignore emit(broker, event);
            };
        };
    };

    // HTTP interface

    public query func http_request(request : Http.Request) : async Http.Response {
        let path = Iter.toArray(Text.tokens(request.url, #text("/")));
        if (path.size() != 0 and path[0] == "nft") {
            if (path.size() != 2) {
                return Http.BAD_REQUEST();
            };
            return nfts.get(path[1], nftStreamingCallback);
        };
        return staticAssets.get(request.url, staticStreamingCallback);
    };

    public query func http_request_streaming_callback(
        tk : Http.StreamingCallbackToken
    ) : async Http.StreamingCallbackResponse {
        if (Text.startsWith(tk.key, #text("nft/"))) {
            switch (nfts.getToken(tk.key)) {
                case (#err(_)) { };
                case (#ok(v))  {
                    return Http.streamContent(
                        tk.key, 
                        tk.index, 
                        v.payload,
                    );
                };
            };
        } else {
            switch (staticAssets.getToken(tk.key)) {
                case (#err(_)) { };
                case (#ok(v))  {
                    return Http.streamContent(
                        tk.key, 
                        tk.index, 
                        v.payload,
                    );
                };
            };
        };
        return {
            body  = Blob.fromArray([]); 
            token = null;
        };
    };

    // A streaming callback based on static assets.
    // Returns {[], null} if the asset can not be found.
    public query func staticStreamingCallback(tk : Http.StreamingCallbackToken) : async Http.StreamingCallbackResponse {
        switch(staticAssets.getToken(tk.key)) {
            case (#err(_)) { };
            case (#ok(v))  {
                return Http.streamContent(
                    tk.key,
                    tk.index,
                    v.payload,
                );
            };
        };
        {
            body = Blob.fromArray([]);
            token = null;
        };
    };

    // A streaming callback based on NFTs. Returns {[], null} if the token can not be found.
    // Expects a key of the following pattern: "nft/{key}".
    public query func nftStreamingCallback(tk : Http.StreamingCallbackToken) : async Http.StreamingCallbackResponse {
        let path = Iter.toArray(Text.tokens(tk.key, #text("/")));
         if (path.size() == 2 and path[0] == "nft") {
            switch (nfts.getToken(path[1])) {
                case (#err(e)) {};
                case (#ok(v))  {
                    if (not v.isPrivate) {
                        return Http.streamContent(
                            "nft/" # tk.key,
                            tk.index,
                            v.payload,
                        );
                    };
                };
            };
        };
        {
            body  = Blob.fromArray([]);
            token = null;
        };
    };
};
