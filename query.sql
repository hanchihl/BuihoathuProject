--Data: Adventure Works from 2015-2017

--View data from Sales 2015,2016 and 2017 then union into Sales Table
SELECT * FROM dbo.Sales_2015
SELECT * FROM dbo.Sales_2016
SELECT * FROM dbo.Sales_2017
GO 
SELECT * INTO Sales FROM
(SELECT * FROM dbo.Sales_2015
UNION
SELECT * FROM dbo.Sales_2016
UNION
SELECT * FROM dbo.Sales_2017) UnionedTables


-- Pivot the CategoryName column by SubcategoryName
SELECT [Bikes],
	   [Components],
	   [Clothing],
	   [Accessories]
FROM 
(	
	SELECT  S.SubcategoryName, 
			C.CategoryName, 
			ROW_NUMBER() OVER (PARTITION BY C.CategoryName ORDER BY sub.SubcategoryName)[rownumber]
	FROM dbo.Subcategories S
	INNER JOIN dbo.Categories C ON C.ProductCategoryKey = S.ProductCategoryKey
) AS table1
PIVOT
(	
	MAX(SubcategoryName) FOR CategoryName IN ([bikes], [components], [clothing], [accessories])
) AS table2


-- Revenue by Country
SELECT country,  
	   ROUND(SUM(OrderQuantity * (ProductPrice - ProductCost)), 0, 0) AS revenue
	FROM dbo.Sales S
	INNER JOIN dbo.Territories T ON T.SalesTerritoryKey = S.TerritoryKey
	INNER JOIN dbo.Products P    ON P.ProductKey = S.ProductKey
		GROUP BY Country
		ORDER BY revenue DESC


--Show TOP 10 best selling product over the years
SELECT [year],
	   ProductName,
	   ranks.quantity
FROM
(
	SELECT YEAR(OrderDate) AS [year],
	   ProductKey,
	   SUM(OrderQuantity) AS quantity,
	   ROW_NUMBER() OVER (PARTITION BY YEAR(OrderDate) ORDER BY SUM(OrderQuantity) DESC) AS rownumber
	FROM dbo.Sales
	GROUP BY ProductKey, 
	YEAR(OrderDate)
) AS ranks
INNER JOIN dbo.Products ON Products.ProductKey = ranks.ProductKey
	WHERE ranks.rownumber <= 10
	ORDER BY ranks.year ASC, 
		     ranks.quantity DESC


-- Create funtion to calculate revenue by SubcategoryName
CREATE FUNCTION calulate_revenue
(@subcategory nvarchar(255))
RETURNS numeric(20,2)
BEGIN 
	DECLARE @revenue numeric(20,2)
	IF NOT EXISTS (SELECT * FROM dbo.Sales
							INNER JOIN dbo.Products P ON P.ProductKey = Sales.ProductKey
							INNER JOIN dbo.Subcategories S ON  S.ProductSubcategoryKey = P.ProductSubcategoryKey
							WHERE SubcategoryName = @subcategory)
		RETURN 0
	ELSE 
		SET @revenue = (SELECT SUM(OrderQuantity * (ProductPrice - ProductCost))   
							FROM dbo.Sales 
							INNER JOIN dbo.Products P ON P.ProductKey = Sales.ProductKey
							INNER JOIN dbo.Subcategories S ON  S.ProductSubcategoryKey = P.ProductSubcategoryKey
							WHERE SubcategoryName = @subcategory)
		RETURN @revenue
END 
GO 	
PRINT dbo.calulate_revenue('Cleaners')					--use function 


-- Show return rate of products
WITH total_returns AS 
(
	SELECT SUM(returnquantity) AS quantity, productname
	FROM [Returns]
	INNER JOIN dbo.Products ON products.productkey = [Returns].ProductKey
		GROUP BY productname
),
	total_sales AS 
(
	SELECT SUM(orderquantity) AS quantity, productname
	FROM dbo.Sales
	INNER JOIN dbo.Products ON dbo.Sales.productkey = products.productkey
		GROUP BY productname
)
 SELECT S.ProductName, 
		(CASE
			WHEN R.ProductName NOT IN  (SELECT S.ProductName FROM total_sales WHERE R.ProductName=S.ProductName) THEN 0
			ELSE 
			ROUND(R.quantity * 100 / S.quantity, 2, 0)
		 END )
				AS [Percentage (%)]	
	FROM total_returns R
	RIGHT JOIN total_sales S ON R.ProductName = S.ProductName
		
	
-- Show sales turnover and average income each region
SELECT te.Region,
	   ROUND(sum(OrderQuantity*P.ProductPrice),0,0) AS Turnover, 
	   AVG(cu.AnnualIncome) AS Income
	FROM dbo.Sales 
	INNER JOIN dbo.Customers cu ON cu.CustomerKey = Sales.CustomerKey
	INNER JOIN dbo.Products P ON P.ProductKey = Sales.ProductKey
	INNER JOIN dbo.Territories te ON te.SalesTerritoryKey = Sales.TerritoryKey
		GROUP BY te.Region
		ORDER BY Turnover DESC, 
				 Income DESC
-- Show products can not sell
 SELECT productname FROM dbo.Products
 WHERE ProductKey NOT IN (SELECT ProductKey FROM dbo.Sales WHERE dbo.Sales.ProductKey = products.ProductKey)
