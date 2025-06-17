codeunit 50112 "Sales Dim Processor Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";
        LibrarySales: Codeunit "Library - Sales";
        LibraryDimension: Codeunit "Library - Dimension";
        LibraryInventory: Codeunit "Library - Inventory";
        Processor: Codeunit "Sales Doc Dimension Processor";

    [Test]
    procedure TestProcessSalesDocuments_AddsDimensions()
    var
        Customer: Record Customer;
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        DefaultDimension: Record "Default Dimension";
    begin
        // [SCENARIO] ProcessSalesDocuments() adds dimensions to header and lines
        InitializeTest();

        // [GIVEN] Customer and Item with default dimensions
        CreateCustomerWithDimension(Customer, DefaultDimension);
        CreateItemWithDimension(Item, DefaultDimension);

        // [GIVEN] Sales document with no dimensions
        CreateSalesDocumentWithItem(SalesHeader, SalesLine, Item."No.", Customer."No.");

        // [WHEN] Run the main processing procedure
        Processor.ProcessSalesDocuments();

        // [THEN] Both header and line should have dimensions
        VerifyHeaderHasDimensions(SalesHeader);
        VerifyLineHasDimensions(SalesLine);
    end;

    [Test]
    procedure TestCopyDefaultDimensions_CopiesCustomerDims()
    var
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        DefaultDimension: Record "Default Dimension";
    begin
        // [SCENARIO] CopyDefaultDimensions() copies customer dimensions to header
        InitializeTest();

        // [GIVEN] Customer with default dimension
        CreateCustomerWithDimension(Customer, DefaultDimension);

        // [GIVEN] Sales header with no dimensions
        CreateSalesDocument(SalesHeader, Customer."No.");

        // [WHEN] Call the dimension copying procedure
        Processor.CopyDefaultDimensions(SalesHeader);

        // [THEN] Header should have customer dimension
        VerifyHeaderHasDimensions(SalesHeader);
    end;

    [Test]
    procedure TestAdjustEmptyDimensionValues_FillsMandatoryValues()
    var
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        DefaultDimension: Record "Default Dimension";
    begin
        // [SCENARIO] AdjustEmptyDimensionValues() fills empty mandatory dimensions
        InitializeTest();

        // [GIVEN] Customer with mandatory dimension
        CreateCustomerWithMandatoryDimension(Customer, DefaultDimension);

        // [GIVEN] Sales header with empty dimension set
        CreateSalesDocument(SalesHeader, Customer."No.");

        // [WHEN] Call the value adjustment procedure
        Processor.AdjustEmptyDimensionValues(SalesHeader);

        // [THEN] Empty dimension should be filled
        VerifyDimensionHasValue(SalesHeader."Dimension Set ID",
            DefaultDimension."Dimension Code",
            DefaultDimension."Dimension Value Code");
    end;

    local procedure InitializeTest()
    begin
        // Clear test data before each test
        ClearAllTables();
    end;

    local procedure CreateCustomerWithDimension(var Customer: Record Customer; var DefaultDimension: Record "Default Dimension")
    var
        DimensionValue: Record "Dimension Value";
    begin
        LibrarySales.CreateCustomer(Customer);
        LibraryDimension.CreateDimWithDimValue(DimensionValue);
        LibraryDimension.CreateDefaultDimensionCustomer(
            DefaultDimension, Customer."No.",
            DimensionValue."Dimension Code", DimensionValue.Code);
    end;

    local procedure CreateItemWithDimension(var Item: Record Item; var DefaultDimension: Record "Default Dimension")
    var
        DimensionValue: Record "Dimension Value";
    begin
        LibraryInventory.CreateItem(Item);
        LibraryDimension.CreateDimWithDimValue(DimensionValue);
        LibraryDimension.CreateDefaultDimensionItem(
            DefaultDimension, Item."No.",
            DimensionValue."Dimension Code", DimensionValue.Code);
    end;

    local procedure CreateCustomerWithMandatoryDimension(var Customer: Record Customer; var DefaultDimension: Record "Default Dimension")
    begin
        CreateCustomerWithDimension(Customer, DefaultDimension);
        DefaultDimension.Validate("Value Posting", DefaultDimension."Value Posting"::"Code Mandatory");
        DefaultDimension.Modify(true);
    end;

    local procedure CreateSalesDocument(var SalesHeader: Record "Sales Header"; CustomerNo: Code[20])
    begin
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, CustomerNo);
        SalesHeader.Validate("Dimension Set ID", 0);
        SalesHeader.Modify(true);
    end;

    local procedure CreateSalesDocumentWithItem(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; ItemNo: Code[20]; CustomerNo: Code[20])
    begin
        CreateSalesDocument(SalesHeader, CustomerNo);
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, ItemNo, 1);
        SalesLine.Validate("Dimension Set ID", 0);
        SalesLine.Modify(true);
    end;

    local procedure VerifyHeaderHasDimensions(SalesHeader: Record "Sales Header")
    begin
        SalesHeader.Find();
        Assert.AreNotEqual(0, SalesHeader."Dimension Set ID", 'Header should have dimensions');
    end;

    local procedure VerifyLineHasDimensions(SalesLine: Record "Sales Line")
    begin
        SalesLine.Find();
        Assert.AreNotEqual(0, SalesLine."Dimension Set ID", 'Line should have dimensions');
    end;

    local procedure VerifyDimensionHasValue(DimSetID: Integer; DimensionCode: Code[20]; ExpectedValue: Code[20])
    var
        DimensionSetEntry: Record "Dimension Set Entry";
    begin
        DimensionSetEntry.Get(DimSetID, DimensionCode);
        Assert.AreEqual(ExpectedValue, DimensionSetEntry."Dimension Value Code",
            'Dimension should have correct value');
    end;

    local procedure ClearAllTables()
    var
        SalesHeader: Record "Sales Header";
        DefaultDimension: Record "Default Dimension";
    begin
        SalesHeader.DeleteAll(true);
        DefaultDimension.DeleteAll();
    end;
}