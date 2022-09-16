
module {

    public type ArtBasics = {
        title: Text;
        description: Text;
        artType: Text;
        tags: [Text];
        details: [(Text, DetailValue)];
    };

    public type ArtPrivate = {
        thumbnail : Text;
        title: Text;
        description: Text;
        artType: Text;
        tags: [Text];
        asset: Blob;
        details: [(Text, DetailValue)];
    };

    public type Art = {
        artBasics: ArtBasics;
        createdAt: Int;
        thumbnail : Text;
    };

    public type ArtUpdate = {
        artBasics: ArtBasics;
        thumbAsset: Blob;
        updateThumbnail : Bool;
    };

    public type NFTMetadata = {
        name : Text;
        symbol : Text;
        value : ?Nat;
        supply : ?Nat;
        website : ?Text;
        socials : [?(Text, Text)];
        prixelart : ?Text;
    };

    public type NFTMetadataExt = {
        name : Text;
        symbol : Text;
        supply : ?Nat;
        value : ?Nat;
        website : ?Text;
        socials : [?(Text, Text)];
        prixelart : ?Text;
        principal : Principal;
    };
    
    public type Invoice = {
        id : Nat;
        creator : Principal;
        amount : Nat;
        token : Text;
        destination : Text;
        quantity : Nat;
        tokenIndexes : ?[Text];
    };

     public type InvoiceError = {
        message : ?Text;
        kind : {
            #InvalidInvoiceId;
            #NotFound;
            #NotAuthorized;
            #InvalidToken;
            #Other;
            #BadFee;
            #InsufficientFunds;
            #InvalidDestination;
            #NotYet;
            #InvalidAccount
        };
    };

    
    public type CreateInvoiceResult = {
        invoice:Invoice;
        subAccount:Text;
    };



//General Types

    public type Metadata = {
        thumbnail : Text;
        name : Text;
        frontend : ?[Text];
        description : Text;
        principal_id : Principal;
        details : [(Text, DetailValue)];
    };

    public type DetailValue = {
        #I64 : Int64;
        #U64 : Nat64;
        #Vec : [DetailValue];
        #Slice : [Nat8];
        #Text : Text;
        #True;
        #False;
        #Float : Float;
        #Principal : Principal;
        #VecText : [Text];
    };

    public type Error = {
        #NotAuthorized;
        #NonExistentItem;
        #BadParameters;
        #Unknown : Text;
    };

     public type ContractInfo = {
        heapSize : Nat; 
        memorySize : Nat;
        maxLiveSize : Nat;
        cycles : Nat; 
    };

}