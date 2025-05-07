/*
	FILE: 8bit.sql
	DATE: 2025-05-01
	AUTHOR: Richard Kemereit
	DESCRIPTION: A database made for an independent game store.
	This includes the database itself, stored procedures, views, triggers, and security setup.
*/

-- Drop database and create new one
DROP DATABASE IF EXISTS 8bit;
CREATE DATABASE 8bit;
USE 8bit;

-- Drop all tables first to avoid foreign key constraint issues
DROP TABLE IF EXISTS Invoice;
DROP TABLE IF EXISTS Employee_pay_rate;
DROP TABLE IF EXISTS Game_inventory;
DROP TABLE IF EXISTS Customer;
DROP TABLE IF EXISTS Customer_address;
DROP TABLE IF EXISTS Employee;
DROP TABLE IF EXISTS Game_item;
DROP TABLE IF EXISTS Audit_log;

-- Create tables
CREATE TABLE Customer_address (
    Address_id INT NOT NULL AUTO_INCREMENT COMMENT 'Unique identifier for each address'
    , Street_address VARCHAR(100) NOT NULL COMMENT 'Street address of the customer'
    , City VARCHAR(168) NOT NULL COMMENT 'City for the customer'
    , State CHAR(2) NOT NULL COMMENT 'State of the customer abbreviated'
    , Zip_code VARCHAR(10) NOT NULL COMMENT 'Zip code for the customer'
    , PRIMARY KEY (Address_id)
) COMMENT 'Information about a customers address';

CREATE TABLE Employee (
    Employee_id INT NOT NULL AUTO_INCREMENT COMMENT 'Unique identifier for the employee'
    , First_name VARCHAR(256) NOT NULL COMMENT 'The first name of the employee'
    , Last_name VARCHAR(256) NOT NULL COMMENT 'The last name of the employee'
    , DOB DATE NOT NULL COMMENT 'The date of birth of the employee'
    , PRIMARY KEY (Employee_id)
) COMMENT 'The name and related information regarding employees';

CREATE TABLE Game_item(
    Game_id INT NOT NULL AUTO_INCREMENT COMMENT 'Unique identifier for the game'
    , Game_name VARCHAR(256) NOT NULL COMMENT 'The name of the game.'
    , Game_platform VARCHAR(100) NOT NULL COMMENT 'Platform that the game can be played on'
    , Game_genre VARCHAR(50) NULL COMMENT 'Genre of the game'
    , Release_year CHAR(4) NOT NULL COMMENT 'Release year of the game item'
    , Game_item_description VARCHAR(1024) NOT NULL COMMENT 'Description of an item'
    , PRIMARY KEY(Game_id)
) COMMENT 'The name and related information regarding the video games';

CREATE TABLE Customer (
    Customer_id INT NOT NULL AUTO_INCREMENT COMMENT 'Unique identifier for a customer'
    , Customer_first_name VARCHAR(256) NOT NULL COMMENT 'Customers first name'
    , Customer_last_name VARCHAR(256) NOT NULL COMMENT 'Customers last name'
    , Address_id INT NOT NULL COMMENT 'Reference to customer address'
    , Phone_number VARCHAR(11) NOT NULL COMMENT 'Phone number for the customer'
    , PRIMARY KEY (Customer_id)
    , CONSTRAINT fk_Customer_Customer_address FOREIGN KEY (Address_id)
        REFERENCES Customer_address(Address_id)
) COMMENT 'Any information regarding customer details';

CREATE TABLE Game_inventory (
    Game_id INT NOT NULL COMMENT 'Unique identifier for a given game'
    , Unit_on_hand INT NOT NULL DEFAULT 0 COMMENT 'Amount of units on hand for a given item'
    , Unit_sold INT NOT NULL DEFAULT 0 COMMENT 'Amount of units sold in the past week for a given item'
    , Price DECIMAL(9,2) NOT NULL COMMENT 'Price of a given item'
    , PRIMARY KEY (Game_id)
    , CONSTRAINT fk_Game_inventory_Game_item FOREIGN KEY (Game_id)
        REFERENCES Game_item(Game_id)
) COMMENT 'Information regarding the inventory of a given game';

CREATE TABLE Employee_pay_rate (
    Employee_id INT NOT NULL COMMENT 'Unique identifier for the employee'
    , Start_date DATE NOT NULL COMMENT 'Start date of an employee'
    , End_date DATE NULL COMMENT 'End date of an employee'
    , Employee_wage DECIMAL(4,2) NOT NULL COMMENT 'Hourly wage of an employee'
    , Employee_position VARCHAR(100) NOT NULL COMMENT 'Position of an employee'
    , PRIMARY KEY (Employee_id, Start_date)
    , CONSTRAINT fk_Employee_pay_rate_Employee FOREIGN KEY (Employee_id)
        REFERENCES Employee(Employee_id)
) COMMENT 'Information regarding an employees pay';

CREATE TABLE Invoice (
    Invoice_id INT NOT NULL AUTO_INCREMENT COMMENT 'Unique identifier for an invoice'
    , Customer_id INT NOT NULL COMMENT 'Unique identifier for a customer'
    , Item_amount INT NOT NULL COMMENT 'Amount of items in a purchase'
    , Subtotal DECIMAL(9,2) NOT NULL COMMENT 'Subtotal of a purchase'
    , Tax DECIMAL(9,2) NOT NULL COMMENT 'Sales tax for a purchase'
    , Created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Time when invoice was created'
    , PRIMARY KEY (Invoice_id)
    , CONSTRAINT fk_Invoice_Customer FOREIGN KEY (Customer_id)
        REFERENCES Customer(Customer_id)
) COMMENT 'Invoice for a customer';

-- Create audit table for triggers
CREATE TABLE Audit_log (
    Log_id INT NOT NULL AUTO_INCREMENT COMMENT 'Unique identifier for each audit log entry'
    , Table_name VARCHAR(50) NOT NULL COMMENT 'Name of the table where the change occurred'
    , Action_type VARCHAR(10) NOT NULL COMMENT 'Type of action performed (INSERT, UPDATE, or DELETE)'
    , Record_id INT NOT NULL COMMENT 'ID of the record that was modified'
    , Changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp when the change occurred'
    , Changed_by VARCHAR(100) NOT NULL COMMENT 'Username of the person who made the change'
    , PRIMARY KEY (Log_id)
) COMMENT 'Audit log for tracking changes in the database';

-- Create Triggers
DELIMITER //

-- Insert Trigger
CREATE TRIGGER game_item_after_insert 
AFTER INSERT ON Game_item
FOR EACH ROW
BEGIN
    INSERT INTO Audit_log (
		Table_name
		, Action_type
		, Record_id
		, Changed_by
		)
    VALUES (
		'Game_item'
		, 'INSERT'
		, NEW.Game_id
		, CURRENT_USER()
		);
END//

-- Update Trigger
CREATE TRIGGER game_item_after_update
AFTER UPDATE ON Game_item
FOR EACH ROW
BEGIN
    INSERT INTO Audit_log (
		Table_name
		, Action_type
		, Record_id
		, Changed_by
		)
    VALUES (
		'Game_item'
		, 'UPDATE'
		, NEW.Game_id
		, CURRENT_USER()
		);
END//

-- Delete Trigger
CREATE TRIGGER game_item_after_delete
AFTER DELETE ON Game_item
FOR EACH ROW
BEGIN
    INSERT INTO Audit_log (
		Table_name
		, Action_type
		, Record_id
		, Changed_by)
    VALUES (
		'Game_item'
		, 'DELETE'
		, OLD.Game_id
		, CURRENT_USER()
		);
END//

-- Create Views
-- View 1: Game Sales Report
CREATE VIEW vw_game_sales_report AS
SELECT 
    game_inv.Game_id
    , g.Game_name
    , g.Game_platform
    , game_inv.Unit_sold
    , game_inv.Price
    , (game_inv.Unit_sold * game_inv.Price) AS Total_Revenue
FROM Game_inventory game_inv
JOIN Game_item g ON game_inv.Game_id = g.Game_id
WHERE game_inv.Unit_sold > 0//

-- View 2: Employee Payment History
CREATE VIEW vw_employee_payment_history AS
SELECT 
    e.Employee_id
    , CONCAT(e.First_name, ' ', e.Last_name) AS Employee_name
    , epr.Employee_position
    , epr.Employee_wage
    , epr.Start_date
    , epr.End_date
FROM Employee e
JOIN Employee_pay_rate epr ON e.Employee_id = epr.Employee_id//

-- CRUD Stored Procedures for Game_item
-- Create Procedure
CREATE PROCEDURE sp_create_game_item(
    IN p_game_name VARCHAR(256)
    , IN p_game_platform VARCHAR(100)
    , IN p_game_genre VARCHAR(50)
    , IN p_release_year CHAR(4)
    , IN p_unit_sold INT
    , IN p_game_item_description VARCHAR(1024)
    , OUT p_game_id INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error creating game item record';
    END;

    START TRANSACTION;
    INSERT INTO Game_item (
        Game_name 
        , Game_platform
        , Game_genre
        , Release_year
        , Unit_sold
        , Game_item_description
    )
    VALUES (
        p_game_name
        , p_game_platform
        , p_game_genre
        , p_release_year
        , p_unit_sold
        , p_game_item_description
    );
    
    SET p_game_id = LAST_INSERT_ID();
    COMMIT;
END//

-- Read Procedure
CREATE PROCEDURE sp_read_game_item(
    IN p_game_id INT
)
BEGIN
    SELECT * FROM Game_item WHERE Game_id = p_game_id;
END//

-- Update Procedure
CREATE PROCEDURE sp_update_game_item(
    IN p_game_id INT
    , IN p_old_game_name VARCHAR(256)
    , IN p_old_game_platform VARCHAR(100)
    , IN p_old_unit_sold INT
    , IN p_new_game_name VARCHAR(256)
    , IN p_new_game_platform VARCHAR(100)
    , IN p_new_unit_sold INT
)
BEGIN
    DECLARE record_count INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error updating game item record';
    END;

    SELECT COUNT(*) INTO record_count
    FROM Game_item
    WHERE Game_id = p_game_id
    AND Game_name = p_old_game_name
    AND Game_platform = p_old_game_platform
    AND Unit_sold = p_old_unit_sold;

    IF record_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No matching record found for update';
    END IF;

    START TRANSACTION;
    UPDATE Game_item
    SET Game_name = p_new_game_name,
        Game_platform = p_new_game_platform,
        Unit_sold = p_new_unit_sold
    WHERE Game_id = p_game_id;
    COMMIT;
END//

-- Delete Procedure
CREATE PROCEDURE sp_delete_game_item(
    IN p_game_id INT
    , IN p_game_name VARCHAR(256)
    , IN p_game_platform VARCHAR(100)
    , IN p_unit_sold INT
)
BEGIN
    DECLARE record_count INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error deleting game item record';
    END;

    SELECT COUNT(*) INTO record_count
    FROM Game_item
    WHERE Game_id = p_game_id
    AND Game_name = p_game_name
    AND Game_platform = p_game_platform
    AND Unit_sold = p_unit_sold;

    IF record_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No matching record found for deletion';
    END IF;

    START TRANSACTION;
    DELETE FROM Game_item
    WHERE Game_id = p_game_id;
    COMMIT;
END//

DELIMITER ;

-- Create Role and User
CREATE ROLE IF NOT EXISTS game_manager;

GRANT EXECUTE ON PROCEDURE 8bit.sp_create_game_item TO game_manager;
GRANT EXECUTE ON PROCEDURE 8bit.sp_read_game_item TO game_manager;
GRANT EXECUTE ON PROCEDURE 8bit.sp_update_game_item TO game_manager;
GRANT EXECUTE ON PROCEDURE 8bit.sp_delete_game_item TO game_manager;

-- Create a user and assign the role
CREATE USER IF NOT EXISTS 'game_user'@'localhost' IDENTIFIED BY 'G@m3Us3r2024';
GRANT game_manager TO 'game_user'@'localhost';

-- Sample data insertion
INSERT INTO Customer_address (
	Street_address
	, City
	, State
	, Zip_code
	) VALUES (
		'123 Main St'
		, 'New York'
		, 'NY'
		, '10001'
		), (
			'456 Oak Ave'
			, 'Los Angeles'
			, 'CA'
			, '90001'
			);

INSERT INTO Game_item (
Game_name
, Game_platform
, Game_genre
, Release_year
, Game_item_description
) VALUES
('Super Mario Odyssey'
, 'Nintendo Switch'
, 'Platform'
, '2017'
, 'A 3D platform adventure game'
),
('The Legend of Zelda'
, 'Nintendo Switch'
, 'Action-Adventure'
, '2022'
, 'An epic adventure game'
);


INSERT INTO Customer (
Customer_first_name
, Customer_last_name
, Address_id
, Phone_number
) VALUES
('John'
, 'Doe'
, 1
, '12345678901'
),
('Jane'
, 'Smith'
, 2
, '98765432101'
);

INSERT INTO Game_inventory (
Game_id
, Unit_on_hand
, Unit_sold
, Price
) VALUES
(1
, 10
, 5
, 59.99
),
(2
, 15
, 3
, 49.99
);

-- sample employee data
INSERT INTO Employee (
First_name
, Last_name
, DOB
) VALUES
('Bob'
, 'Johnson'
, '1990-05-15'
),
('Alice'
, 'Williams'
, '1988-03-22'
);

INSERT INTO Employee_pay_rate (
Employee_id
, Start_date
, End_date
, Employee_wage
, Employee_position
) VALUES
(1
, '2023-01-01'
, NULL, 15.50
, 'Sales Associate'
),
(2
, '2023-01-15'
, NULL
, 18.75
, 'Manager'
);

-- invoice data
INSERT INTO Invoice (
    Customer_id
    , Item_amount
    , Subtotal
    , Tax
) VALUES
(1
, 2
, 119
.98
, 9.60
),  -- John Doe buying 2 games
(2
, 1
, 49.99
, 4.00
),   -- Jane Smith buying 1 game
(1
, 3
, 179.97
, 14.40
); -- John Doe making another purchase


