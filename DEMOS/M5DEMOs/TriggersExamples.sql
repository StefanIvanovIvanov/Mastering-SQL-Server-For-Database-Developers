CREATE PROC Sales.GetOrderCountByDueDate
@DueDate datetime, @OrderCount int OUTPUT
AS
  SELECT @OrderCount = COUNT(1)
  FROM Sales.SalesOrderHeader AS soh
  WHERE soh.DueDate = @DueDate;
GO

DECLARE @DueDate datetime = '20050713';
DECLARE @OrderCount int;
EXEC Sales.GetOrderCountByDueDate @DueDate,
                                  @OrderCount OUTPUT;
SELECT @OrderCount;


CREATE TRIGGER TR_Opportunity_Insert
ON Sales.Opportunity
AFTER INSERT AS 
BEGIN
  SET NOCOUNT ON;
  INSERT INTO Sales.OpportunityAudit 
      (OpportunityID, ActionPerformed, ActionOccurredAt)
      SELECT i.OpportunityID,
                   'I',
                   SYSDATETIME()
      FROM inserted AS i;
END;


CREATE TRIGGER TR_Category_Delete 
ON Product.Category
AFTER DELETE AS 
BEGIN
    SET NOCOUNT ON;
    UPDATE p SET p.Discontinued = 1
    FROM Product.Product AS p
    INNER JOIN deleted as d
    ON p.CategoryID = d.CategoryID;
END;
GO

CREATE TRIGGER TR_ProductReview_Update
ON Product.ProductReview
AFTER UPDATE AS 
BEGIN
    SET NOCOUNT ON;
    UPDATE pr
    SET Product.ProductReview.ModifiedDate = SYSDATETIME()
    FROM Product.ProductReview AS pr
    INNER JOIN inserted AS i
    ON i.ProductReviewID = pr.ProductReviewID;
END;


CREATE TRIGGER TR_ProductReview_Delete 
ON Product.ProductReview
INSTEAD OF DELETE AS 
BEGIN
  SET NOCOUNT ON;
  UPDATE pr SET pr.Discontinued = 1
  FROM Product.ProductReview AS pr
  INNER JOIN deleted as d
  ON pr.ProductReviewID = d.ProductReviewID;
END;

