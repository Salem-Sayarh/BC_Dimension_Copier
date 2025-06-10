namespace Extension_Loop.Extension_Loop;
using Microsoft.Sales.Document;
using Microsoft.Finance.Dimension;
using Microsoft.Sales.Customer;
using Microsoft.Service.Document;
using Microsoft.Inventory.Item;


codeunit 50111 CopyDimension
{
    procedure UpdateSalesDimensions()
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.RESET;
        SalesHeader.SETRANGE("Dimension Set ID", 0);
        if SalesHeader.FINDSET then begin
            repeat
                CopyDimensions(SalesHeader);
            until SalesHeader.NEXT = 0;
        end;
    end;

    local procedure CopyDimensions(var SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        ItemDefaultDim: Record "Default Dimension";
        TempDimSetEntry: Record "Dimension Set Entry" temporary;
        DimMgt: Codeunit DimensionManagement;
        NewDimSetID: Integer;
    begin
        // Copy the Dimensions of Customer
        CopyCustomerDim(SalesHeader);

        TempDimSetEntry.DeleteAll();

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindSet then
            repeat
                if SalesLine."Dimension Set ID" <> 0 then begin
                    SalesLine."Dimension Set ID" := 0;
                    SalesLine.Modify();
                end;
                TempDimSetEntry.DeleteAll();

                if Item.Get(SalesLine."No.") then begin
                    ItemDefaultDim.Reset();
                    ItemDefaultDim.SetRange("Table ID", Database::Item);
                    ItemDefaultDim.SetRange("No.", Item."No.");
                    if ItemDefaultDim.FindSet() then
                        repeat
                            TempDimSetEntry.SetRange("Dimension Code", ItemDefaultDim."Dimension Code");
                            if TempDimSetEntry.FindSet() then
                                repeat
                                    TempDimSetEntry.Delete();
                                until TempDimSetEntry.Next() = 0;
                            TempDimSetEntry.Reset();
                            TempDimSetEntry.Init();
                            TempDimSetEntry.Validate("Dimension Code", ItemDefaultDim."Dimension Code");
                            TempDimSetEntry.Validate("Dimension Value Code", ItemDefaultDim."Dimension Value Code");
                            TempDimSetEntry.Insert();
                        until ItemDefaultDim.Next() = 0;
                end;

                GetCustomerDimensions(SalesHeader."Sell-to Customer No.", TempDimSetEntry);

                NewDimSetID := DimMgt.GetDimensionSetID(TempDimSetEntry);
                if NewDimSetID <> 0 then begin
                    SalesLine."Dimension Set ID" := NewDimSetID;
                    SalesLine.Modify();
                end;
            until SalesLine.Next() = 0;
    end;

    local procedure CopyCustomerDim(var SalesHeader: Record "Sales Header")
    var
        TempDimSetEntry: Record "Dimension Set Entry" temporary;
        NewDimSetID: Integer;
        DimMgt: Codeunit DimensionManagement;
    begin
        TempDimSetEntry.DeleteAll();
        GetCustomerDimensions(SalesHeader."Sell-to Customer No.", TempDimSetEntry);

        if not TempDimSetEntry.IsEmpty() then begin
            NewDimSetID := DimMgt.GetDimensionSetID(TempDimSetEntry);
            if NewDimSetID <> 0 then begin
                SalesHeader."Dimension Set ID" := NewDimSetID;
                SalesHeader.Modify();
            end;
        end;
    end;

    local procedure GetCustomerDimensions(CustomerNo: Code[20]; var TempDimSetEntry: Record "Dimension Set Entry" temporary)
    var
        Cust: Record Customer;
        CustDefaultDim: Record "Default Dimension";
    begin
        if Cust.Get(CustomerNo) then begin
            CustDefaultDim.Reset();
            CustDefaultDim.SetRange("Table ID", Database::Customer);
            CustDefaultDim.SetRange("No.", Cust."No.");

            if CustDefaultDim.FindSet() then
                repeat
                    TempDimSetEntry.Init();
                    TempDimSetEntry.Validate("Dimension Code", CustDefaultDim."Dimension Code");
                    TempDimSetEntry.Validate("Dimension Value Code", CustDefaultDim."Dimension Value Code");
                    TempDimSetEntry.Insert();
                until CustDefaultDim.Next() = 0;
        end;
    end;
}
