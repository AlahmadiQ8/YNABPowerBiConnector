section YNABConnector;

// When set to true, additional trace information will be written out to the User log. 
// This should be set to false before release. Tracing is done through a call to 
// Diagnostics.LogValue(). When EnableTraceOutput is set to false, the call becomes a 
// no-op and simply returns the original value.
EnableTraceOutput = true;

BaseUri = "https://api.youneedabudget.com/v1";


DefaultRequestHeaders = [
    #"Accept" = "application/json",
    #"Authorization" = "Bearer " & Extension.CurrentCredential()[Key]
];

/*[DataSource.Kind="YNABConnector", Publish="YNABConnector.Publish"]
shared YNABConnector.Feed = Value.ReplaceType(YNABConnectorImpl, type function (
    budgetName as (type text meta [
        Documentation.FieldCaption = "Budget Name",
        Documentation.FieldDescription = "Exact name of the budget"
    ])
) as any);*/

[DataSource.Kind="YNABConnector", Publish="YNABConnector.Publish"]
shared YNABConnector.Feed = Value.ReplaceType(YNABConnectorImpl, type function (budgetName as text) as any);

YNABConnectorImpl = (budgetName as text) =>
    let
        source = Web.Contents("https://api.youneedabudget.com/v1/budgets", [ Headers = DefaultRequestHeaders ]),
        json = Json.Document(source),
        data = json[data],
        budgets = data[budgets],
        budget = Diagnostics.LogValue("budget", List.FindText(budgets, budgetName)),
        BudgetId = Diagnostics.LogValue("BudgetId", List.First(budget)[id]),
        transactionsSource = Web.Contents("https://api.youneedabudget.com/v1/budgets/" & BudgetId & "/transactions" , [ Headers = DefaultRequestHeaders ]),
        
        #"Imported JSON" = Json.Document(transactionsSource),
        data1 = #"Imported JSON"[data],
        transactionsData = data1[transactions],
        #"Converted to Table" = Table.FromList(transactionsData, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        transactions = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"id", "date", "amount", "memo", "cleared", "approved", "flag_color", "account_id", "account_name", "payee_id", "payee_name", "category_id", "category_name", "transfer_account_id", "transfer_transaction_id", "matched_transaction_id", "deleted"}, {"id", "date", "amount", "memo", "cleared", "approved", "flag_color", "account_id", "account_name", "payee_id", "payee_name", "category_id", "category_name", "transfer_account_id", "transfer_transaction_id", "matched_transaction_id", "deleted"}),

        final = #table({"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, {
            { "Transactions", transactions, "Table", "Table", true }
        }),
        navTable = Table.ToNavigationTable(final, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;


Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;
 

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = Diagnostics[LogValue];
Diagnostics.LogFailure = Diagnostics[LogFailure];



// Data Source Kind description
YNABConnector = [
    Authentication = [
        Key = []
    ],
    Label = "TripPin Part 1 - OData"
];

// Data Source UI publishing description
YNABConnector.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { "TripPin OData", "TripPin OData" }
];

// authenticate 
// prompt user to select budget from dropdown
// get transactions
