namespace Extension_Loop.Extension_Loop;
using Microsoft.Sales.Document;
using Microsoft.Finance.Dimension;
using Microsoft.Sales.Customer;
using Microsoft.Service.Document;
using Microsoft.Inventory.Item;


codeunit 50110 UpdateSalesDoc
{
    // ***************************************************************
    // New Top-Level Procedure: ProcessSalesDocuments
    // Processes ALL Sales Documents (no Document Type filter)
    // ***************************************************************
    procedure ProcessSalesDocuments()
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.RESET;
        // Removed Document Type filter – now all Sales Docs will be processed.
        SalesHeader.SETRANGE("Dimension Set ID", 0);
        if SalesHeader.FINDSET then begin
            repeat
                Message('Sales with Type %1 No. %2 has no dimensions.', SalesHeader.GetDocTypeTxt(), SalesHeader."No.");
                // First, copy dimensions from default records.
                CopyDimensions(SalesHeader);
                // Then adjust empty Dimension Value Codes based on default settings.
                AdjustDimensionValueCodes(SalesHeader);
            until SalesHeader.NEXT = 0;
        end;
    end;

    // ***************************************************************
    // Modified CopyDimensions Procedure
    // Now copies dimensions for both header and lines for all Sales Docs.
    // For Sales Header, customer defaults are used.
    // For Sales Lines, item defaults are used.
    // ***************************************************************
    local procedure CopyDimensions(var SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        ItemDefaultDim: Record "Default Dimension";
        TempDimSetEntry: Record "Dimension Set Entry" temporary;
        DimMgt: Codeunit DimensionManagement;
        NewDimSetID: Integer;
    begin
        // Copy header dimensions from customer defaults.
        CopyCustomerDim(SalesHeader);

        // Process each Sales Line.
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FINDSET then
            repeat
                // Reset the Sales Line's dimension set.
                if SalesLine."Dimension Set ID" <> 0 then begin
                    SalesLine."Dimension Set ID" := 0;
                    SalesLine.MODIFY();
                end;
                TempDimSetEntry.DELETEALL();

                // If the item exists, copy its default dimensions.
                if Item.GET(SalesLine."No.") then begin
                    ItemDefaultDim.RESET();
                    ItemDefaultDim.SETRANGE("Table ID", DATABASE::Item);
                    ItemDefaultDim.SETRANGE("No.", Item."No.");
                    if ItemDefaultDim.FINDSET() then
                        repeat
                            // Remove any existing entry for the same Dimension Code.
                            TempDimSetEntry.SetRange("Dimension Code", ItemDefaultDim."Dimension Code");
                            if TempDimSetEntry.FINDSET() then
                                repeat
                                    TempDimSetEntry.DELETE();
                                until TempDimSetEntry.NEXT() = 0;
                            TempDimSetEntry.RESET();
                            TempDimSetEntry.INIT();
                            TempDimSetEntry.VALIDATE("Dimension Code", ItemDefaultDim."Dimension Code");
                            TempDimSetEntry.VALIDATE("Dimension Value Code", ItemDefaultDim."Dimension Value Code");
                            TempDimSetEntry.INSERT();
                        until ItemDefaultDim.NEXT() = 0;
                end;

                // Calculate a new Dimension Set ID for the Sales Line.
                NewDimSetID := DimMgt.GetDimensionSetID(TempDimSetEntry);
                if NewDimSetID <> 0 then begin
                    SalesLine."Dimension Set ID" := NewDimSetID;
                    SalesLine.MODIFY();
                end;
            until SalesLine.NEXT() = 0;
    end;

    // ***************************************************************
    // CopyCustomerDim remains as before but is now used for ALL Sales Docs.
    // It copies customer default dimensions to the Sales Header.
    // ***************************************************************
    local procedure CopyCustomerDim(var SalesHeader: Record "Sales Header")
    var
        TempDimSetEntry: Record "Dimension Set Entry" temporary;
        NewDimSetID: Integer;
        DimMgt: Codeunit DimensionManagement;
    begin
        TempDimSetEntry.DELETEALL();
        GetCustomerDimensions(SalesHeader."Sell-to Customer No.", TempDimSetEntry);

        if not TempDimSetEntry.ISEMPTY() then begin
            NewDimSetID := DimMgt.GetDimensionSetID(TempDimSetEntry);
            if NewDimSetID <> 0 then begin
                SalesHeader."Dimension Set ID" := NewDimSetID;
                SalesHeader.MODIFY();
            end;
        end;
    end;

    // ***************************************************************
    // GetCustomerDimensions: Copies customer default dimensions into a temporary table.
    // ***************************************************************
    local procedure GetCustomerDimensions(CustomerNo: Code[20]; var TempDimSetEntry: Record "Dimension Set Entry" temporary)
    var
        Cust: Record Customer;
        CustDefaultDim: Record "Default Dimension";
    begin
        if Cust.GET(CustomerNo) then begin
            CustDefaultDim.RESET();
            CustDefaultDim.SETRANGE("Table ID", DATABASE::Customer);
            CustDefaultDim.SETRANGE("No.", Cust."No.");
            TempDimSetEntry.DELETEALL();

            if CustDefaultDim.FINDSET() then
                repeat
                    TempDimSetEntry.INIT();
                    TempDimSetEntry.VALIDATE("Dimension Code", CustDefaultDim."Dimension Code");
                    TempDimSetEntry.VALIDATE("Dimension Value Code", CustDefaultDim."Dimension Value Code");
                    TempDimSetEntry.INSERT();
                until CustDefaultDim.NEXT() = 0;
        end;
    end;

    // ***************************************************************
    // New Procedure: AdjustDimensionValueCodes
    // This procedure updates dimension entries (for both Sales Header and Sales Lines)
    // IF the Dimension Value Code is empty AND
    // the corresponding default dimension record’s Value Posting field is either 'Code Mandatory' or 'Same Code'.
    // For header dimensions, the default is taken from the Customer.
    // For line dimensions, the default is taken from the Item.
    // If the Dimension Value Code is not empty, nothing is done.
    // ***************************************************************
    local procedure AdjustDimensionValueCodes(var SalesHeader: Record "Sales Header")
    var
        DimSetEntry: Record "Dimension Set Entry";
        DefaultDim: Record "Default Dimension";
        SalesLine: Record "Sales Line";
        DefaultValue: Code[20];
    begin
        // --- Process Sales Header Dimensions ---
        if SalesHeader."Dimension Set ID" <> 0 then begin
            DimSetEntry.SETRANGE("Dimension Set ID", SalesHeader."Dimension Set ID");
            if DimSetEntry.FINDSET() then
                repeat
                    // Only update if the Dimension Value Code is empty.
                    if DimSetEntry."Dimension Value Code" = '' then begin
                        // Look up the customer default dimension for this Dimension Code.
                        if DefaultDim.GET(DATABASE::Customer, SalesHeader."Sell-to Customer No.", DimSetEntry."Dimension Code") then begin
                            // Only update if Value Posting is 'Code Mandatory' or 'Same Code'.
                            if (DefaultDim."Value Posting" = "Default Dimension Value Posting Type"::"Code Mandatory") or (DefaultDim."Value Posting" = "Default Dimension Value Posting Type"::"Same Code") then begin
                                DefaultValue := DefaultDim."Dimension Value Code";
                                DimSetEntry."Dimension Value Code" := DefaultValue;
                                DimSetEntry.MODIFY();
                            end;
                        end;
                    end;
                until DimSetEntry.NEXT() = 0;
        end;

        // --- Process Sales Line Dimensions ---
        SalesLine.SETRANGE("Document Type", SalesHeader."Document Type");
        SalesLine.SETRANGE("Document No.", SalesHeader."No.");
        if SalesLine.FINDSET() then
            repeat
                if SalesLine."Dimension Set ID" <> 0 then begin
                    DimSetEntry.RESET();
                    DimSetEntry.SETRANGE("Dimension Set ID", SalesLine."Dimension Set ID");
                    if DimSetEntry.FINDSET() then
                        repeat
                            if DimSetEntry."Dimension Value Code" = '' then begin
                                // Look up the item default dimension for this Dimension Code.
                                if DefaultDim.GET(DATABASE::Item, SalesLine."No.", DimSetEntry."Dimension Code") then begin
                                    if (DefaultDim."Value Posting" = "Default Dimension Value Posting Type"::"Code Mandatory") or (DefaultDim."Value Posting" = "Default Dimension Value Posting Type"::"Same Code") then begin
                                        DefaultValue := DefaultDim."Dimension Value Code";
                                        DimSetEntry."Dimension Value Code" := DefaultValue;
                                        DimSetEntry.MODIFY();
                                    end;
                                end;
                            end;
                        until DimSetEntry.NEXT() = 0;
                end;
            until SalesLine.NEXT() = 0;
    end;
}
