
module {

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
        #AlreadyExists;
        #NotAuthorized;
        #Unauthorized;
        #NotFound;
        #InvalidRequest;
        #AuthorizedPrincipalLimitReached : Nat;
        #Immutable;
        #FailedToWrite : Text;
    };
}