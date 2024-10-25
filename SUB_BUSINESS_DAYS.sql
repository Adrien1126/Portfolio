DROP FUNCTION IF EXISTS SUB_BUSINESS_DAYS;
DELIMITER //

CREATE FUNCTION SUB_BUSINESS_DAYS(start_date DATE, sub_days INTEGER)
RETURNS DATE
DETERMINISTIC
BEGIN
    DECLARE counter INT DEFAULT 0;
    DECLARE curr_date DATE;
    SET curr_date = DATE_SUB(start_date, INTERVAL sub_days DAY);
    
    IF DAYOFWEEK(curr_date) = 7 THEN 
		SET curr_date = DATE_ADD(curr_date, INTERVAL 2 DAY); 
	ELSEIF DAYOFWEEK(curr_date) = 1 THEN 
		SET curr_date = DATE_ADD(curr_date, INTERVAL 1 DAY);
	END IF;
    RETURN curr_date;
END //

DELIMITER ;

