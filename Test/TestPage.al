page 50109 "Test Sales Quote Dimension"
{
    Caption = 'Test Sales Quote GET ALL Dimension';
    PageType = Card;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Group)
            {
                Caption = 'Click to run the CodeUnit';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TestCodeUnit)
            {
                Caption = 'Test Get Sales Quotes With no Dimension';
                trigger OnAction()
                var
                    CopyDimension: Codeunit "Sales Doc Dimension Processor";
                begin
                    CopyDimension.ProcessSalesDocuments();
                end;
            }
        }
    }
}