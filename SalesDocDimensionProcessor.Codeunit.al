codeunit 50110 "Sales Doc Dimension Processor"
{
    // Processes all sales documents with missing dimensions
    // 1. Copies default dimensions (header from customer, lines from items)
    // 2. Adjusts empty dimension values based on default rules

    procedure ProcessSalesDocuments()
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.Reset();
        SalesHeader.SetRange("Dimension Set ID", 0); // Find docs without dimensions
        if SalesHeader.FindSet() then
            repeat
                Message('Sales %1 %2 has no dimensions.',
                    SalesHeader.GetDocTypeTxt(), SalesHeader."No.");
                CopyDefaultDimensions(SalesHeader);
                AdjustEmptyDimensionValues(SalesHeader);
            until SalesHeader.Next() = 0;
    end;

    local procedure CopyDefaultDimensions(var SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        ItemDefaultDim: Record "Default Dimension";
        TempDimSetEntry: Record "Dimension Set Entry" temporary;
        DimensionManagement: Codeunit DimensionManagement;
        NewDimSetID: Integer;
    begin
        // Process Header: Copy customer dimensions
        CopyCustomerDimensions(SalesHeader);

        // Process Lines: Copy item dimensions
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindSet() then
            repeat
                ResetLineDimensions(SalesLine);
                if Item.Get(SalesLine."No.") then
                    CreateItemDimensionSet(Item, TempDimSetEntry);

                NewDimSetID := DimensionManagement.GetDimensionSetID(TempDimSetEntry);
                if NewDimSetID <> 0 then begin
                    SalesLine."Dimension Set ID" := NewDimSetID;
                    SalesLine.Modify();
                end;
            until SalesLine.Next() = 0;
    end;

    local procedure CopyCustomerDimensions(var SalesHeader: Record "Sales Header")
    var
        TempDimSetEntry: Record "Dimension Set Entry" temporary;
        DimensionManagement: Codeunit DimensionManagement;
        NewDimSetID: Integer;
    begin
        GetCustomerDimensions(SalesHeader."Sell-to Customer No.", TempDimSetEntry);
        if not TempDimSetEntry.IsEmpty() then begin
            NewDimSetID := DimensionManagement.GetDimensionSetID(TempDimSetEntry);
            if NewDimSetID <> 0 then begin
                SalesHeader."Dimension Set ID" := NewDimSetID;
                SalesHeader.Modify();
            end;
        end;
    end;

    local procedure GetCustomerDimensions(CustomerNo: Code[20]; var TempDimSetEntry: Record "Dimension Set Entry" temporary)
    var
        Customer: Record Customer;
        CustDefaultDim: Record "Default Dimension";
    begin
        if Customer.Get(CustomerNo) then begin
            CustDefaultDim.SetRange("Table ID", Database::Customer);
            CustDefaultDim.SetRange("No.", Customer."No.");
            if CustDefaultDim.FindSet() then
                repeat
                    AddDimensionEntry(
                        TempDimSetEntry,
                        CustDefaultDim."Dimension Code",
                        CustDefaultDim."Dimension Value Code"
                    );
                until CustDefaultDim.Next() = 0;
        end;
    end;

    local procedure AdjustEmptyDimensionValues(var SalesHeader: Record "Sales Header")
    var
        DimSetEntry: Record "Dimension Set Entry";
        DefaultDim: Record "Default Dimension";
        SalesLine: Record "Sales Line";
    begin
        // Adjust header dimensions
        UpdateEmptyHeaderDimensions(SalesHeader);

        // Adjust line dimensions
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindSet() then
            repeat
                UpdateEmptyLineDimensions(SalesLine);
            until SalesLine.Next() = 0;
    end;

    local procedure UpdateEmptyHeaderDimensions(SalesHeader: Record "Sales Header")
    var
        DimSetEntry: Record "Dimension Set Entry";
        DefaultDim: Record "Default Dimension";
        DefaultValue: Code[20];
    begin
        if SalesHeader."Dimension Set ID" = 0 then exit;

        DimSetEntry.SetRange("Dimension Set ID", SalesHeader."Dimension Set ID");
        if DimSetEntry.FindSet() then
            repeat
                if DimSetEntry."Dimension Value Code" = '' then
                    if DefaultDim.Get(Database::Customer, SalesHeader."Sell-to Customer No.", DimSetEntry."Dimension Code") then
                        if DefaultDim.ShouldEnforceValue() then begin
                            DefaultValue := DefaultDim."Dimension Value Code";
                            DimSetEntry."Dimension Value Code" := DefaultValue;
                            DimSetEntry.Modify();
                        end;
            until DimSetEntry.Next() = 0;
    end;

    local procedure UpdateEmptyLineDimensions(var SalesLine: Record "Sales Line")
    var
        DimSetEntry: Record "Dimension Set Entry";
        DefaultDim: Record "Default Dimension";
        DefaultValue: Code[20];
    begin
        if SalesLine."Dimension Set ID" = 0 then exit;

        DimSetEntry.SetRange("Dimension Set ID", SalesLine."Dimension Set ID");
        if DimSetEntry.FindSet() then
            repeat
                if DimSetEntry."Dimension Value Code" = '' then
                    if DefaultDim.Get(Database::Item, SalesLine."No.", DimSetEntry."Dimension Code") then
                        if DefaultDim.ShouldEnforceValue() then begin
                            DefaultValue := DefaultDim."Dimension Value Code";
                            DimSetEntry."Dimension Value Code" := DefaultValue;
                            DimSetEntry.Modify();
                        end;
            until DimSetEntry.Next() = 0;
    end;

    local procedure CreateItemDimensionSet(Item: Record Item; var TempDimSetEntry: Record "Dimension Set Entry" temporary)
    var
        ItemDefaultDim: Record "Default Dimension";
    begin
        TempDimSetEntry.DeleteAll();
        ItemDefaultDim.SetRange("Table ID", Database::Item);
        ItemDefaultDim.SetRange("No.", Item."No.");
        if ItemDefaultDim.FindSet() then
            repeat
                AddDimensionEntry(
                    TempDimSetEntry,
                    ItemDefaultDim."Dimension Code",
                    ItemDefaultDim."Dimension Value Code"
                );
            until ItemDefaultDim.Next() = 0;
    end;

    local procedure AddDimensionEntry(var TempDimSetEntry: Record "Dimension Set Entry" temporary; DimCode: Code[20]; DimValueCode: Code[20])
    begin
        TempDimSetEntry.Init();
        TempDimSetEntry.Validate("Dimension Code", DimCode);
        TempDimSetEntry.Validate("Dimension Value Code", DimValueCode);
        TempDimSetEntry.Insert();
    end;

    local procedure ResetLineDimensions(var SalesLine: Record "Sales Line")
    begin
        if SalesLine."Dimension Set ID" <> 0 then begin
            SalesLine."Dimension Set ID" := 0;
            SalesLine.Modify();
        end;
    end;
}

// Extension to Default Dimension table for value posting rules
tableextension 50110 "Default Dimension Ext" extends "Default Dimension"
{
    procedure ShouldEnforceValue(): Boolean
    begin
        exit("Value Posting" in ["Value Posting"::"Code Mandatory", "Value Posting"::"Same Code"]);
    end;
}