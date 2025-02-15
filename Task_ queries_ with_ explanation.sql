---ASSIGNMENT 2: Creation and Insertion queries for the given schema

CREATE TABLE Customers (
    CustomerID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
     Email VARCHAR(100) UNIQUE NOT NULL,
   RegistrationDate DATE DEFAULT CURRENT_DATE );

 CREATE TABLE Products (
    ProductID SERIAL PRIMARY KEY,
    ProductName VARCHAR(100) NOT NULL,
    Category VARCHAR(50) NOT NULL,
     Price DECIMAL(10,2) NOT NULL CHECK (Price > 0),
    Stock INT NOT NULL CHECK (Stock >= 0)
 );

CREATE TABLE Orders (
    OrderID SERIAL PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    TotalAmount DECIMAL(10,2) NOT NULL CHECK (TotalAmount >= 0),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

CREATE TABLE OrderDetails (
    OrderDetailID SERIAL PRIMARY KEY,
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    Subtotal DECIMAL(10,2) NOT NULL CHECK (Subtotal >= 0),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID) ON DELETE CASCADE,
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE CASCADE
);



INSERT INTO Customers (Name, Email, RegistrationDate) VALUES
('Alice Johnson', 'alice@example.com', '2024-01-01'),
('Bob Smith', 'bob@example.com', '2024-02-01'),
('Charlie Brown', 'charlie@example.com', '2024-03-01'),
('David Lee', 'david@example.com', '2024-04-01');

INSERT INTO Products (ProductName, Category, Price, Stock) VALUES
('Laptop', 'Electronics', 1200.00, 10),
('Smartphone', 'Electronics', 800.00, 15),
('Headphones', 'Accessories', 200.00, 30),
('Keyboard', 'Accessories', 100.00, 25),
('Gaming Mouse', 'Accessories', 150.00, 20),
('Tablet', 'Electronics', 600.00, 12);

INSERT INTO Orders (CustomerID, OrderDate, TotalAmount) VALUES
(1, '2024-07-01', 1400.00),
(2, '2024-07-05', 1800.00),
(3, '2024-07-10', 950.00),
(1, '2024-08-01', 2200.00),
(4, '2024-08-10', 1000.00),
( 1, '2024-08-15', 5000.00),  
( 2, '2024-09-10', 6000.00), 
( 3, '2024-10-20', 7000.00), 
( 1, '2024-11-05', 8000.00),
( 2, '2024-12-12', 9000.00),  
( 3, '2025-01-25', 10000); 

INSERT INTO OrderDetails (OrderID, ProductID, Quantity, Subtotal) VALUES
(1, 1, 1, 1200.00),  -- Alice buys a Laptop
(1, 3, 1, 200.00),   -- Alice buys Headphones
(2, 2, 2, 1600.00),  -- Bob buys 2 Smartphones
(2, 4, 2, 200.00),   -- Bob buys 2 Keyboards
(3, 3, 1, 200.00),   -- Charlie buys Headphones
(3, 5, 5, 750.00),   -- Charlie buys 5 Gaming Mice
(4, 1, 1, 1200.00),  -- Alice buys another Laptop
(4, 6, 1, 600.00),   -- Alice buys a Tablet
(4, 5, 2, 300.00),   -- Alice buys 2 Gaming Mice
(5, 2, 1, 800.00),   -- David buys a Smartphone
(5, 4, 2, 200.00);   -- David buys 2 Keyboards

-- Task 1: Advanced SQL Queries (3 Points)


--1) Retrieve the top 3 customers with the highest total purchase amount.

select c.Name, sum(TotalAmount) as TotalPurchaseAmount
from Orders o join Customers c on o.CustomerID = c.CustomerID 
group by c.Name 
order by TotalPurchaseAmount desc 
limit 3

--It selects customer names and sum of total amount of all orders placed by a specific customer
--we need to join the customer table in order to obtain their names and group the amount by the name, display them in a descending order 
--and limit it to 3 so that it retrieves top 3 customers

--2)Show monthly sales revenue for the last 6 months using PIVOT.

SELECT * FROM crosstab(
    'SELECT ''Total Revenue'' AS category, 
            TO_CHAR(OrderDate, ''YYYY-MM'') AS month, 
            SUM(TotalAmount)
     FROM Orders 
     WHERE OrderDate >= CURRENT_DATE - INTERVAL ''6 months''
     GROUP BY TO_CHAR(OrderDate, ''YYYY-MM'')
     ORDER BY month'
) AS pivot_table (
    category TEXT,
    "2024-08" NUMERIC,
    "2024-09" NUMERIC,
    "2024-10" NUMERIC,
    "2024-11" NUMERIC,
    "2024-12" NUMERIC,
    "2025-01" NUMERIC
);

--Using crosstab instead of pivot since postgre doesnt support pivot, it basically selects a fixed category 'Total Revenue'.
-- Extracts the month (YYYY-MM) from the OrderDate.
-- Sums the TotalAmount for each month in the last 6 months.
-- Groups by month and orders them.
--The crosstab() function will provide it a format of a pivot table, with one column as Total Revenue and rest columns as 'YYYY-MM'
--AS pivot_table (...) defines the structure, explicitly naming months from "2024-08" to "2025-01".

--3)Find the second most expensive product in each category using window functions.
Select category,ProductName,Price
from(
select Category,ProductName,Price, RANK() OVER(PARTITION BY Category ORDER BY Price DESC)AS rank
from Products) WHERE rank =2;

--We create a window in the inner query which selects Category,Name and Price of product which uses 
--the RANK() window function to rank products within each category (PARTITION BY Category), 
--ordering them by Price in descending order (ORDER BY Price DESC).
--Then in the outer query we specify a where condition with Rank=2 which serves the purpose

-- Task 2: Stored Procedures and Functions (2 Points)

-- Create a stored procedure to place an order, which:
-- Deducts stock from the Products table.
-- Inserts data into the Orders and OrderDetails tables.
-- Returns the new OrderId.

CREATE OR REPLACE FUNCTION placed_order(
p_cust_id int,p_prod_id int,p_qty int
) RETURNS INT AS $$

DECLARE

v_order_id int;
v_price decimal(10,2);
v_stock int;
BEGIN

SELECT Price, Stock INTO v_price, v_stock 
FROM Products 
WHERE ProductID = p_prod_id;

if v_stock<p_qty then
	raise exception 'Not enough stock';
end if;

insert into Orders(CustomerID, OrderDate, TotalAmount)values(p_cust_id, CURRENT_DATE,p_qty*v_price) RETURNING OrderID INTO v_order_id;
IF v_order_id IS NULL THEN
        RAISE EXCEPTION 'Failed to generate OrderID!';
    END IF;

insert into OrderDetails(OrderDetailID, OrderID, ProductID, Quantity, Subtotal) values(DEFAULT,v_order_id,p_prod_id,p_qty,p_qty*v_price);

 UPDATE Products
    SET Stock = Stock - p_qty
    WHERE ProductID = p_prod_id;
	
RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;

SELECT placed_order(1, 2, 3);

--Here I created a stored procediure or say a function,named placed_order which take 
-- p_cust_id → Customer ID
-- p_prod_id → Product ID
-- p_qty → Quantity of the product ordered as inputs and Check product details:
-- Retrieves Price and Stock for the given ProductID from the Products table.
-- Stock validation:
-- If available stock (v_stock) is less than requested quantity (p_qty),  
--the function throws an error (Not enough stock).
-- Insert into Orders table:Creates a new order in the Orders table, storing CustomerID, OrderDate, and total price (p_qty * price).
-- Retrieves the generated OrderID (v_order_id).
-- If OrderID is not generated, it raises an exception (Failed to generate OrderID!).
-- Insert into OrderDetails table: Stores order details: OrderID, ProductID, Quantity, and Subtotal (p_qty * price).
-- Update stock:Reduces the available stock of the product in the Products table.
-- Returns: The newly created OrderID.

--2. Write a user-defined function that takes a CustomerID and returns the total amount spent by that customer.

CREATE OR REPLACE FUNCTION count_total_amount(Cust_id int)
returns numeric as $$
declare v_total_amount NUMERIC :=0;

BEGIN
select sum(TotalAmount)into v_total_amount from Orders where CustomerID = Cust_id;
RETURN v_total_amount;
END;
$$ LANGUAGE plpgsql;

SELECT count_total_amount(4);

--Takes a customer ID (Cust_id) as input,It searches the Orders table for all rows where CustomerID = Cust_id.
-- It adds up the values from the TotalAmount column.
-- Stores the sum in v_total_amount.


-- Task 3: Transactions and Concurrency Control (3 Points)

-- 1)Write a transaction to ensure an order is placed only if all 
-- products are in stock. If any product is out of stock, rollback the transaction.

--To start with declaring to variables as order id and a boolean value insufficient stock as default set to false 
DO $$ 
DECLARE 
    v_order_id INT;
    insufficient_stock BOOLEAN := FALSE;
BEGIN
    -- Starting the transaction and Create a new order and get its ID
    INSERT INTO Orders (CustomerID, OrderDate, TotalAmount)
    VALUES (1, CURRENT_DATE, 2000.00) 
    RETURNING OrderID INTO v_order_id;

    -- Insert into order details 
    INSERT INTO OrderDetails (OrderID, ProductID, Quantity, Subtotal)
    VALUES 
        (v_order_id, 4, 500, 2099.98),  
        (v_order_id, 1, 2, 60.99);    

--Now  Check stock availability, if it is available well and good otherwise a rollback is required to erase 
--all values from orders and order details
    SELECT TRUE 
    INTO insufficient_stock
    FROM OrderDetails od
    JOIN Products p ON od.ProductID = p.ProductID
    WHERE od.OrderID = v_order_id
    AND od.Quantity > p.Stock
    LIMIT 1;

    --If stock is insufficient, rollback and exit
    IF insufficient_stock THEN
        ROLLBACK;
        RAISE EXCEPTION 'Insufficient stock for one or more products.';
    END IF;

  --  If everything is available then deduct stock from products
    UPDATE Products
    SET Stock = Stock - od.Quantity
    FROM OrderDetails od
    WHERE od.OrderID = v_order_id
    AND Products.ProductID = od.ProductID;

    --  Commit transaction if all conditions are met
    COMMIT;

    RAISE NOTICE 'Order placed successfully! Order ID: %', v_order_id;
END $$ LANGUAGE plpgsql;

--2)Demonstrate how to handle deadlocks when updating order details.
--- To demonstrate handling of a deadlock, there are many approaches, one of them is to use Shared Lock in the table
--In session 1 :
BEGIN;
 --Lock the Products table
LOCK TABLE Products IN SHARE ROW EXCLUSIVE MODE;

--Produce a delay to allow Session 2 to lock OrderDetails first
SELECT pg_sleep(7);

--Now try to update OrderDetails (this will cause a deadlock)
UPDATE OrderDetails 
SET Quantity = 5 
WHERE OrderID = 1 AND ProductID = 2;

--Commit the transaction (if no deadlock occurs)
COMMIT;
---In session 2

BEGIN; 
--Lock the OrderDetails table
LOCK TABLE OrderDetails IN SHARE ROW EXCLUSIVE MODE;

--  Simulate delay to allow Session 1 to lock Products first
SELECT pg_sleep(7);

-- Now try to update Products
UPDATE Products 
SET Stock = Stock - 1 
WHERE ProductID = 2;

-- Commit the transaction (if no deadlock occurs)
COMMIT;

--To prevent this kind of situations, we can lock table using SHARE ROW EXCLUSIVE MODE. This will lock the table until 
--user commits
BEGIN;  -- Start transaction

-- Lock tables in a consistent order to prevent deadlock
LOCK TABLE OrderDetails IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE Products IN SHARE ROW EXCLUSIVE MODE;

-- Perform updates
UPDATE OrderDetails SET Quantity = 10 WHERE OrderID = 1 AND ProductID = 4;
UPDATE Products SET Stock = Stock - 1 WHERE ProductID = 2;

-- Commit the transaction
COMMIT;
--Demonstration of a deadlock situation and its prevention.

--3)Use SAVEPOINT to allow partial updates in an order process where only some items might be out of stock.

CREATE OR REPLACE PROCEDURE handle_order(v_order_id INT)
LANGUAGE plpgsql 
AS $$
DECLARE 
    v_product_id INT;
    v_quantity INT;
    v_stock INT;
BEGIN
    FOR v_product_id, v_quantity IN 
        SELECT ProductID, Quantity FROM OrderDetails WHERE OrderID = v_order_id
    LOOP
        SELECT Stock INTO v_stock FROM Products WHERE ProductID = v_product_id;

        IF v_quantity > v_stock THEN
            RAISE NOTICE 'Skipping product due to insufficient stock.', v_product_id;
        ELSE
            UPDATE Products 
            SET Stock = Stock - v_quantity 
            WHERE ProductID = v_product_id;

            RAISE NOTICE 'Product successfully updated.', v_product_id;
        END IF;
    END LOOP;

    RAISE NOTICE 'Order processed with available items.';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'An error occurred. Order processing failed.';
END $$;       
CALL handle_order(1);

-- Task 4: SQL for Reporting and Analytics (2 Points)
-- Create reports using:
-- 1. Generate a customer purchase report using ROLLUP that includes:
-- Total purchases by customer
-- Total of all purchases
SELECT 
    c.CustomerID, 
    c.Name, 
    SUM(o.TotalAmount) AS TotalPurchases
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
GROUP BY ROLLUP(c.CustomerID, c.Name)
ORDER BY TotalPurchases  NULLS LAST;

--It uses Rollup to generate total of Total Purchases made by all the customers and 
--a seperate column for Total purchase of an individual customer

--2. Use window functions (LEAD, LAG) to show how a customer's order amount compares to their previous order amount.
SELECT 
    o.CustomerID, 
    c.Name, 
    o.OrderID, 
    o.OrderDate, 
    o.TotalAmount, 
    LAG(o.TotalAmount) OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate) AS PreviousAmount, 
    LEAD(o.TotalAmount) OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate) AS NextAmount
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
ORDER BY o.CustomerID, o.OrderDate;

--This query fetches, customer data to compare previous order's amount to next order's amount for that it requires
-- OrderDate,Amount,OrderId and Customer ID. Customer name for the sake of comparison.
-- It uses LEAD to know the next order based on provided date and LAG to get previous order amount based on Date
-- This query is ordered by customer id and orderdate to maintain consistency


