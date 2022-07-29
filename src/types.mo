
module {

    public type Invoice = {
        id : Nat;
        creator : Principal;
        amount : Nat;
        token : Text;
        destination : Text;
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

      public type AccountIdentifier = {
        #text : Text;
        #principal : Principal;
        #blob : Blob;
    };


    public type AccountBalanceArgs = {
        account: Blob;
    };

    public type Tokens = {
        e8s: Nat64;
    };

    public type SubAccount = Blob;


    public type InitOptions = {
        artistWhitelist : [Principal];
        admins : [Principal];
    };

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
    };


    public type Error = {
        #NotAuthorized;
        #NonExistentItem;
        #BadParameters;
        #Unknown : Text;
    };
    // public type Error = {
    //     #AlreadyExists;
    //     #NotAuthorized;
    //     #Unauthorized;
    //     #NotFound;
    //     #InvalidRequest;
    //     #AuthorizedPrincipalLimitReached : Nat;
    //     #Immutable;
    //     #FailedToWrite : Text;
    // };
}